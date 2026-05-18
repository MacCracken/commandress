# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.4.0** — tagged release 2026-05-18. M3 closed: per-segment timeout watchdog (M2 carry-over) + time / hostname / user segments. Next milestone: **M4 — language-env segments** (python_env / node_env / rustup_env).

## Role

Structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Binary name: `cmdrs`. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius.

## Toolchain

- **Cyrius pin**: `5.11.63` (in `cyrius.cyml [package].cyrius`)

## Source

| Module | Status |
|---|---|
| `src/main.cyr` | M1 — loads config, builds Context, dispatches to `render_prompt(cfg, ctx)` |
| `src/config.cyr` | **M1 + M3 (0.4.0)** — CYML loader for `~/.commandress.cyml`. Schema: `[[prompt]]` (segments, separator, trailer) + `[[segments.cwd]]` (home_shorten) + `[[segments.exit]]` (hide_zero) + `[[segments.vcs]]` (show_dirty, dirty_marker) + `[[segments.time]]` (format). Defaults baked in; missing file → defaults; unknown fields warn to stderr |
| `src/context.cyr` | **M1 (0.2.0)** — `{ home, last_exit }` per-invocation context handed to every segment dispatcher |
| `src/render.cyr` | **M1 + M3 (0.4.0)** — table-driven registry (name → dispatcher fn ptr); paints `cfg.segments` joined by `cfg.separator`, `cfg.trailer` always. Dispatchers wired for `cwd`, `exit`, `vcs`, `time`, `hostname`, `user`; unknown segments warn to stderr |
| `src/shellout.cyr` | **M3 (0.4.0)** — generic per-call timeout watchdog. `shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen)` returns bytes / `-1` (system error) / `-2` (timeout). Implements fork + pipe + `epoll_wait(timeout)` + `kill(SIGKILL)` on overrun + `waitpid` reap. See [`architecture/002-shellout-watchdog.md`](../architecture/002-shellout-watchdog.md) |
| `src/segments/cwd.cyr` | M1 — `getcwd` + optional `$HOME` → `~` shortening (strict-prefix only) |
| `src/segments/exit.cyr` | M1 — empty on 0, `[N]` otherwise; `hide_zero = false` paints `[0]` too |
| `src/segments/vcs.cyr` | **M2 (0.3.0) + watchdog (0.4.0)** — shells out to `sit status` via `shellout_capture` with a hardcoded 5 ms budget. Parses `On branch <name>` + scans for `nothing to commit, working tree clean`. Emits `<branch>` (clean) or `<branch><dirty_marker>` (dirty). Renders empty outside a sit repo, when sit isn't on PATH, on watchdog timeout, or on parse failure. PATH lookup is inline (`_find_in_path`) pending Cyrius v6.x Item 8. Config-overridable `[[segments.vcs]] budget_ms = N` plumbing is a follow-up slot |
| `src/segments/time.cyr` | **M3 (0.4.0)** — strftime-subset formatter (`%H %M %S %Y %y %m %d %%`; unsupported specs pass through literal). UTC via `CLOCK_REALTIME`; local-time / `TZ` is a future slot. Default format `"%H:%M"`; config-overridable via `[[segments.time]] format = ...` |
| `src/segments/hostname.cyr` | **M3 (0.4.0)** — `uname(2)` nodename. One syscall, no config knobs |
| `src/segments/user.cyr` | **M3 (0.4.0)** — `getuid()` + `lib/pwd.cyr` direct /etc/passwd reader (musl-style; no glibc NSS). Falls back to `$USER`, then empty. No config knobs |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: **152,234 B** on Cyrius 5.11.63, x86_64 (text 114,578 B; bss 37,656 B). Up from 140,155 B at the watchdog-only point by +12,079 B for the three new M3 segments (`time` + `hostname` + `user`) plus `lib/chrono.cyr`'s `epoch_to_date` machinery and `lib/pwd.cyr`'s /etc/passwd reader. Net win vs 0.3.0 baseline (395,115 B): **−242,881 B**, dominated by the .61 heap-alloc rewrite of `lib/toml.cyr::toml_parse_file` that reclaimed the 256 KB on-fn-scope buffer (`var buf[262144]`) DCE couldn't drop. See [cyrius papercuts (archived)](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/archived/2026-05-17-commandress-stdlib-papercuts.md).

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

- `tests/commandress.tcyr` — **65 assertions across 35 tests**: cwd / exit / vcs-parser / time / hostname / user segments + config loader (defaults, missing-file, null-path, full + partial override, vcs section) + shellout watchdog (happy path via `/bin/echo`, timeout-kills-child via `/bin/sleep 1` with 10 ms budget). Time-segment tests pin epoch inputs (`3725`, `0`, `1767225600`) for deterministic byte-for-byte assertion. Hostname compares byte-for-byte against direct `uname(2)`. User skips when both /etc/passwd and `$USER` are absent. `cyrius test` green.
- `tests/commandress.bcyr` — per-segment + config + parser + full-prompt timings (above).
- `tests/commandress.fcyr` — fuzz stub (no harness yet).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert` (and via includes: `cyml`, `toml`, `fnptr`, `bench`).

External: none (and none planned for v1.0).

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

- **M3 closed in 0.4.0** (tagged 2026-05-18): per-segment timeout watchdog (`src/shellout.cyr`) + `time` / `hostname` / `user` segments. Default segments stay `["cwd", "exit"]` — new segments are opt-in.
- **Cyrius pin → 5.11.63** absorbed the .60-.63 commandress papercut band; bss dropped ~256 KB from the `lib/toml.cyr` heap-alloc rewrite.
- Upstream filings during 0.3.0 (Cyrius `2026-05-17-commandress-stdlib-papercuts.md`, archived after the .60–.63 band):
  - ✅ **Item 6 — `_exec3` argv-buffer byte-contract bug** (Cyrius 5.11.60). `var argv[4]` was 4 bytes but stored 5 pointers (40 B). Silent stack corruption; the reason `run_capture("/bin/echo", "hello", 0, ...)` returned 1 byte instead of 6. Commandress's inline fork+pipe in `src/segments/vcs.cyr` is no longer load-bearing.
  - ✅ **Item 7 — vec-based `exec_capture` family missed stderr dup2** (Cyrius 5.11.60). All four vec exec fns now mirror `run_capture`'s `dup2(/dev/null, 2)`.
  - ✅ **Item 2 — `toml_parse_file` 256 KB on-fn-scope buffer** (Cyrius 5.11.61). Heap-alloc'd; commandress's bss dropped 262 KB on the 5.11.63 rebuild.
  - ✅ **Item 5 — `large static data` warning DCE attribution** (Cyrius 5.11.62). Warning now reports how many of the bytes sit inside unreachable fns.
  - ✅ **Item 1 — `cyrius init` bench scaffold** (Cyrius 5.11.62). Fresh scaffolds now compile and run end-to-end against the real `bench_new` API.
  - ⏸ **Item 8 — no PATH-lookup helper in stdlib** — deferred to Cyrius v6.x. `_find_in_path` in `vcs.cyr` stays for now.
  - Items 3 (toml `[name]` single-bracket sections) and 4 (LSP transitive-include false positives) also deferred to Cyrius v6.x.
- Next: **M4 — language-env segments** (`python_env`, `node_env`, `rustup_env`). M4 entry-work: lift `_find_in_path` from `src/segments/vcs.cyr` to a shared util so the new shellout-backed segments share PATH lookup. Config-overridable `budget_ms` for the shellout segments is also a sibling slot.

## Next

See [`roadmap.md`](roadmap.md).
