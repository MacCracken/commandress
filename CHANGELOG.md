# Changelog

All notable changes to commandress will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.4.0] — 2026-05-18

**M3 — time + hostname + user segments + per-segment timeout watchdog (M2 carry-over).** Closes the four-deliverable bag for milestone M3 from the roadmap. The per-segment timeout enforcement that was carried forward from M2 lands as a generic `shellout_capture` watchdog (`src/shellout.cyr`) that wraps fork + pipe + epoll-deadline + SIGKILL + waitpid around any external command; `src/segments/vcs.cyr` switched from its inline `_vcs_capture` workaround onto the watchdog. Three new pure-syscall segments — `time` (mini-strftime over `lib/chrono.cyr`), `hostname` (`uname(2)` nodename field), and `user` (`getuid` + `lib/pwd.cyr` musl-style /etc/passwd reader, `$USER` fallback) — round out the M3 core set. Cyrius pin bumped to 5.11.63 along the way; binary size dropped **395,115 B → 152,234 B** vs the 5.11.59-era 0.3.0 (−242,881 B; the .61 heap-alloc of `lib/toml.cyr::toml_parse_file` reclaimed 256 KB of bss DCE couldn't drop).

### Added

- **`src/shellout.cyr`** — `shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen): i64`. Forks the child, dup2's stdout to a pipe + stderr to `/dev/null`, polls the read end with an epoll deadline, kills the child on overrun, reaps via `waitpid`. Returns bytes captured (`>= 0`), `-1` on system error, `-2` on timeout. Architecture model in [`docs/architecture/002-shellout-watchdog.md`](docs/architecture/002-shellout-watchdog.md). The watchdog is the reusable infrastructure piece — future shellout segments (M4 language-env) inherit the same gate without rebuilding the fork+poll scaffold.
- **`src/segments/time.cyr`** — `time_format(epoch, fmt)` + `time_render(fmt)`. Strftime-subset formatter supporting `%H %M %S %Y %y %m %d %%`; unsupported specs pass through verbatim. Default format `"%H:%M"`. Time is `CLOCK_REALTIME` UTC; local-time / `TZ` parsing is a future slot. Splitting the pure `time_format(epoch, fmt)` from the wall-clock-reading `time_render(fmt)` lets tests pin the input epoch and assert byte-for-byte.
- **`src/segments/hostname.cyr`** — `uname(2)` nodename field at offset 65 of the utsname struct. One syscall, no config knobs. Short-host rendering (strip first dot onward) and length truncation are future config fields if asked for.
- **`src/segments/user.cyr`** — `getuid()` + `pwd_getpwuid()` direct /etc/passwd lookup (musl-style; bypasses glibc NSS via `lib/pwd.cyr`). Falls back to `$USER` env var on lookup failure (missing /etc/passwd, UID not present, strbuf too small) and finally renders empty when even that's unset. Matches starship/PS1 conventions for the user surface.
- **`docs/architecture/002-shellout-watchdog.md`** — mechanism + caller contract + scope limits (no retry, no partial-output, no CPU-bound enforcement).
- **Config schema gains `[[segments.time]]`** — `format = "%H:%M"` (default). Default applied baseline-then-override; unknown keys warn to stderr with per-section allow-list. `hostname` and `user` register in the segment dispatcher but ship no `[[segments.*]]` block at v0.4.0 (no knobs to expose yet).
- **Render registry registers `time` / `hostname` / `user`** via `_dispatch_time` / `_dispatch_hostname` / `_dispatch_user` in `src/render.cyr`. Default `cfg.segments` stays `["cwd", "exit"]` — the new segments are opt-in. M6 caching will revisit which segments live in the default set.
- **Tests** — 18 new assertions across 12 tests (`51 → 65` total):
  - 4 shellout: `test_shellout_happy_path` (`/bin/echo hello` returns 6 bytes verbatim), `test_shellout_timeout_kills_child` (`/bin/sleep 1` with 10 ms budget returns -2 in well under 1 s — proving SIGKILL fired rather than parent blocking on waitpid).
  - 9 time: HH:MM / HH:MM:SS / date / 2-digit year (verified against 2026-01-01 epoch) / literal `%%` / unknown spec pass-through / mixed literals+specs / null fmt / empty fmt.
  - 3 hostname: non-null render + byte-for-byte match against direct `uname(2)` nodename.
  - 2 user: non-null render with /etc/passwd-or-$USER skip-on-both-absent.
  - Suite is now **65 passed, 0 failed (65 total)**.

### Changed

- **`VERSION`** — `0.3.0` → `0.4.0`.
- **`cyrius.cyml [package].cyrius`** — `5.11.59` → `5.11.63`. Absorbs the .60–.63 Cyrius commandress papercut band (Items 1, 2, 5, 6, 7 closed; Items 3, 4, 8 still deferred to Cyrius v6.x).
- **`lib/` refresh** — `cyrius lib sync` pulled the .60 / .61 fixes for `lib/process.cyr` (`_exec3` byte-contract; vec-exec family stderr dup2) and `lib/toml.cyr` (`toml_parse_file` heap-alloc).
- **`src/segments/vcs.cyr`** — `_vcs_capture` deleted (~45 LoC); `vcs_render` now calls `shellout_capture(sit_path, argv, envp, VCS_BUDGET_MS = 5, &buf, 8192)` and treats any negative return as the empty-render path. Hardcoded 5 ms budget is the seam where config-overridable `[[segments.vcs]] budget_ms = N` plumbing will hook in later. `_find_in_path` stays inline pending Cyrius v6.x Item 8.
- **`src/config.cyr`** — `CFG_SIZE` grew 56 → 64 B for the new `CFG_TIME_FORMAT` slot. `config_default()` initializes it to `"%H:%M"`. `config_load()` gains a `[[segments.time]]` parsing block with allow-list `{format}`.
- **`src/main.cyr`** — added `include "lib/chrono.cyr"` (for `clock_now_ms` + `clock_epoch_secs` + `epoch_to_date`), `include "lib/pwd.cyr"` (user segment), and `include "src/shellout.cyr"` ahead of `src/render.cyr`.
- **`tests/commandress.tcyr`** — same library + segment includes added.
- **Binary size** — text 84,050 → 114,578 B (+30,528 for the four new segments + watchdog + chrono + pwd surfaces that survive DCE in commandress's slice). bss 298,064 → 37,656 B (−260,408 — toml heap-alloc).

### Roadmap

- **M3 closed.** All four deliverables shipped: per-segment timeout watchdog (M2 carry-over), time segment, hostname segment, user segment. Default segments remain `["cwd", "exit"]` — new segments are opt-in until M6 cached probes change the cost math.

## [0.3.0] — 2026-05-17

**M2 — VCS context segment (sit-based).** commandress now reads the current branch + dirty/clean state from [`sit`](https://github.com/MacCracken/sit) (the AGNOS-native VCS, per ADR 0004) and renders it as a segment. Opt-in via `segments = ["cwd", "vcs", "exit"]` in `~/.commandress.cyml`. Inside a sit repo on branch `main` with a clean tree → `<cwd> main $ `; with edits → `<cwd> main* $ `; outside any sit repo or without `sit` on PATH → vcs segment is empty. Per-segment timeout enforcement is the only M2 deliverable not in this release — `sit status` is fast in practice (~1.8 ms fork+exec+parse on the dev host) and the watchdog earns its own slot in v0.4.0.

### Added

- **ADR 0004** — VCS probe shells out to `sit`, not external `git`. Sovereign-stack alignment captured. [`docs/adr/0004-vcs-probe-via-sit.md`](docs/adr/0004-vcs-probe-via-sit.md).
- **`src/segments/vcs.cyr`** — VCS context segment.
  - `_find_in_path(name)` — walks `$PATH`, returns the absolute path of the first hit (`access(X_OK)`-probed). Needed because `lib/process.cyr` wraps bare `execve(2)` which does NOT do PATH lookup. ~30 LoC inline; filed upstream as papercut item 8 to push a `which()` / `run_p` helper into stdlib.
  - `_vcs_capture(cmd_path, arg1, buf, buflen)` — inline fork + pipe + execve with stdout captured into `buf` and stderr dup2'd to `/dev/null`. Heap-alloc'd argv (24 B). Avoids `lib/process.cyr::run_capture` because its `_exec3` helper has a stack-buffer-size bug (`var argv[4]` reserves 4 *bytes* but stores 5 pointers = 40 bytes — silent stack overflow that broke `run_capture("/bin/echo", "hello", 0, ...)` returning 1 byte instead of 6). Filed upstream as papercut item 6.
  - `vcs_parse_render(buf, n, dirty_marker)` — pure parser. Returns `<branch>` (clean) or `<branch><dirty_marker>` (dirty) or 0 (parse failure / not a recognised `On branch <name>` shape).
  - `vcs_render(dirty_marker)` — composes the above: find sit, capture, parse, render.
- **Config schema gains `[[segments.vcs]]`** — `show_dirty: bool` (default `true`), `dirty_marker: string` (default `"*"`). Defaults baked in; missing section → defaults; unknown keys warn to stderr with per-section allow-list.
- **Render registry registers `vcs`** via `_dispatch_vcs` in `src/render.cyr`. Default `cfg.segments` stays `["cwd", "exit"]` — vcs is opt-in for v0.3.0 (one fork+exec per redraw is non-trivial cost; M6 caching changes the math, and only-when-asked is the right default until then).
- **Example config updated** with the `[[segments.vcs]]` section + body-zone notes about the new segment.
- **Tests** — 11 new (4 vcs config + 7 vcs parser) on top of the existing 36. `cyrius test` 47/47 green. Parser tests cover: clean, staged-dirty, unstaged-dirty, custom marker, marker-disabled, wrong-prefix-returns-empty, short-buffer-returns-empty.
- **Benchmarks** — `vcs_parse_render` 233 ns avg (pure byte-scan), `vcs_render` (fork+sit status+parse) **1.814 ms** avg — ~36 % of the 5 ms cold-start budget. M6 caching (1 s TTL on probe results) eats the redundant cost across rapid redraws.
- **Upstream filings** — appended three new items (6 — `_exec3` argv size bug; 7 — `exec_capture` missing stderr redirect; 8 — no PATH lookup in stdlib) to the existing [cyrius issue 2026-05-17 commandress papercuts](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-17-commandress-stdlib-papercuts.md). All three are workaround-shipped in this release.

### Changed

- Binary size: **374,168 B → 395,592 B** (+21,424 B for the vcs segment + parser + `_find_in_path` + `_vcs_capture` + new tests). `.bss` largely unchanged; growth is in `.text`.
- Roadmap M2 ADR ref updated to **0004** (the previous draft used 0003, which is now taken by the config-format ADR).
- Roadmap M2 marked feature-complete; per-segment timeout enforcement (the remaining M2 deliverable) deferred to v0.4.0 with explicit roadmap note.

## [0.2.0] — 2026-05-17

**M1 — minimum viable prompt — feature-complete.** Config loader lands; the prompt is now end-to-end user-configurable. `cwd` and `exit` segments paint per the user's `~/.commandress.cyml`; segment order, separator, trailer, and per-segment toggles (`home_shorten`, `hide_zero`) all flow through from disk to render. Defaults are baked in — the binary still produces the v0.1.0 prompt shape when no config file is present. M2 (VCS segment) reframed to shell out to [`sit`](https://github.com/MacCracken/sit) (AGNOS-native) rather than external `git` — sovereign-stack alignment.

### Added

- **`src/config.cyr`** — CYML config loader for `~/.commandress.cyml`. Schema:
  ```cyml
  [[prompt]]
  segments  = ["cwd", "exit"]
  separator = " "
  trailer   = " $ "

  [[segments.cwd]]
  home_shorten = true

  [[segments.exit]]
  hide_zero = true
  ```
  Defaults baked in; missing file → defaults; unknown fields warn to stderr with per-section allow-list. The `[[name]]` (array-of-tables) spelling is a stdlib-parser workaround — `[name]` (single table) support is filed as [cyrius proposal 2026-05-17](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-17-toml-single-bracket-sections.md). Once it lands, the schema migrates to `[prompt]`/`[segments.cwd]`/`[segments.exit]` with `[[name]]` kept back-compat.
- **`src/context.cyr`** — per-invocation `Context` struct `{ home, last_exit }` handed read-only to every segment dispatcher. Earned its own file once render became table-driven and segments stopped reading env vars themselves.
- **`src/render.cyr` is now table-driven** — registers segments as `(name → dispatcher fn ptr)` and walks `cfg.segments` via `fncall2(fp, cfg, ctx)`. Joins non-empty outputs with `cfg.separator`; appends `cfg.trailer` unconditionally. Unknown segment names warn to stderr and skip — rendering continues with what's recognized.
- **`docs/examples/commandress.cyml.example`** — annotated example config with notes in the CYML body zone describing available segments.
- **Config-loader tests** — `test_config_defaults`, `test_config_load_missing_returns_defaults`, `test_config_load_null_path_returns_defaults`, `test_config_load_full_override`, `test_config_load_partial_override`. 36 assertions total across the suite (was 13 in v0.1.0).
- **Roadmap M1 marked complete on `main`**; M2 reframed to **shell out to [`sit`](https://github.com/MacCracken/sit) rather than external `git`** for VCS state. Sovereign-stack alignment — commandress already commits to zero non-stdlib deps and `sit` is a first-party Cyrius binary on the same toolchain cadence.
- **Upstream filings opened during the session**:
  - [cyrius issue 2026-05-17 commandress papercuts](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-17-commandress-stdlib-papercuts.md) — 5 stdlib/tooling items: bench scaffold using non-existent `bench()` 3-arg form; `lib/toml.cyr::toml_parse_file`'s 256 KB on-fn-scope static buffer that bloats every consumer's `.bss`; `[name]` silently dropped; LSP transitive-include false positives; `large static data` warning fires before DCE.
  - [cyrius proposal 2026-05-17 toml single-bracket sections](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-17-toml-single-bracket-sections.md) — additive `[name]` support alongside existing `[[name]]`.

### Changed

- Segment functions are invoked through dispatcher wrappers (`_dispatch_cwd`, `_dispatch_exit`) so the registry can pass `(cfg, ctx)` uniformly. Raw `cwd_render(home)` / `exit_render(code)` signatures unchanged for direct callers (tests, future debug paths).
- Binary size: **73,544 B → 374,168 B**. ~290 KB of that is `.bss` from `lib/toml.cyr::toml_parse_file`'s 256 KB `var buf[262144]` static in an unreachable fn (we use `toml_parse` directly after `cyml_parse` splits the header). Pure `.text` is **84 KB**. Tracking upstream — see papercut issue item 2. Per-segment + full-prompt timings unchanged: `cwd_render` 674 ns avg, `exit_render(42)` 38 ns avg, `config_default` 140 ns avg, `render_prompt` 2 µs avg — still **0.04 %** of the 5 ms budget.

## [0.1.0] — 2026-05-17

**Initial public release.** Scaffold + minimum viable prompt (M1 partial — `cwd` + `exit` segments, render pipeline) + CI/release wiring aligned with kriya. The binary renders a working prompt out of the box; full user-configurability arrives in v0.2.0.

### Identity

`commandress` (binary: `cmdrs`) — a structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) and eventually bash/zsh. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius. Stateless, segment-based, config-driven, zero non-stdlib deps.

### Added

- **Scaffold** via `cyrius init commandress` (2026-05-15) — `VERSION`, `cyrius.cyml`, `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `LICENSE`, `.gitignore`, `src/{main,test}.cyr`, `tests/commandress.{tcyr,bcyr,fcyr}`, `docs/{adr,architecture,guides,examples,development}/` per [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md).
- **Binary output name** `cmdrs` (short for *commandress*) configured via `[build].output`.
- **ADR 0001** — repo split from agnoshi: prompt rendering lives in its own repo + binary; the contract between shell and prompt is env vars + CLI flags. [`docs/adr/0001-separate-repo-from-agnoshi.md`](docs/adr/0001-separate-repo-from-agnoshi.md).
- **ADR 0002** — segment rendering model: each segment is a pure fn of the prompt context; no shared mutable state; config-driven order Just Works because segments are leaves. [`docs/adr/0002-segment-rendering-model.md`](docs/adr/0002-segment-rendering-model.md).
- **ADR 0003** — config format: `~/.commandress.cyml` is CYML (Cyrius-native), not TOML; matches the `cyrius.cyml` mental model, markdown body reserved for user notes. [`docs/adr/0003-config-format.md`](docs/adr/0003-config-format.md).
- **Architecture note 001** — prompt render budget: 5 ms cold start total, 500 µs per-segment default, slow segments degrade to empty (never stall). [`docs/architecture/001-prompt-render-budget.md`](docs/architecture/001-prompt-render-budget.md).
- **`src/segments/cwd.cyr`** — current-working-directory segment. `getcwd` syscall + strict-prefix `$HOME → ~` shortening (won't false-match `/home/macro` against `/home/macrobench`).
- **`src/segments/exit.cyr`** — last-exit segment. Empty on `0`, `[N]` on non-zero. Reads from `$AGNOSHI_LAST_EXIT`.
- **`src/render.cyr`** — render pipeline. Walks a hard-coded segment list, joins non-empty outputs with a single space, appends `$ ` trailer. (Config-driven version lands in v0.2.0.)
- **`src/main.cyr`** — wires `getenv` → segments → render. Replaces the `hello from commandress` scaffold stub.
- **Tests** (`tests/commandress.tcyr`) — 7 tests across cwd + exit segments (13 assertions): home-prefix exact-match, strict-prefix, bad-home fallback, negative exit code, etc. `cyrius test` 13/13 green.
- **Benchmarks** (`tests/commandress.bcyr`) — per-segment + full-prompt timings on the dev host: `cwd_render` 664 ns / `exit_render` 38 ns / `render_prompt` 2 µs avg — **0.04 % of the 5 ms budget**. (Replaced an `init`-scaffold `bench(name, fp, n)` stub that referenced a non-existent stdlib symbol — the real API is `bench_new` + `bench_batch_start/stop`.)
- **README, CLAUDE.md, `docs/development/{state,roadmap}.md`, `docs/guides/getting-started.md`** filled with project-specific content per [first-party-standards.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md).

### Changed

- **Cyrius toolchain pin** bumped from `5.11.54` → `5.11.59` in `cyrius.cyml`; synced `lib/` from `~/.cyrius/versions/5.11.59/lib` via `cyrius lib sync`. Picks up the v5.11.55–.59 wrapper polish (manifest-pin drift detection, `--strict-pin`, `cyrius lib sync` itself) and the DCE-aware undef-fn reachability filter (cross-arch).
- Binary size: **58,568 B → 73,544 B** (+14,976 B for the M1 segments + render pipeline + tests).
- **`cyrius.cyml` `version` resolves via `${file:VERSION}`** (was hardcoded `"0.1.0"`). Aligns with the kriya pattern and the CLAUDE.md rule that `VERSION` is the single source of truth. Combined with `release.yml`'s `cat VERSION == $GITHUB_REF_NAME` gate, a release bump is now one edit to `VERSION` — drift becomes a fail-loud CI error.

### Fixed

- **CI parity with [kriya](https://github.com/MacCracken/kriya)**: added `workflow_call:` trigger to `.github/workflows/ci.yml` so `release.yml`'s `uses: ./.github/workflows/ci.yml` gate can invoke it (without the trigger, release would have failed at the CI-gate step). Switched build step output from `build/${{ github.event.repository.name }}` (would have published asset `commandress`) to `build/cmdrs`, matching `[build].output` and `CLAUDE.md` Quick Start.
