# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.8.0** — tagged release 2026-05-18. **M7 closed**: first-party shell adapters under [`adapters/`](../../adapters/) — `zsh.sh` (precmd + PROMPT + RPROMPT), `bash.sh` (PROMPT_COMMAND + PS1 with `\001..\002` SGR-wrap for readline-width accounting), `agnoshi.sh` (contract-only; env-var spec until agnoshi adopts it). Users wire `cmdrs` into their shell with one `source` line. Zero Cyrius code changes this milestone — all shell-side glue + docs. Next: **M8 — public API + security audit** (schema freeze, security pass on config parsing / env-var handling / subprocess exec, benchmarks finalised).

## Role

Structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Binary name: `cmdrs`. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius.

## Toolchain

- **Cyrius pin**: `5.11.64` (in `cyrius.cyml [package].cyrius`)

## Source

| Module | Status |
|---|---|
| `src/main.cyr` | M1 — loads config, builds Context, dispatches to `render_prompt(cfg, ctx)` |
| `src/config.cyr` | **M1 + M3 (0.4.0) + M5 (0.6.0–0.6.1)** — CYML loader for `~/.commandress` (renamed from `~/.commandress.cyml` per ADR 0006). Schema: `[[prompt]]` (segments, right_segments, separator, trailer, separator_style, separator_glyph, right_separator_glyph) + `[[segments.cwd]]` (home_shorten, max_length, fg/bg/style) + `[[segments.exit]]` (hide_zero, fg/bg/style) + `[[segments.vcs]]` (show_dirty, dirty_marker, fg/bg/style) + `[[segments.time]]` (format, fg/bg/style) + `[[segments.{hostname,user,cyrius_env,python_env,node_env,rustup_env}]]` (fg/bg/style only) + optional `[[palette]]` (named-slot table referenced via `fg = "palette:<name>"`). Per-segment storage: pre-baked SGR cstring + raw bg cstring (the latter only used by powerline transitions). Defaults baked in (including opinionated default theme); partial-override-safe; missing file → defaults; unknown fields warn to stderr. `CFG_SIZE` 264 B |
| `src/context.cyr` | **M1 (0.2.0)** — `{ home, last_exit }` per-invocation context handed to every segment dispatcher |
| `src/render.cyr` | **M1 + M3 (0.4.0) + M4 (0.5.0) + M5 (0.6.0–0.6.1)** — table-driven registry (name → dispatcher fn ptr). `render_prompt(cfg, ctx, side)` paints either `cfg.segments` (side=0) or `cfg.right_segments` (side=1); left side appends `cfg.trailer`, right side skips it. Each painted segment wraps in its pre-computed SGR opener + `\x1b[0m` reset; emits raw when SGR is 0. **Plain mode** (default): segments joined by `cfg.separator`. **Powerline mode** (`cfg.separator_style == 1`): adjacent segments separated by `<fg=prev_bg; bg=next_bg>` SGR + glyph + reset; trailing transition (`fg=last_bg; bg=default`) closes the chain when last segment has a bg. `_sgr_for(cfg, name)` and `_bg_for(cfg, name)` mirror `_seg_fn_for` for SGR / raw-bg resolution. Unknown segments warn to stderr |
| `src/shellout.cyr` | **M3 (0.4.0)** — generic per-call timeout watchdog. `shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen)` returns bytes / `-1` (system error) / `-2` (timeout). Implements fork + pipe + `epoll_wait(timeout)` + `kill(SIGKILL)` on overrun + `waitpid` reap. See [`architecture/002-shellout-watchdog.md`](../architecture/002-shellout-watchdog.md) |
| `src/cache.cyr` | **M6 (0.7.0)** — per-segment per-cwd probe cache backed by `/tmp/commandress-<uid>/`. `cache_init()` (idempotent 0o700 mkdir), `cache_get(seg, cwd, ttl_secs)` (sys_stat mtime → read if fresh, else 0), `cache_put(seg, cwd, value, len)`. djb2 32-bit hash on cwd → 8 hex chars for the filename. `""` is a real cached value (distinguishable from miss) so segments can cache the no-output case |
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
- Size: **200,667 B** on Cyrius 5.11.64, x86_64 (text 141,555 B; bss 59,112 B). Up from 193,753 B at the 0.6.1 baseline by **+6,914 B** for `src/cache.cyr` (~150 LoC) + vcs's cache-wrap path + the default-segment-flip's extra "vcs" string slot. Text +2,618 B; bss +4,296 B (cache UID-stringification scratch + hash buffers). Net win vs 0.3.0 baseline (395,115 B): **−194,448 B**.

## Benchmarks

Captured 2026-05-18 on the dev host (Linux 7.0.5-arch1-1, x86_64):

| Operation | Avg | Min | Max |
|---|---|---|---|
| `cwd_render` | 670 ns | 613 ns | 808 ns |
| `exit_render(nonzero)` | 39 ns | 36 ns | 59 ns |
| `config_default` | 3 µs | 3 µs | 3 µs |
| `vcs_parse_render` (pure parser) | 232 ns | 225 ns | 260 ns |
| **`vcs_render` (cached, 1s TTL)** | **72 µs** | **6 µs** | **1.270 ms** |
| `cyrius_env_parse_version` (pure parser) | 75 ns | 70 ns | 99 ns |
| `cyrius_env_render` (file path, no shellout) | 7 µs | 7 µs | 8 µs |
| `python_env_basename` (pure parser) | 88 ns | 84 ns | 98 ns |
| `python_env_render` (empty walk) | 12 µs | 11 µs | 13 µs |
| `node_env_render` (empty walk) | 6 µs | 5 µs | 8 µs |
| `rustup_env_render` (empty walk) | 6 µs | 5 µs | 7 µs |
| `render_prompt (default cwd+vcs+exit)` | 10 µs | 9 µs | 10 µs |

Budget: 5 ms cold start total ([`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)). **M6 headline**: `vcs_render` **4.6 ms → 72 µs avg** with the 1 s TTL cache (the `max` of 1.270 ms is the one cold call that warms the entry; the remaining 99 reads in the bench averaged ~7 µs). `render_prompt (default cwd+vcs+exit)` is **10 µs** — even with vcs now in the default set, the cold-start budget is **0.2 % consumed**. The bench-gate CI step is wired to fail above 5 ms; comfortable headroom. Per-release numbers append to [`benchmarks/history.csv`](benchmarks/history.csv) for trend visibility.

## Tests

- `tests/commandress.tcyr` — **245 assertions across 112 tests**: full M1–M5 coverage + M6 additions for `cache` (4 cases — roundtrip, per-cwd isolation, empty-value caching, miss-when-absent) and the updated `test_config_defaults` asserting the new 3-segment default. `cyrius test` green.
- `tests/commandress.bcyr` — per-segment + config + parser + full-prompt timings (above).
- `tests/commandress.fcyr` — fuzz stub (no harness yet).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert` (and via includes: `cyml`, `toml`, `fnptr`, `bench`).

External: none (and none planned for v1.0).

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

- **M7 closed in 0.8.0** (tagged 2026-05-18): three shell adapters under [`adapters/`](../../adapters/) — `zsh.sh` (live), `bash.sh` (live), `agnoshi.sh` (contract-only; agnoshi hasn't adopted `$AGNOSHI_PROMPT_CMD` yet, but the spec lives in the file's header so adoption is wire-and-go). zsh + bash get matching setup guides under [`docs/guides/`](../guides/).
- **agnoshi adoption pending**: `/home/macro/Repos/agnoshi/src/prompt.cyr` currently renders its own prompt. When agnoshi reads `$AGNOSHI_PROMPT_CMD` per redraw (5-point contract documented in `adapters/agnoshi.sh`), users sourcing the adapter get a commandress-rendered prompt with no further commandress change.
- **Deferred behind upstream gaps**:
  - `rust-toolchain.toml` parsing — blocked on Cyrius single-bracket TOML (papercut Item 3, v6.x).
  - `find_in_path` itself — pending Cyrius v6.x Item 8 (no stdlib `which()`); the `src/pathlookup.cyr` workaround ships.
  - LSP transitive-include false positives across `src/render.cyr` — Cyrius Item 4, v6.x. Build is clean; the noise stays.
- **Deferred by policy (file-first, per user direction 2026-05-18)**:
  - `python --version`, `node --version`, `rustup show` shellouts. The cache infrastructure is now in place to make these affordable when they land — pre-v1 they remain parked.
  - `package.json` `engines.node` parsing. JSON-walk cost still not justified.
- **Pre-v1 theme-switching path** (per user commitment in M5 design): single-palette `[[palette]]` shipped 0.6.0; curated `docs/themes/` library shipped 0.6.1; multi-palette `[[palettes.<name>]]` + top-level `palette = "<name>"` selector planned for v0.7.x or v0.8.x; schema freeze (and path lock) at v0.9.0 (M8).
- **Next**: **M8 — public API + security audit** (freeze config schema; audit pass on config parsing / env-var handling / subprocess exec — write to `docs/audit/YYYY-MM-DD-audit.md`; finalise benchmark numbers; lock the path + field contract ahead of M9's v1.0 freeze). After M8: **M9 — v1.0 freeze + tag**.

## Next

See [`roadmap.md`](roadmap.md).
