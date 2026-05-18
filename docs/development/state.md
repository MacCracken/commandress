# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.2.0** — tagged release 2026-05-17. Config loader + table-driven render. Work for **0.3.0** in flight on `main`: VCS context segment via `sit` (M2 from roadmap).

## Role

Structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Binary name: `cmdrs`. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius.

## Toolchain

- **Cyrius pin**: `5.11.59` (in `cyrius.cyml [package].cyrius`)

## Source

| Module | Status |
|---|---|
| `src/main.cyr` | M1 — loads config, builds Context, dispatches to `render_prompt(cfg, ctx)` |
| `src/config.cyr` | **M1 (0.2.0)** — CYML loader for `~/.commandress.cyml`. Schema: `[[prompt]]` (segments, separator, trailer) + `[[segments.cwd]]` (home_shorten) + `[[segments.exit]]` (hide_zero). Defaults baked in; missing file → defaults; unknown fields warn to stderr |
| `src/context.cyr` | **M1 (0.2.0)** — `{ home, last_exit }` per-invocation context handed to every segment dispatcher |
| `src/render.cyr` | **M1 (0.2.0)** — table-driven registry (name → dispatcher fn ptr), walks `cfg.segments` array via `fncall2`, paints with `cfg.separator`/`cfg.trailer`, unknown segments warn to stderr |
| `src/segments/cwd.cyr` | M1 — `getcwd` + optional `$HOME` → `~` shortening (strict-prefix only) |
| `src/segments/exit.cyr` | M1 — empty on 0, `[N]` otherwise; `hide_zero = false` paints `[0]` too |
| `src/segments/vcs.cyr` | **M2 (0.3.0)** — shells out to `sit status` via inline fork+pipe (process.cyr's `_exec3` has a buffer-size bug; see upstream filing). Parses `On branch <name>` + scans for `nothing to commit, working tree clean`. Emits `<branch>` (clean) or `<branch><dirty_marker>` (dirty). Renders empty outside a sit repo, when sit isn't on PATH, or on parse failure. PATH lookup is inline (`_find_in_path`) because `lib/process.cyr` wraps bare `execve(2)` without libc-style PATH search. |
| `src/segments/time.cyr` | not started — wall-clock segment (M3) |
| `src/segments/hostname.cyr` | not started — hostname segment (M3) |
| `src/segments/user.cyr` | not started — user segment (M3) |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: **395,592 B** on Cyrius 5.11.59, x86_64. `.bss` bloat dominated by stdlib stack buffers (`lib/toml.cyr::toml_parse_file`'s 256 KB; others in `lib/io.cyr`, `lib/process.cyr`). Filed upstream — see [cyrius papercuts](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-17-commandress-stdlib-papercuts.md).

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

- `tests/commandress.tcyr` — **47 assertions across 21 tests**: cwd / exit / vcs-parser segments + config loader (defaults, missing-file, null-path, full + partial override, vcs section). `cyrius test` green.
- `tests/commandress.bcyr` — per-segment + config + parser + full-prompt timings (above).
- `tests/commandress.fcyr` — fuzz stub (no harness yet).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert` (and via includes: `cyml`, `toml`, `fnptr`, `bench`).

External: none (and none planned for v1.0).

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

- **Roadmap M2 feature-complete on `main`** (pending 0.3.0 tag): VCS segment shells out to `sit` (ADR 0004), parses branch + dirty/clean, renders empty outside a sit repo. Per-segment timeout enforcement deferred to v0.4.0 (M2's remaining roadmap item — `sit status` is fast in practice; a non-blocking pipe + `poll`-with-timeout watchdog earns its own slot).
- Upstream filings during 0.3.0 (will be appended to the existing papercut doc):
  - **`lib/process.cyr::_exec3` argv-buffer size bug** — `var argv[4]` is 4 bytes but stores 5 pointers (40 B). Silent stack overflow; the reason `run_capture("/bin/echo", "hello", 0, ...)` returns 1 byte instead of 6. Commandress's `src/segments/vcs.cyr` inlines its own fork+pipe to avoid the trap.
  - **`lib/process.cyr`'s vec-based `exec_capture` doesn't redirect stderr** — only `run_capture` (the cstr 2-arg variant) dup2's stderr to /dev/null. Both should.
  - **No PATH-lookup helper in stdlib** — every consumer that wants `execvp`-style semantics rolls its own (`_find_in_path` in vcs.cyr). Worth a proposal for `run_p` / `exec_p` variants.
- Next: tag 0.3.0, then start M3 (time, hostname, user segments per roadmap).

## Next

See [`roadmap.md`](roadmap.md).
