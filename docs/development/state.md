# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.3.0** — tagged release 2026-05-17. VCS segment via `sit`. Work in flight on `main`: per-segment timeout watchdog landed (M2 carry-over closed); M3 segments (time, hostname, user) pending. Next tag TBD.

## Role

Structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Binary name: `cmdrs`. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius.

## Toolchain

- **Cyrius pin**: `5.11.63` (in `cyrius.cyml [package].cyrius`)

## Source

| Module | Status |
|---|---|
| `src/main.cyr` | M1 — loads config, builds Context, dispatches to `render_prompt(cfg, ctx)` |
| `src/config.cyr` | **M1 (0.2.0)** — CYML loader for `~/.commandress.cyml`. Schema: `[[prompt]]` (segments, separator, trailer) + `[[segments.cwd]]` (home_shorten) + `[[segments.exit]]` (hide_zero) + `[[segments.vcs]]` (show_dirty, dirty_marker). Defaults baked in; missing file → defaults; unknown fields warn to stderr |
| `src/context.cyr` | **M1 (0.2.0)** — `{ home, last_exit }` per-invocation context handed to every segment dispatcher |
| `src/render.cyr` | **M1 (0.2.0)** — table-driven registry (name → dispatcher fn ptr), walks `cfg.segments` array via `fncall2`, paints with `cfg.separator`/`cfg.trailer`, unknown segments warn to stderr |
| `src/shellout.cyr` | **M2 carry-over (Unreleased)** — generic per-call timeout watchdog. `shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen)` returns bytes / `-1` (system error) / `-2` (timeout). Implements fork + pipe + `epoll_wait(timeout)` + `kill(SIGKILL)` on overrun + `waitpid` reap. See [`architecture/002-shellout-watchdog.md`](../architecture/002-shellout-watchdog.md) |
| `src/segments/cwd.cyr` | M1 — `getcwd` + optional `$HOME` → `~` shortening (strict-prefix only) |
| `src/segments/exit.cyr` | M1 — empty on 0, `[N]` otherwise; `hide_zero = false` paints `[0]` too |
| `src/segments/vcs.cyr` | **M2 (0.3.0) + watchdog (Unreleased)** — shells out to `sit status` via `shellout_capture` with a hardcoded 5 ms budget. Parses `On branch <name>` + scans for `nothing to commit, working tree clean`. Emits `<branch>` (clean) or `<branch><dirty_marker>` (dirty). Renders empty outside a sit repo, when sit isn't on PATH, on watchdog timeout, or on parse failure. PATH lookup is inline (`_find_in_path`) pending Cyrius v6.x Item 8. Config-overridable `[[segments.vcs]] budget_ms = N` plumbing is a follow-up slot. |
| `src/segments/time.cyr` | not started — wall-clock segment (M3) |
| `src/segments/hostname.cyr` | not started — hostname segment (M3) |
| `src/segments/user.cyr` | not started — user segment (M3) |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: **140,155 B** on Cyrius 5.11.63, x86_64 (text 104,091 B; bss 36,064 B). Up from 133,451 B at the bare 5.11.63 bump by +6,704 B for the watchdog (`src/shellout.cyr`) + `lib/chrono.cyr` surface. Net win vs 5.11.59 baseline (395,115 B): **−254,960 B**, dominated by the .61 heap-alloc rewrite of `lib/toml.cyr::toml_parse_file` that reclaimed the 256 KB on-fn-scope buffer (`var buf[262144]`) DCE couldn't drop. See [cyrius papercuts (archived)](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/archived/2026-05-17-commandress-stdlib-papercuts.md).

## Benchmarks

Captured 2026-05-17 on the dev host (Linux 7.0.5-arch1-1, x86_64):

| Operation | Avg | Min | Max |
|---|---|---|---|
| `cwd_render` | 650 ns | 603 ns | 808 ns |
| `exit_render(nonzero)` | 38 ns | 36 ns | 53 ns |
| `config_default` | 146 ns | 136 ns | 218 ns |
| `vcs_parse_render` (pure parser) | 233 ns | 228 ns | 254 ns |
| `vcs_render` (fork + `sit status` + parse) | **1.814 ms** | 1.738 ms | 1.959 ms |
| `render_prompt (cwd+exit)` | 2 µs | 2 µs | 2 µs |

Budget: 5 ms cold start total ([`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)). The `vcs_render` line is the heavy one — fork + exec of `sit` + read pipe + waitpid. At 1.8 ms it's ~36 % of the cold-start budget *on its own*. Cached probe results across rapid redraws (M6) close this — 1 s TTL means typing inside a single prompt cycle doesn't re-pay it. For 0.3.0, vcs is opt-in (default segments stay `["cwd", "exit"]`) so this is only paid when the user enables it.

## Tests

- `tests/commandress.tcyr` — **51 assertions across 23 tests**: cwd / exit / vcs-parser segments + config loader (defaults, missing-file, null-path, full + partial override, vcs section) + shellout watchdog (happy path via `/bin/echo`, timeout-kills-child via `/bin/sleep 1` with 10 ms budget; each skips cleanly on host-tool absence). `cyrius test` green.
- `tests/commandress.bcyr` — per-segment + config + parser + full-prompt timings (above).
- `tests/commandress.fcyr` — fuzz stub (no harness yet).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert` (and via includes: `cyml`, `toml`, `fnptr`, `bench`).

External: none (and none planned for v1.0).

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

- **Per-segment timeout watchdog landed on `main`** (pending next tag): `src/shellout.cyr::shellout_capture` enforces a `budget_ms` deadline on any external shellout via fork + pipe + `epoll_wait` + `kill(SIGKILL)` + `waitpid`. `src/segments/vcs.cyr` switched from inline `_vcs_capture` to the helper with a hardcoded 5 ms budget. Closes the M2 deliverable that was carried forward to M3. See [`architecture/002-shellout-watchdog.md`](../architecture/002-shellout-watchdog.md).
- **Cyrius pin → 5.11.63** absorbed the .60-.63 commandress papercut band; bss dropped ~256 KB from the `lib/toml.cyr` heap-alloc rewrite.
- Upstream filings during 0.3.0 (Cyrius `2026-05-17-commandress-stdlib-papercuts.md`, archived after the .60–.63 band):
  - ✅ **Item 6 — `_exec3` argv-buffer byte-contract bug** (Cyrius 5.11.60). `var argv[4]` was 4 bytes but stored 5 pointers (40 B). Silent stack corruption; the reason `run_capture("/bin/echo", "hello", 0, ...)` returned 1 byte instead of 6. Commandress's inline fork+pipe in `src/segments/vcs.cyr` is no longer load-bearing.
  - ✅ **Item 7 — vec-based `exec_capture` family missed stderr dup2** (Cyrius 5.11.60). All four vec exec fns now mirror `run_capture`'s `dup2(/dev/null, 2)`.
  - ✅ **Item 2 — `toml_parse_file` 256 KB on-fn-scope buffer** (Cyrius 5.11.61). Heap-alloc'd; commandress's bss dropped 262 KB on the 5.11.63 rebuild.
  - ✅ **Item 5 — `large static data` warning DCE attribution** (Cyrius 5.11.62). Warning now reports how many of the bytes sit inside unreachable fns.
  - ✅ **Item 1 — `cyrius init` bench scaffold** (Cyrius 5.11.62). Fresh scaffolds now compile and run end-to-end against the real `bench_new` API.
  - ⏸ **Item 8 — no PATH-lookup helper in stdlib** — deferred to Cyrius v6.x. `_find_in_path` in `vcs.cyr` stays for now.
  - Items 3 (toml `[name]` single-bracket sections) and 4 (LSP transitive-include false positives) also deferred to Cyrius v6.x.
- Next: time / hostname / user segments (remaining M3 deliverables), then a config-overridable budget_ms slot for vcs.

## Next

See [`roadmap.md`](roadmap.md).
