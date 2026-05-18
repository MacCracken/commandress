# 0005 — Language-env segments follow a file-first probe pattern

**Status**: Accepted
**Date**: 2026-05-18

## Context

M4 ships four language-env segments — `cyrius_env`, `python_env`, `node_env`, `rustup_env` — and the v1.0 roadmap leaves room for more (ruby, go, java, ...). Without a shared shape, each segment could diverge on multiple axes:

- **Project detection** — env var (`$VIRTUAL_ENV`), ancestor walk for a marker file (`.python-version`, `.nvmrc`, `rust-toolchain`), or runtime invocation (`python --version`).
- **What to display** — project pin (file contents) vs runtime version (process probe). Both are "the python version" but answer different questions.
- **Whether to shell out** — and when.
- **Parse / trim semantics** — leading/trailing whitespace handling, CRLF, surrounding quotes.

A few constraints frame the choice:

- **5 ms cold-start budget** ([`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)). Every segment runs per redraw. fork+exec is ~1–3 ms (see `vcs_render`'s 1.8 ms in `state.md`). Four language-env segments forking simultaneously would obliterate the budget before M6 caching lands.
- **File-first user direction** (2026-05-18): "yeah file-first is the safest clean path... and shellout can be later in the project prior to v1." Settles the shellout question for v0.5.0 — file sources first, shellout deferred until M6 caching makes version probes affordable.
- **Sovereign-stack default** (memory: prefer first-party tools when shelling out). When a shellout fallback eventually does land, it targets the language's own native tool (`cyrius --version`, not a wrapper).
- **No mandatory project detector** — Python and Rust don't have one canonical "this is a project" file the way `cyrius.cyml` or `Cargo.toml` do. The marker file *is* the project signal.

## Decision

**Every language-env segment resolves in the following order, stopping at the first non-empty result:**

1. **Environment variable** — only when the language convention surfaces a "currently active" signal that way. Today: `$VIRTUAL_ENV` for `python_env` (its basename is the venv name). Takes precedence because the user explicitly activated something.
2. **Project pin file (ancestor walk)** — walk cwd upward via `find_ancestor_with` looking for the marker, read+trim via `read_trimmed_file_at`. Today:
   - `cyrius_env` → `cyrius.cyml` marker, reads `VERSION`
   - `python_env` → `.python-version`
   - `node_env` → `.nvmrc`
   - `rustup_env` → `rust-toolchain`
3. **Shellout fallback** — only when a sovereign-stack tool can answer authoritatively. Today only `cyrius_env` does this (`cyrius --version` via the shared `shellout_capture` watchdog, 5 ms budget). Python / Node / Rust don't shell out in v0.5.0 — deferred to a pre-v1 milestone tied to M6 caching.
4. **Empty** — segment renders nothing.

**Shared infrastructure** lives in `src/fslookup.cyr`:

- `find_ancestor_with(start_dir, marker)` — the cwd-upward walker.
- `read_trimmed_file_at(root, suffix)` — read + trim ws (space, tab, `\n`, `\r`) at both ends. 256-byte read cap (pin files hold semver-shaped strings, not data).

**Output convention** — raw version string (`0.5.0`, `20.11.1`, `lts/iron`, `stable`). No label, glyph, or padding. Theming (prefixes, colors, glyphs) is M5's job — uniform across all env segments, not per-segment.

**Per-segment artifacts** — each segment owes:

- A header comment listing its resolution order + any deferred sources (e.g. `node_env` notes `package.json engines.node` and `node --version` as parked).
- A test group exercising the helpers it composes (basename for python; find_ancestor_with + read_trimmed_file_at for others). The orchestrator's empty-outside-project branch gets a smoke test.
- A bench for the render path (file walk to `/` is the empty-render worst case; ~6–12 µs in current numbers).

## Consequences

- **Positive**
  - New env probes follow a 15–30 line template (`node_env.cyr` is 20 lines, `rustup_env.cyr` is 18). The shared helpers absorb the cost.
  - Empty-render budget is dominated by `getcwd` + `access` per ancestor — 6 µs is 0.12% of the 5 ms budget. Adding the fifth, sixth, seventh segment doesn't change the order of magnitude.
  - Predictable shape for users: every segment reads the same project-pin conventions the language's own tooling already respects (`pyenv` reads `.python-version`; `nvm` / `fnm` / `volta` read `.nvmrc`; cargo respects `rust-toolchain`). The prompt agrees with the toolchain.
  - File-first means cold-start time scales linearly with segment count without forking — M6 caching becomes a *latency improvement* for the shellout cases, not a *prerequisite for being usable*.
- **Negative**
  - Languages without standard pin files need a new pattern when they arrive. Java is the canonical example — `pom.xml` / `build.gradle` declare the project, but the JDK version lives in `JAVA_HOME` or `~/.sdkmanrc` / `.tool-versions`. Will require ADR amendment when first encountered.
  - "Project pin" and "active runtime" are not always the same. `python_env` shows `myenv` (basename of `$VIRTUAL_ENV`) when activated, and `3.11.7` (`.python-version` contents) otherwise. A user with both signals present sees the venv name, not the pin — defensible (the venv is the *active* truth) but worth knowing.
  - Hand-rolled scanners for richer files (`rust-toolchain.toml`'s `[toolchain] channel = "..."`, `package.json engines.node`) are blocked on either Cyrius stdlib gaps (single-bracket TOML, papercut Item 3) or JSON-parse cost we don't want to pay yet. Deferred — these are real gaps users may notice.
- **Neutral**
  - The shellout-fallback slot in the pattern is currently only used by `cyrius_env`. Reserving the layer in the contract (rather than the implementation) keeps room for `python --version` / `node --version` / `rustup show` to land later without an ADR amendment.
  - Each segment gets its own dispatcher and registry entry in `src/render.cyr`. Five env segments = five dispatchers. Considered a single `_dispatch_env(segment_name)` table but the explicit dispatchers cost ~3 lines apiece and read cleanly; defer the table-driving until the registry crosses ~10 entries.

## Alternatives considered

- **Shellout-first (starship-style)** — every segment runs `python --version` / `node --version` / `rustc --version` / `cyrius --version` per redraw. Matches user expectation from starship/p10k but pays 1–3 ms per shellout × N segments. Outside the budget without caching. Revisitable once M6 lands the 1-second-TTL cache; the segment internals don't need to change, only the resolution order flips.
- **Per-segment file-walk helpers** — each env segment hand-rolls its own ancestor walk. Tried this initially (the walker was inline in `cyrius_env.cyr` for one bite). Rejected once python_env became the second consumer — duplication was real (~40 lines) and the abstraction has one obvious shape.
- **Single shared `env_segment(spec)` factory** — would generalise even further, with each segment passing a config struct (marker file, env var name, output transform). Considered too speculative — the four current segments have idiosyncrasies ($VIRTUAL_ENV basename; `cyrius --version` parse) that wouldn't compress cleanly into a spec. Revisitable if the count crosses ~8 and the idiosyncrasies have decayed.
- **No shellout, ever** — drop the layer-3 slot entirely. Rejected because `cyrius_env`'s "early project with no VERSION file yet" use case is real and well-served by `cyrius --version`. Removing the slot would either drop a useful behaviour or push the shellout responsibility into the segment in an ad-hoc way.

## References

- [`docs/architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md) — the 5 ms / 500 µs envelope this pattern lives inside.
- [`docs/adr/0002-segment-rendering-model.md`](0002-segment-rendering-model.md) — pure-fn-of-input segment contract these probes inherit.
- [`docs/adr/0004-vcs-probe-via-sit.md`](0004-vcs-probe-via-sit.md) — the sister decision for the VCS segment; same fork+exec watchdog, same per-segment empty-on-failure contract.
- `src/fslookup.cyr` — shared `find_ancestor_with` + `read_trimmed_file_at`.
- `src/pathlookup.cyr` — shared `find_in_path` (used by the shellout layer).
- `src/shellout.cyr` — the fork+pipe+epoll watchdog all shellout-backed segments share.
