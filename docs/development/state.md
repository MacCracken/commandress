# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — tagged release 2026-05-17. M1 segments (cwd + exit) + render pipeline + CI/release alignment with kriya. Work for **0.2.0** in flight on `main`: full CYML config loader.

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
| `src/segments/git.cyr` | not started — git branch/state segment (M2) |
| `src/segments/time.cyr` | not started — wall-clock segment (M3) |
| `src/segments/hostname.cyr` | not started — hostname segment (M3) |
| `src/segments/user.cyr` | not started — user segment (M3) |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: **374,168 B** (M1 cwd + exit + config loader, Cyrius 5.11.59, x86_64).
- Of which ~290 KB is `.bss`, ~256 KB of which is the stack buffer in `lib/toml.cyr::toml_parse_file` — an unreachable fn we drag in by including `lib/toml.cyr`. Filed upstream as [cyrius issue #2026-05-17 item 2](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-17-commandress-stdlib-papercuts.md). The `.text` section is **84 KB** (the actual code we ship).

## Benchmarks

Captured 2026-05-17 on the dev host (Linux 7.0.5-arch1-1, x86_64):

| Operation | Avg | Min | Max |
|---|---|---|---|
| `cwd_render` | 674 ns | 614 ns | 953 ns |
| `exit_render(nonzero)` | 38 ns | 36 ns | 53 ns |
| `config_default` | 140 ns | 131 ns | 219 ns |
| `render_prompt (cwd+exit)` | 2 µs | 2 µs | 2 µs |

Budget: 5 ms cold start total ([`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)). Current in-process render at 2 µs is **0.04 % of budget**; the table-driven dispatch added in 0.2.0 didn't move the needle.

## Tests

- `tests/commandress.tcyr` — **36 assertions across 12 tests**: cwd / exit segments + config loader (defaults, missing-file fallback, null-path fallback, full override, partial override). `cyrius test` green.
- `tests/commandress.bcyr` — per-segment + config_default + full-prompt timings (above).
- `tests/commandress.fcyr` — fuzz stub (no harness yet).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert` (and via includes: `cyml`, `toml`, `fnptr`, `bench`).

External: none (and none planned for v1.0).

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

- **Roadmap M1 complete on `main`** (pending 0.2.0 tag): cwd + exit segments, table-driven render pipeline, CYML config loader. Example config at [`docs/examples/commandress.cyml.example`](../examples/commandress.cyml.example).
- Upstream filings opened during the session:
  - [cyrius issue 2026-05-17 commandress papercuts](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-17-commandress-stdlib-papercuts.md) — 5 items (bench scaffold, toml static buf, LSP transitive includes, etc.).
  - [cyrius proposal 2026-05-17 toml single-bracket sections](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-17-toml-single-bracket-sections.md) — `[name]` support alongside `[[name]]`. Once it lands, our `[[prompt]]` schema migrates to `[prompt]` (back-compat preserved).
- Next: tag 0.2.0, then start M2 — **VCS segment via `sit`** (not external `git`; sovereign-stack alignment, decided 2026-05-17). See [`roadmap.md`](roadmap.md) M2.

## Next

See [`roadmap.md`](roadmap.md).
