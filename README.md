# commandress

> A fast, structured shell prompt for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Sovereign-stack equivalent of [starship](https://starship.rs/), in [Cyrius](https://github.com/MacCracken/cyrius).

**Binary**: `cmdrs` (short for *commandress*). **Status**: pre-release scaffold (v0.1.0, 2026-05-15). **License**: GPL-3.0-only.

## What it is

A small, self-contained binary that takes shell context as input (`$CWD`, last exit code, current git state, language version, etc.) and prints a configurable, segment-based prompt line. The shell invokes it once per prompt redraw.

- **Zero deps** beyond the Cyrius stdlib — single static binary, fast cold start
- **Segment model** — independent, parallelizable producers (cwd, git, time, exit, language env) each rendering into a slot
- **Config-driven** — appearance, segment order, and segment toggles live in a CYML file (`~/.commandress.cyml`)
- **agnoshi-first** — the shell that ships with AGNOS is the primary integration target; other shells follow on demand

## What it is not

- Not a shell — `cmdrs` only renders the prompt; agnoshi (or your shell) still owns history, completion, and execution
- Not a replacement for `PS1` mode-switching — config is declarative, not procedural
- Not a port of starship — convergent design, separate implementation, Cyrius-native conventions

## Build

```sh
cyrius deps                                    # resolve stdlib deps
cyrius build src/main.cyr build/cmdrs          # compile (binary named cmdrs)
cyrius test                                    # run [build].test + tests/*.tcyr
```

## Quick use (once Phase M1 lands)

```sh
# In agnoshi, set the prompt hook
export AGNOSHI_PROMPT_CMD=cmdrs

# Or invoke directly for one prompt:
cmdrs                                          # prints one rendered prompt to stdout
cmdrs --config ~/.commandress.cyml             # custom config file
cmdrs --debug                                  # show timing per segment
```

## Project layout

```
commandress/
├── VERSION
├── cyrius.cyml
├── CLAUDE.md, CHANGELOG.md, README.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, LICENSE
├── src/
│   └── main.cyr                              # binary entrypoint
├── tests/
│   ├── commandress.tcyr                      # unit tests
│   ├── commandress.bcyr                      # benchmark stub
│   └── commandress.fcyr                      # fuzz stub
└── docs/
    ├── adr/                                  # decision records
    ├── architecture/                         # non-obvious invariants
    ├── guides/                               # task-oriented how-tos
    ├── examples/                             # runnable examples
    └── development/
        ├── roadmap.md                        # milestones through v1.0
        └── state.md                          # live state snapshot
```

## Documentation

- [`CLAUDE.md`](CLAUDE.md) — agent instructions for this repo
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — milestone plan
- [`docs/development/state.md`](docs/development/state.md) — current version, sizes, in-flight work
- [`docs/guides/getting-started.md`](docs/guides/getting-started.md) — build + first run
- [`docs/adr/`](docs/adr/) — architectural decisions
- [`docs/architecture/`](docs/architecture/) — non-obvious invariants

## Place in the AGNOS ecosystem

`commandress` sits beside [`agnoshi`](https://github.com/MacCracken/agnoshi) (the shell) — it's a prompt renderer, not a shell. The split mirrors starship-vs-bash: one tool owns the input loop and execution, the other owns the visual prompt. Decoupling means upgrading the prompt's design surface doesn't require a shell release, and the prompt can serve other shells without taking on shell complexity.

Standards: [first-party-standards.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)

## License

[GPL-3.0-only](LICENSE)
