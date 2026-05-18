# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-05-15 via `cyrius init`. No releases yet.

## Role

Structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Binary name: `cmdrs`. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius.

## Toolchain

- **Cyrius pin**: `5.11.59` (in `cyrius.cyml [package].cyrius`)

## Source

| Module | Status |
|---|---|
| `src/main.cyr` | M1 — builds Context (HOME, AGNOSHI_LAST_EXIT), calls `render_prompt` |
| `src/render.cyr` | M1 — hard-coded segment list (cwd, exit), space separator, `$ ` trailer |
| `src/segments/cwd.cyr` | M1 — `getcwd` + optional `$HOME` → `~` shortening (strict-prefix only) |
| `src/segments/exit.cyr` | M1 — empty on 0, `[N]` otherwise |
| `src/config.cyr` | not started — CYML loader (M1 follow-up; defaults baked in until then) |
| `src/segments/time.cyr` | not started — wall-clock segment (M3) |
| `src/segments/git.cyr` | not started — git branch/state segment (M2) |
| `src/segments/hostname.cyr` | not started — hostname segment (M3) |
| `src/segments/user.cyr` | not started — user segment (M3) |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: **73,544 B** (M1 cwd + exit segments + render pipeline, Cyrius 5.11.59, x86_64)

## Benchmarks

Captured 2026-05-17 on the dev host (Linux 7.0.5-arch1-1, x86_64):

| Operation | Avg | Min | Max |
|---|---|---|---|
| `cwd_render` | 664 ns | 609 ns | 892 ns |
| `exit_render(nonzero)` | 38 ns | 35 ns | 52 ns |
| `render_prompt (cwd+exit)` | 2 µs | 1 µs | 2 µs |

Budget: 5 ms cold start total ([`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)). Current in-process render at 2 µs is **0.04 % of budget**; headroom is for git, language-env, and the rest of M2–M4.

## Tests

- `tests/commandress.tcyr` — primary suite (scaffold stub)
- `tests/commandress.bcyr` — benchmark stub
- `tests/commandress.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`

External: none (and none planned for v1.0).

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

- Roadmap M1 (v0.2.0): **cwd + exit segments + render pipeline shipped**. Remaining for v0.2.0: `src/config.cyr` (CYML loader) so segment order + per-segment options become user-configurable. See [`roadmap.md`](roadmap.md).

## Next

See [`roadmap.md`](roadmap.md).
