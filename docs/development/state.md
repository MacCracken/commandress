# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.1.4** — released 2026-08-26. **Toolchain refresh + stdlib resync** patch — Cyrius pin `6.4.66` → `6.5.35`, clearing the wrapper/manifest drift (`cyrius --version` had been printing `manifest-pin: 6.4.66 (drift — wrapper is 6.5.35)`), plus a full re-vendor of the bundled stdlib snapshot to match (`cyrius lib sync --full` — 60 libs updated, 2 added, 0 removed; headline bumps bayan `1.2.0 → 1.5.2`, sankoch `2.5.1 → 2.7.8`, yukti `2.2.9 → 2.3.8`, patra `1.12.12 → 1.13.10`, vani `1.1.1 → 1.2.2`, ganita `1.0.3 → 1.1.4`, sandhi `1.9.0 → 1.9.10`, sigil `3.12.1 → 3.12.9`, sakshi `2.4.6 → 2.4.11`, mabda `4.0.7 → 4.1.0`). Also carries the previously-unreleased **agnos cache fix** (`src/cache.cyr` — `sys_stat` arity, cache disabled on agnos), a **CI toolchain-install fix** (both workflows now use the upstream `scripts/install.sh` instead of a hand-rolled untar into the pre-6.5 flat `~/.cyrius/{bin,lib}` layout, which 6.5.x rejects — the pin bump detonated that latent break), and a fix to `scripts/bench-history.sh`, which had been silently dropping every decimal-average bench row since 6.4.x. Suite remains 279/279 green; `--agnos` cross-build clean; binary 147,600 B → 168,264 B (+20,664 B, +14.0 % — the vendored snapshot, not codegen; the compiler was already 6.5.35 on both sides of the measurement). Public API per [ADR 0007](../adr/0007-schema-freeze.md) unchanged. Prior: **1.1.3** (2026-07-17) Cyrius pin `6.2.24` → `6.4.66` + stdlib resync; **1.1.2** (2026-06-19) Cyrius pin `6.1.14` → `6.2.24`; **1.1.1** (2026-06-08) agnos argv fix; **1.1.0** (2026-06-06) AGNOS as a build target; **1.0.1** (2026-05-21) Cyrius pin `5.11.64` → `6.0.1`; **1.0.0** tagged 2026-05-18 (M9 — v1.0 freeze + tag). Next: **post-v1 cadence** — multi-palette, `rust-toolchain.toml` once Cyrius single-bracket TOML lands, the parked file-first language shellouts, agnoshi adoption.

## Role

Structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Binary name: `cmdrs`. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius.

## Toolchain

- **Cyrius pin**: `6.5.35` (in `cyrius.cyml [package].cyrius`)

## Source

| Module | Status |
|---|---|
| `src/main.cyr` | M1 — loads config, builds Context, dispatches to `render_prompt(cfg, ctx)` |
| `src/config.cyr` | **M1 + M3 (0.4.0) + M5 (0.6.0–0.6.1)** — CYML loader for `~/.commandress` (renamed from `~/.commandress.cyml` per ADR 0006). Schema: `[[prompt]]` (segments, right_segments, separator, trailer, separator_style, separator_glyph, right_separator_glyph) + `[[segments.cwd]]` (home_shorten, max_length, fg/bg/style) + `[[segments.exit]]` (hide_zero, fg/bg/style) + `[[segments.vcs]]` (show_dirty, dirty_marker, fg/bg/style) + `[[segments.time]]` (format, fg/bg/style) + `[[segments.{hostname,user,cyrius_env,python_env,node_env,rustup_env}]]` (fg/bg/style only) + optional `[[palette]]` (named-slot table referenced via `fg = "palette:<name>"`). Per-segment storage: pre-baked SGR cstring + raw bg cstring (the latter only used by powerline transitions). Defaults baked in (including opinionated default theme); partial-override-safe; missing file → defaults; unknown fields warn to stderr. `CFG_SIZE` 264 B |
| `src/context.cyr` | **M1 (0.2.0)** — `{ home, last_exit }` per-invocation context handed to every segment dispatcher |
| `src/render.cyr` | **M1 + M3 (0.4.0) + M4 (0.5.0) + M5 (0.6.0–0.6.1)** — table-driven registry (name → dispatcher fn ptr). `render_prompt(cfg, ctx, side)` paints either `cfg.segments` (side=0) or `cfg.right_segments` (side=1); left side appends `cfg.trailer`, right side skips it. Each painted segment wraps in its pre-computed SGR opener + `\x1b[0m` reset; emits raw when SGR is 0. **Plain mode** (default): segments joined by `cfg.separator`. **Powerline mode** (`cfg.separator_style == 1`): adjacent segments separated by `<fg=prev_bg; bg=next_bg>` SGR + glyph + reset; trailing transition (`fg=last_bg; bg=default`) closes the chain when last segment has a bg. `_sgr_for(cfg, name)` and `_bg_for(cfg, name)` mirror `_seg_fn_for` for SGR / raw-bg resolution. Unknown segments warn to stderr |
| `src/shellout.cyr` | **M3 (0.4.0)** — generic per-call timeout watchdog. `shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen)` returns bytes / `-1` (system error) / `-2` (timeout). Implements fork + pipe + `epoll_wait(timeout)` + `kill(SIGKILL)` on overrun + `waitpid` reap. See [`architecture/002-shellout-watchdog.md`](../architecture/002-shellout-watchdog.md) |
| `src/cache.cyr` | **M6 (0.7.0) + agnos degrade (1.1.4)** — per-segment per-cwd probe cache backed by `/tmp/commandress-<uid>/`. `cache_init()` (idempotent 0o700 mkdir), `cache_get(seg, cwd, ttl_secs)` (stat mtime → read if fresh, else 0), `cache_put(seg, cwd, value, len)`. djb2 32-bit hash on cwd → 8 hex chars for the filename. `""` is a real cached value (distinguishable from miss) so segments can cache the no-output case. **HOST-ONLY**: `_cache_stat` fails closed on agnos and `cache_init` sets `_cache_disabled` there before any of the file's Linux-shaped raw syscalls can run — agnos's `stat` struct has no `st_uid`, `getuid` is a stub returning 0, and `sys_mkdir` takes no mode, so the F-3 ownership audit cannot be satisfied. Nothing is lost: `shellout_capture` already returns -1 on agnos, so no cacheable value is ever produced |
| `src/pathlookup.cyr` | **M4 (0.5.0)** — `find_in_path(name)` walks `$PATH`, returns the first heap-alloc'd absolute-path cstring that passes `access(X_OK)` (or 0). Lifted from `src/segments/vcs.cyr` once `cyrius_env` became a second shellout consumer. Still pending Cyrius v6.x Item 8 upstream |
| `src/fslookup.cyr` | **M4 (0.5.0)** — shared fs helpers used by every language-env segment. `find_ancestor_with(start_dir, marker)` walks cwd upward returning the dir containing `<dir><marker>`, or 0. `read_trimmed_file_at(root, suffix)` reads `<root><suffix>` (256-byte cap) and trims surrounding ws (space, tab, `\n`, `\r`). Marker must start with `/` (e.g. `"/cyrius.cyml"`) so the root-case join is correct |
| `src/color.cyr` | **M5 (0.6.0)** — ANSI SGR helpers. `color_to_sgr_fg(name)` / `color_to_sgr_bg(name)` map 16 named colours (8 standard + 8 bright) + `"default"` to SGR ints (30..37 / 90..97 fg; bg = fg + 10; 0 for absent/default/unknown). `style_to_sgr_mods(s, codes, max)` parses space-separated tokens (bold / italic / underline / reverse) writing mod codes as i64s. `sgr_open_for(fg, bg, style)` composes the `"\x1b[<mods>;<fg>;<bg>m"` opener, returns 0 when nothing to emit. `SGR_RESET` is `"\x1b[0m"`. Render closes every styled segment with `SGR_RESET` so terminal-defaults aren't leaked between segments |
| `src/segments/cwd.cyr` | **M1 + M5 (0.6.0)** — `getcwd` + optional `$HOME` → `~` shortening (strict-prefix only) + optional `max_length` truncation at `/` boundaries (`_truncate_cwd` helper: walks left→right for earliest `/` whose suffix fits `max_length - 3`; pathological `< 4` emits a row of `.` dots; no-qualifying-`/` falls back to `...` + raw tail) |
| `src/segments/exit.cyr` | M1 — empty on 0, `[N]` otherwise; `hide_zero = false` paints `[0]` too |
| `src/segments/vcs.cyr` | **M2 (0.3.0) + watchdog (0.4.0) + pathlookup lift (0.5.0) + cache (0.7.0)** — getcwd → `cache_get("vcs", cwd, 1)` short-circuit. On miss: shells out to `sit status` via `shellout_capture` (5 ms budget), parses `On branch <name>` + dirty/clean substring, caches the result (including `""` for no-output cases so the next redraw also skips the fork). 1 s TTL means rapid redraws within a single keystroke burst share one fork+exec. Config-overridable `[[segments.vcs]] budget_ms = N` plumbing is a follow-up slot |
| `src/segments/time.cyr` | **M3 (0.4.0)** — strftime-subset formatter (`%H %M %S %Y %y %m %d %%`; unsupported specs pass through literal). UTC via `CLOCK_REALTIME`; local-time / `TZ` is a future slot. Default format `"%H:%M"`; config-overridable via `[[segments.time]] format = ...` |
| `src/segments/hostname.cyr` | **M3 (0.4.0)** — `uname(2)` nodename. One syscall, no config knobs |
| `src/segments/user.cyr` | **M3 (0.4.0)** — `getuid()` + `lib/pwd.cyr` direct /etc/passwd reader (musl-style; no glibc NSS). Falls back to `$USER`, then empty. No config knobs |
| `src/segments/cyrius_env.cyr` | **M4 (0.5.0)** — Cyrius project segment. Walks ancestors for `cyrius.cyml`, reads `<root>/VERSION`, falls back to `cyrius --version` shellout (5 ms budget). Emits raw version string. Per [ADR 0005](../adr/0005-language-env-probe-pattern.md) |
| `src/segments/python_env.cyr` | **M4 (0.5.0)** — Python project/venv segment. `$VIRTUAL_ENV` basename first, else `.python-version` ancestor walk + read+trim. `python --version` shellout deferred pre-v1. Per ADR 0005 |
| `src/segments/node_env.cyr` | **M4 (0.5.0)** — Node project segment. `.nvmrc` ancestor walk + read+trim. Passes numeric (`20.11.1`) and channel-style (`lts/iron`) content verbatim. `package.json engines.node` + `node --version` shellout deferred. Per ADR 0005 |
| `src/segments/rustup_env.cyr` | **M4 (0.5.0)** — Rust toolchain segment. Plain-format `rust-toolchain` ancestor walk + read+trim. `rust-toolchain.toml` deferred (blocked on Cyrius single-bracket TOML, papercut Item 3); `rustup show` shellout deferred per file-first policy. Per ADR 0005 |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: **168,264 B** on Cyrius 6.5.35, x86_64 (text 162,839 B; bss 2,544 B). Up from 147,600 B by **+20,664 B (+14.0 %)** at the 1.1.4 refresh — attributable to the **vendored stdlib snapshot, not codegen**: the local wrapper was already `cycc 6.5.35` before the bump (that was the drift), so the pre-bump baseline built the same `src/` with the same compiler against the old `lib/` and measured 147,600 B (text 143,049 B; bss 2,464 B). Roughly half the growth is unreached code — the build's dead-code note moves from `318 unreachable fns (58,189 B)` to `384 unreachable fns (69,382 B)`, all eliminable with `CYRIUS_DCE=1`. Net win vs the 0.3.0 baseline (395,115 B) is still **−226,851 B**.
- `--agnos` cross-build: **164,056 B** (text 157,478 B; bss 2,496 B). Clean since the 1.1.4 `cache.cyr` fix; Cyrius 6.5.1 made the `sys_stat` arity mismatch a hard error.
- Historical: **147,600 B** on 6.4.66 was the 1.1.3 figure (text 141,329 B; bss 2,464 B), itself down from 210,144 B on 6.2.24. **202,561 B** on Cyrius 5.11.64 (text 143,265 B; bss 59,296 B) was the v1.0.x figure — 200,667 B at the 0.7.0 baseline + **1,894 B** for the M8 audit fixes (F-1 sanitization helper, F-3 cache-dir mode-verify, F-4 O_NOFOLLOW, F-5 atomic temp+rename, F-7 parse_last_exit, F-8 absolute-only PATH walker).

## Benchmarks

Captured 2026-08-26 at the 1.1.4 refresh on the dev host (Linux 7.1.9-arch1-2, x86_64). The 6.5.x bench harness subtracts a measured timer floor (~1.256 µs per clock read) from every sample:

| Operation | Avg | Min | Max |
|---|---|---|---|
| `cwd_render` | 715 ns | 684 ns | 933 ns |
| `exit_render(nonzero)` | 37 ns | 34 ns | 49 ns |
| `config_default` | 2.819 µs | 2.696 µs | 3.170 µs |
| `vcs_parse_render` (pure parser) | 232 ns | 228 ns | 252 ns |
| **`vcs_render` (cached, 1s TTL)** | **8.907 µs** | **6.491 µs** | **25.488 µs** |
| `cyrius_env_parse_version` (pure parser) | 80 ns | 75 ns | 133 ns |
| `cyrius_env_render` (file path, no shellout) | 6.012 µs | 5.636 µs | 7.085 µs |
| `python_env_basename` (pure parser) | 90 ns | 86 ns | 102 ns |
| `python_env_render` (empty walk) | 12.593 µs | 12.173 µs | 13.205 µs |
| `node_env_render` (empty walk) | 4.961 µs | 4.603 µs | 5.673 µs |
| `rustup_env_render` (empty walk) | 5.091 µs | 4.671 µs | 6.981 µs |
| `render_prompt (default cwd+vcs+exit)` | 10.851 µs | 10.702 µs | 11.092 µs |

Budget: 5 ms cold start total ([`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)). **M6 headline**: `vcs_render` **4.6 ms → ~9 µs avg** with the 1 s TTL cache (the `max` is the one cold call that warms the entry; the remaining reads in the bench are the average). `render_prompt (default cwd+vcs+exit)` is **10.851 µs** — even with vcs in the default set, the cold-start budget is **0.2 % consumed**, and the 1.1.4 stdlib refresh moved it by ~0.3 µs (10.553 µs → 10.851 µs), i.e. noise. The bench-gate CI step is wired to fail above 5 ms; comfortable headroom. Per-release numbers append to [`benchmarks/history.csv`](../benchmarks/history.csv) for trend visibility — note that `bench-history.sh` silently recorded nothing between 0.9.0 and 1.1.4 (decimal-average rows failed its skip-filter; fixed in 1.1.4), so the CSV has no rows for the releases in that span.

## Tests

- `tests/commandress.tcyr` — **279 assertions across 131 tests**: full M1–M7 coverage + M8 audit-fix additions for `sanitize_segment_output` (8 cases — F-1), cache hardening (2 cases — F-3/F-4/F-5: mode-0o600 stat-verify, symlink-swap refuses), `parse_last_exit` (6 cases — F-7), and `find_in_path_with` (3 cases — F-8 relative-rejected / dot-rejected / absolute-resolves-including-mixed). `cyrius test` green.
- `tests/commandress.bcyr` — per-segment + config + parser + full-prompt timings (above).
- `tests/commandress.fcyr` — fuzz stub (no harness yet).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert` (and via includes: `cyml`, `toml`, `fnptr`, `bench`).

The declared `[deps]` surface is stable across releases; the **vendored `lib/` snapshot** is re-synced to the pinned toolchain per refresh (`cyrius lib sync --full`). Last resync: **1.1.4 → the 6.5.35 pin** (60 libs updated, 2 added, 0 removed). A stale snapshot surfaces at build time as a `./lib/ shadows version-pinned …/lib — N bundled lib(s) differ` warning — the signal to re-sync. Note `cyrius deps` alone does **not** refresh the snapshot; it resolves declared `[deps]`, which for a stdlib-only project is a no-op (no `cyrius.lock` is produced, so `cyrius deps --verify` reports none — expected, not a fault).

External: none (and none planned for v1.0).

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

- **M9 closed in 1.0.0** (tagged 2026-05-18): doc roll only — CHANGELOG 1.0.0 headline, README refresh, state + roadmap close-out. No code changes. Public API frozen per ADR 0007.
- **agnoshi adoption pending**: `/home/macro/Repos/agnoshi/src/prompt.cyr` currently renders its own prompt. When agnoshi reads `$AGNOSHI_PROMPT_CMD` per redraw (5-point contract documented in `adapters/agnoshi.sh`, with F-12 no-re-expand rule), users sourcing the adapter get a commandress-rendered prompt with no further commandress change.
- **Deferred behind upstream gaps**:
  - `rust-toolchain.toml` parsing — blocked on Cyrius single-bracket TOML (papercut Item 3, v6.x).
  - `find_in_path` itself — pending Cyrius v6.x Item 8 (no stdlib `which()`); the `src/pathlookup.cyr` workaround ships.
  - LSP transitive-include false positives across `src/render.cyr` — Cyrius Item 4, v6.x. Build is clean; the noise stays.
- **Deferred by policy (file-first, per user direction 2026-05-18)**:
  - `python --version`, `node --version`, `rustup show` shellouts. The cache infrastructure makes these affordable when they land — parked for post-v1.
  - `package.json` `engines.node` parsing. JSON-walk cost still not justified.
- **Binary size drifting up with the stdlib snapshot** (noted 1.1.4): each resync pulls larger vendored libs, and ~half of 1.1.4's +20,664 B is code the linker never reaches (`384 unreachable fns (69,382 B)`). `CYRIUS_DCE=1` eliminates it today but is not wired into the build or CI. Worth deciding at the next refresh whether DCE becomes the default for release builds — size is not budgeted (render time is), so this is hygiene, not a regression against a stated target.
- **Post-v1 theme-switching path**: single-palette `[[palette]]` shipped 0.6.0; curated `docs/themes/` library shipped 0.6.1; multi-palette `[[palettes.<name>]]` + top-level `palette = "<name>"` selector remains the next theme-track move under the additive-only contract in ADR 0007.
- **Next**: **post-v1 cadence**. Public surface is frozen; new work is additive per ADR 0007 or goes through the documented 3-step deprecation path. Driver list is the deferred items above plus whatever downstream consumers request.

## Next

See [`roadmap.md`](roadmap.md).
