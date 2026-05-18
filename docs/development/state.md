# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.5.0** — tagged release 2026-05-18. M4 closed: four language-env segments (`cyrius_env`, `python_env`, `node_env`, `rustup_env`) + two shared fs/path utility modules + ADR 0005 capturing the file-first probe pattern. Next milestone: **M5 — theming + visuals** (ANSI palette, separators, right-prompt, themed examples, cwd length-truncation deferred from M1).

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
| `src/render.cyr` | **M1 + M3 (0.4.0) + M4 (0.5.0)** — table-driven registry (name → dispatcher fn ptr); paints `cfg.segments` joined by `cfg.separator`, `cfg.trailer` always. Dispatchers wired for `cwd`, `exit`, `vcs`, `time`, `hostname`, `user`, `cyrius_env`, `python_env`, `node_env`, `rustup_env`; unknown segments warn to stderr |
| `src/shellout.cyr` | **M3 (0.4.0)** — generic per-call timeout watchdog. `shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen)` returns bytes / `-1` (system error) / `-2` (timeout). Implements fork + pipe + `epoll_wait(timeout)` + `kill(SIGKILL)` on overrun + `waitpid` reap. See [`architecture/002-shellout-watchdog.md`](../architecture/002-shellout-watchdog.md) |
| `src/pathlookup.cyr` | **M4 (0.5.0)** — `find_in_path(name)` walks `$PATH`, returns the first heap-alloc'd absolute-path cstring that passes `access(X_OK)` (or 0). Lifted from `src/segments/vcs.cyr` once `cyrius_env` became a second shellout consumer. Still pending Cyrius v6.x Item 8 upstream |
| `src/fslookup.cyr` | **M4 (0.5.0)** — shared fs helpers used by every language-env segment. `find_ancestor_with(start_dir, marker)` walks cwd upward returning the dir containing `<dir><marker>`, or 0. `read_trimmed_file_at(root, suffix)` reads `<root><suffix>` (256-byte cap) and trims surrounding ws (space, tab, `\n`, `\r`). Marker must start with `/` (e.g. `"/cyrius.cyml"`) so the root-case join is correct |
| `src/segments/cwd.cyr` | M1 — `getcwd` + optional `$HOME` → `~` shortening (strict-prefix only) |
| `src/segments/exit.cyr` | M1 — empty on 0, `[N]` otherwise; `hide_zero = false` paints `[0]` too |
| `src/segments/vcs.cyr` | **M2 (0.3.0) + watchdog (0.4.0) + pathlookup lift (0.5.0)** — shells out to `sit status` via `shellout_capture` with a hardcoded 5 ms budget. Parses `On branch <name>` + scans for `nothing to commit, working tree clean`. Emits `<branch>` (clean) or `<branch><dirty_marker>` (dirty). Renders empty outside a sit repo, when sit isn't on PATH, on watchdog timeout, or on parse failure. PATH lookup now via `src/pathlookup.cyr::find_in_path`. Config-overridable `[[segments.vcs]] budget_ms = N` plumbing is a follow-up slot |
| `src/segments/time.cyr` | **M3 (0.4.0)** — strftime-subset formatter (`%H %M %S %Y %y %m %d %%`; unsupported specs pass through literal). UTC via `CLOCK_REALTIME`; local-time / `TZ` is a future slot. Default format `"%H:%M"`; config-overridable via `[[segments.time]] format = ...` |
| `src/segments/hostname.cyr` | **M3 (0.4.0)** — `uname(2)` nodename. One syscall, no config knobs |
| `src/segments/user.cyr` | **M3 (0.4.0)** — `getuid()` + `lib/pwd.cyr` direct /etc/passwd reader (musl-style; no glibc NSS). Falls back to `$USER`, then empty. No config knobs |
| `src/segments/cyrius_env.cyr` | **M4 (0.5.0)** — Cyrius project segment. Walks ancestors for `cyrius.cyml`, reads `<root>/VERSION`, falls back to `cyrius --version` shellout (5 ms budget). Emits raw version string. Per [ADR 0005](../adr/0005-language-env-probe-pattern.md) |
| `src/segments/python_env.cyr` | **M4 (0.5.0)** — Python project/venv segment. `$VIRTUAL_ENV` basename first, else `.python-version` ancestor walk + read+trim. `python --version` shellout deferred pre-v1. Per ADR 0005 |
| `src/segments/node_env.cyr` | **M4 (0.5.0)** — Node project segment. `.nvmrc` ancestor walk + read+trim. Passes numeric (`20.11.1`) and channel-style (`lts/iron`) content verbatim. `package.json engines.node` + `node --version` shellout deferred. Per ADR 0005 |
| `src/segments/rustup_env.cyr` | **M4 (0.5.0)** — Rust toolchain segment. Plain-format `rust-toolchain` ancestor walk + read+trim. `rust-toolchain.toml` deferred (blocked on Cyrius single-bracket TOML, papercut Item 3); `rustup show` shellout deferred per file-first policy. Per ADR 0005 |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: **176,088 B** on Cyrius 5.11.63, x86_64 (text 121,520 B; bss 54,568 B). Up from 152,234 B at the 0.4.0 baseline by **+23,854 B** for four new language-env segments + two shared utility modules (`src/pathlookup.cyr`, `src/fslookup.cyr`). Text grew +6,942 B (the four segments are file-walk-only — `node_env.cyr` is 20 lines, `rustup_env.cyr` is 18). bss grew +16,912 B (per-segment file-scope buffers). The read+trim duplication collapsed into `read_trimmed_file_at` clawed back ~1.4 KB. Net win vs 0.3.0 baseline (395,115 B): **−219,027 B**.

## Benchmarks

Captured 2026-05-18 on the dev host (Linux 7.0.5-arch1-1, x86_64):

| Operation | Avg | Min | Max |
|---|---|---|---|
| `cwd_render` | 668 ns | 613 ns | 919 ns |
| `exit_render(nonzero)` | 37 ns | 35 ns | 49 ns |
| `config_default` | 166 ns | 143 ns | 655 ns |
| `vcs_parse_render` (pure parser) | 220 ns | 214 ns | 247 ns |
| `vcs_render` (fork + `sit status` + parse) | **1.836 ms** | 1.719 ms | 2.202 ms |
| `cyrius_env_parse_version` (pure parser) | 76 ns | 72 ns | 94 ns |
| `cyrius_env_render` (file path, no shellout) | 7 µs | 6 µs | 8 µs |
| `python_env_basename` (pure parser) | 98 ns | 95 ns | 104 ns |
| `python_env_render` (empty walk) | 12 µs | 12 µs | 13 µs |
| `node_env_render` (empty walk) | 6 µs | 5 µs | 6 µs |
| `rustup_env_render` (empty walk) | 6 µs | 5 µs | 6 µs |
| `render_prompt (cwd+exit)` | 2 µs | 2 µs | 2 µs |

Budget: 5 ms cold start total ([`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)). The `vcs_render` line is still the heavy one — fork + exec of `sit` + read pipe + waitpid. At 1.8 ms it's ~37 % of the cold-start budget *on its own*. The four new M4 env segments combined sum to ~31 µs — three orders of magnitude under the budget, because they're file-walk-only in v0.5.0 (no fork/exec). Cached probe results across rapid redraws (M6) close the vcs cost; the env segments stay fast either way.

## Tests

- `tests/commandress.tcyr` — **130 assertions across 67 tests**: cwd / exit / vcs-parser / time / hostname / user / cyrius_env / python_env / node_env / rustup_env segments + config loader + shellout watchdog + pathlookup. Helper tests are hermetic — each writes to a fresh `/tmp/cmdrs_<name>_tst*` directory and cleans up. `cyrius test` green.
- `tests/commandress.bcyr` — per-segment + config + parser + full-prompt timings (above). Includes `pathlookup` / `fslookup` / `shellout` / `chrono` / `pwd` (gap fixed mid-M4 — without them, later benches would have crashed on undefined-symbol references).
- `tests/commandress.fcyr` — fuzz stub (no harness yet).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert` (and via includes: `cyml`, `toml`, `fnptr`, `bench`).

External: none (and none planned for v1.0).

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

- **M4 closed in 0.5.0** (tagged 2026-05-18): four language-env segments (`cyrius_env`, `python_env`, `node_env`, `rustup_env`) + two shared utility modules (`src/pathlookup.cyr`, `src/fslookup.cyr`) + [ADR 0005](../adr/0005-language-env-probe-pattern.md) capturing the file-first probe pattern. Default segments stay `["cwd", "exit"]` — env segments are opt-in.
- **Deferred behind upstream gaps**:
  - `rust-toolchain.toml` parsing — blocked on Cyrius single-bracket TOML (papercut Item 3, v6.x). Workaround-ship not feasible for an externally-defined format we don't control.
  - `find_in_path` itself — still pending Cyrius v6.x Item 8 (no stdlib `which()`); the `src/pathlookup.cyr` workaround ships.
  - LSP transitive-include false positives across `src/render.cyr` — Cyrius Item 4, v6.x. Build is clean; the noise stays.
- **Deferred by policy (file-first, per user direction 2026-05-18)**:
  - `python --version`, `node --version`, `rustup show` shellouts. Parked pre-v1 alongside M6 caching, which is the change that makes per-redraw version probes affordable.
  - `package.json` `engines.node` parsing. Same reasoning — version-range parsing isn't worth the JSON-walk cost without caching.
- Next: **M5 — theming + visuals** (ANSI palette in config, segment separator glyphs, right-prompt support if the shell exposes it, themed examples in `docs/themes/`, cwd length-truncation deferred from M1).

## Next

See [`roadmap.md`](roadmap.md).
