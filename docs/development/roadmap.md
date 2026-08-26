# commandress — Roadmap

> **Post-v1 sequencing.** State lives in [`state.md`](state.md); this file is the
> *order* — what ships in which release, against what gate. Shipped work moves to
> [`../../CHANGELOG.md`](../../CHANGELOG.md); only next-up and future work lives here.
>
> Every item below is **pinned work**: it exists because something in the codebase,
> an audit, or an ADR defers it. Each carries a **source** link back to the line that
> defers it, so the roadmap and the code cannot drift apart. If you add a `TODO`,
> `deferred`, or `follow-up` to the source, add it here too — that is the contract.
>
> Version slots are **planned sequencing, not commitments**. Items move between slots
> as priorities change; what does not move is the pinned list itself.

## Status

**v1.0 shipped 2026-05-18.** All v1.0 criteria are met and archived at the bottom of
this file. Current release is **1.1.6**; the 1.1.x line has been toolchain refreshes,
the cmdit CLI adoption, and a security audit. The public API is frozen per
[ADR 0007](../adr/0007-schema-freeze.md): everything below is either **additive** on a
not-frozen surface, or routed through the documented 3-step deprecation path. No item
here breaks a v1 config.

---

## 1.2.0 — Colour and theming completion

The colour model shipped deliberately narrow at 0.6.0 (16 named colours). Every slot
below was reserved at schema freeze, so all of it is additive.

| Item | Source of the deferral |
|---|---|
| **Multi-palette** — `[[palettes.<name>]]` tables plus a top-level `palette = "<name>"` selector. Single-palette `[[palette]]` shipped 0.6.0; the multi form was reserved, not built. | [ADR 0007](../adr/0007-schema-freeze.md) reserved-for-additive; `state.md` post-v1 theme track |
| **Hex and 256-colour values** — `fg = "#8be9fd"` / `fg = "38;5;117"` alongside the named set. | `src/color.cyr:6` — *"Hex / 256-color / palette references are deferred (v0.6.x+)"* |
| **A powerline-ready theme variant** — the five shipped themes are fg-only; a powerline theme needs `bg` on every segment block. | `docs/themes/README.md:87` — *"A dedicated powerline-ready theme variant is planned for a follow-up release"* |

**Gate**: none. All three are additive config surface plus `src/color.cyr` work.

---

## 1.3.0 — Language-env depth

The language-env segments are file-first by explicit user direction (2026-05-18): read
a pin file, never pay a subprocess. That policy stands. This slot finishes the *file*
half and puts the subprocess half behind opt-in config.

| Item | Source of the deferral |
|---|---|
| **`rust-toolchain.toml` parsing** — the modern `[toolchain] channel = "…"` form, alongside the legacy plain-text file. **No longer gated** (see below). | `src/segments/rustup_env.cyr` |
| **`package.json` → `engines.node`** — a second `node_env` source when `.nvmrc` is absent. | `src/segments/node_env.cyr:14` |
| **Opt-in version shellouts** — `python --version`, `node --version`, `rustup show active-toolchain`, each behind a per-segment config flag, default off. The 1 s TTL cache (`src/cache.cyr`) is what makes them affordable. | `src/segments/node_env.cyr`, `src/segments/rustup_env.cyr`; `state.md` "deferred by policy" |

**Gate: CLEARED.** `rust-toolchain.toml` was deferred because the Cyrius stdlib could
not parse single-bracket `[section]` tables (papercut Item 3). **That gap has closed.**
Verified 2026-08-26 against the 6.5.35 stdlib: `toml_get_sections` finds a
single-bracket `[toolchain]`, with a double-bracket control case proving the harness.
This item is scheduled work now, not blocked work — the source comments that said
otherwise were corrected in the same sweep.

---

## 1.4.0 — Per-segment control

Knobs the config schema was always shaped for but never grew, plus the output-shape gap
the 2026-08-26 audit recorded.

| Item | Source of the deferral |
|---|---|
| **Per-segment `budget_ms`** — `[[segments.vcs]] budget_ms = N`; the watchdog budget is fixed in code today. | `src/segments/vcs.cyr:26` — *"in a follow-up slot — for v0.4.0 the budget is fixed in code"* |
| **Per-segment output length cap** — a hostile repository can push ~255 printable characters into every redraw via a language-env pin file. Sanitized and inert, but visually disruptive; `max_length` currently applies to `cwd` only. | [2026-08-26 audit](../audit/2026-08-26-audit.md) — *Known gaps* |
| **Local time and `TZ`** — the `time` segment is UTC-only; `TZ` lookup plus offset application is its own piece of work. | `src/segments/time.cyr:23` |

**Gate**: none. All three are additive per-segment config fields.

---

## 1.5.0 — Cache and build hygiene

Nothing user-visible; all of it is the "we know, we wrote it down" pile.

| Item | Source of the deferral |
|---|---|
| **Cache eviction** — entries are tiny and never garbage-collected, one per (segment, cwd) forever. | `src/cache.cyr:30` — *"Out of scope (M6 follow-ups if needed): LRU eviction … for now we don't gc"* |
| **Wider cache key** — the key is a 32-bit djb2 of the cwd, so two directories can share an entry and render each other's branch name for one TTL second. Not a privilege boundary (the cache is 0700 and per-UID), just wrong output. | [2026-08-26 audit](../audit/2026-08-26-audit.md) — *Known gaps* |
| **Decide `CYRIUS_DCE=1` for release builds** — roughly half the binary is code the linker never reaches (`384 unreachable fns, 69,382 B` at last count). DCE eliminates it but is not wired into the build or CI. Size is not a budgeted metric (render time is), so this is hygiene — but it should be a decision, not a drift. | `state.md` in-flight, noted at 1.1.4 |
| **`alloc` return guards beyond the chokepoint** — 1.1.6 guarded `sanitize_segment_output`, the one path every segment crosses. The rest allocate small fixed-shape buffers and are reachable only under heap exhaustion. | [2026-08-26 audit](../audit/2026-08-26-audit.md) — *Known gaps* |

---

## Unscheduled — gated on something outside this repo

These are **not** in a version slot because commandress cannot schedule them. Each is
listed with what would unblock it, so the gate is checkable rather than folkloric.

| Item | Real gate | Checked |
|---|---|---|
| **agnoshi adoption** — flips on when agnoshi reads `$AGNOSHI_PROMPT_CMD` per redraw. The 5-point contract is already specified in `adapters/agnoshi.sh`; **no commandress change is required**. | agnoshi implements the contract | `adapters/agnoshi.sh:16` — *"agnoshi has not yet adopted it"* |
| **Retire `src/pathlookup.cyr`** — 99 lines re-implementing `execvp`'s PATH walk, because `execve(2)` does not do PATH lookup and no stdlib helper exposes one. | Cyrius grows a `which()`-equivalent (papercut Item 8) | Re-checked 2026-08-26 against the 6.5.35 vendored stdlib: **still open**, no stdlib fn resolves a bare name against `$PATH`. The workaround ships and is correct. |

> **Check the gate before repeating it.** Two of the three "blocked on Cyrius" claims in
> this repo were stale by the time anyone re-read them — Item 3 had shipped, and the
> `[[X]]` config workaround it justified had become unnecessary without anyone noticing.
> Item 8 was re-verified and genuinely still holds. Re-test the gate at each toolchain
> refresh rather than carrying the claim forward.

---

## Explicitly not planned

Unchanged from v1.0, restated so nobody re-proposes them:

- **Windows / non-Linux support** — AGNOS is Linux-derived. agnos is a build target; other OSes are not.
- **GUI / TUI config editor** — editing a config file is fine.
- **Plugin system / dynamic segment loading** — breaks the static-binary story; segments are first-party.
- **Right-prompt animation, blink, stateful render** — the render is one-shot by design.
- **Multi-line prompts as the default** — configurable if a user wants it; not the default.
- **External `git` fallback for `vcs`** — `sit` is the AGNOS-native VCS and the only backend ([ADR 0004](../adr/0004-vcs-probe-via-sit.md)).
- **Changing the canonical `[[X]]` config spelling to `[X]`** — single-bracket now *works* and is documented as accepted, but `[[X]]` stays canonical: every shipped theme and example uses it, and a churn of every user's config buys nothing.

---

## Archived — v1.0 criteria (all met, shipped 2026-05-18)

- [x] Stable config schema, breaking changes only via deprecation — **0.9.0** ([ADR 0007](../adr/0007-schema-freeze.md))
- [x] Core segment set (`cwd`, `exit`, `time`, `vcs`, the four language envs, `hostname`, `user`) — **0.5.0**
- [x] Full-prompt render under 5 ms cold start, CI-gated — **0.7.0**
- [x] Per-segment time budget; slow segments degrade to empty — **0.4.0** (`src/shellout.cyr`)
- [x] At least one downstream consumer green — zsh + bash adapters, **0.8.0**
- [x] CHANGELOG complete from v0.1.0
- [x] Security audit pass — **0.9.0** ([2026-05-18](../audit/2026-05-18-audit.md)); second pass **1.1.6** ([2026-08-26](../audit/2026-08-26-audit.md))
- [x] Benchmarks captured — **0.9.0** ([`benchmarks.md`](../benchmarks.md))
