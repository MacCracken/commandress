# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-05-15 via `cyrius init`. No releases yet.

## Role

Structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Binary name: `cmdrs`. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius.

## Toolchain

- **Cyrius pin**: `5.11.54` (in `cyrius.cyml [package].cyrius`)

## Source

Initial scaffold only — `src/main.cyr` is a stub. No segment implementations yet.

| Module | Status |
|---|---|
| `src/main.cyr` | scaffold (entrypoint stub) |
| `src/config.cyr` | not started — CYML config loader |
| `src/segments/cwd.cyr` | not started — current working directory segment |
| `src/segments/exit.cyr` | not started — last-exit-code segment |
| `src/segments/time.cyr` | not started — wall-clock segment |
| `src/segments/git.cyr` | not started — git branch/state segment |
| `src/render.cyr` | not started — segment composition + ANSI emit |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: TBD (first build pending)

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

- Roadmap M1 (v0.2.0): config-loader stub + cwd segment + exit-code segment. See [`roadmap.md`](roadmap.md).

## Next

See [`roadmap.md`](roadmap.md).
