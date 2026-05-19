# commandress

> A fast, structured shell prompt for [agnoshi](https://github.com/MacCracken/agnoshi), zsh, and bash. Sovereign-stack equivalent of [starship](https://starship.rs/), in [Cyrius](https://github.com/MacCracken/cyrius).

**Binary**: `cmdrs` (short for *commandress*). **Status**: **v1.0.0** — public API frozen ([ADR 0007](docs/adr/0007-schema-freeze.md)). **License**: GPL-3.0-only.

## What it is

A small, self-contained binary that takes shell context as input (`$CWD`, last exit code, current VCS state, etc.) and prints a configurable, segment-based prompt line. The shell invokes it once per prompt redraw.

- **Zero deps** beyond the Cyrius stdlib — single static binary, fast cold start (default `cwd + vcs + exit` prompt renders in ~9 µs — 0.2 % of the 5 ms budget)
- **Segment model** — independent producers (cwd / vcs / exit / time / hostname / user / language envs), each a pure function of context
- **Config-driven** — appearance, segment order, and per-segment toggles live in a CYML file (`~/.commandress` — no extension; see [ADR 0006](docs/adr/0006-config-path-rename.md))
- **Sovereign stack** — VCS state comes from [`sit`](https://github.com/MacCracken/sit), not external `git` ([ADR 0004](docs/adr/0004-vcs-probe-via-sit.md))
- **Shell-agnostic** — first-party adapters for zsh and bash ship in [`adapters/`](adapters/); agnoshi adoption is contract-locked

## What it is not

- Not a shell — `cmdrs` only renders the prompt; agnoshi (or your shell) still owns history, completion, and execution
- Not a replacement for `PS1` mode-switching — config is declarative, not procedural
- Not a port of starship — convergent design, separate implementation, Cyrius-native conventions
- Not a polyglot VCS surface — the vcs segment shells out to `sit` only; there's no external-`git` fallback (per [ADR 0004](docs/adr/0004-vcs-probe-via-sit.md))

## Build

```sh
cyrius deps                                    # resolve stdlib deps (no-op if already synced)
cyrius build src/main.cyr build/cmdrs          # compile (binary named cmdrs)
cyrius test                                    # 279 assertions across 131 tests
cyrius bench tests/commandress.bcyr            # per-segment + full-prompt timings
```

## Available segments (v1.0.0)

| Name | Source | Renders | Per-segment options |
|---|---|---|---|
| `cwd` | `getcwd(2)` | Current directory, optionally `~`-shortened, optionally truncated | `home_shorten`, `max_length`, `fg`/`bg`/`style` |
| `exit` | `$AGNOSHI_LAST_EXIT` | `[N]` on non-zero; empty on success | `hide_zero`, `fg`/`bg`/`style` |
| `vcs` | `sit status` (cached, 1 s TTL) | `<branch>` / `<branch>*` inside a `sit` repo | `show_dirty`, `dirty_marker`, `fg`/`bg`/`style` |
| `time` | `CLOCK_REALTIME` | strftime-subset (`%H %M %S %Y %y %m %d %%`) | `format`, `fg`/`bg`/`style` |
| `hostname` | `uname(2)` nodename | Host short name | `fg`/`bg`/`style` |
| `user` | `getuid()` + `/etc/passwd` | Current user; falls back to `$USER` | `fg`/`bg`/`style` |
| `cyrius_env` | `cyrius.cyml` ancestor + `VERSION` | Cyrius project version | `fg`/`bg`/`style` |
| `python_env` | `$VIRTUAL_ENV` / `.python-version` | venv basename or pinned version | `fg`/`bg`/`style` |
| `node_env` | `.nvmrc` ancestor walk | Pinned Node version / channel | `fg`/`bg`/`style` |
| `rustup_env` | `rust-toolchain` ancestor walk | Pinned Rust toolchain | `fg`/`bg`/`style` |

Default segment order is `["cwd", "vcs", "exit"]` — `vcs` became default-on in v0.7.0 once the 1 s TTL probe cache (`src/cache.cyr`) made it cheap enough (~68 µs hot avg vs ~1.2 ms cold). Outside a `sit` repo the `vcs` segment renders empty, so the prompt stays clean for non-VCS directories.

Colour, powerline-style separators, named palettes, and right-prompt all ship — see [`docs/examples/commandress.cyml.example`](docs/examples/commandress.cyml.example) and the curated theme files in [`docs/themes/`](docs/themes/).

## Quick use

```sh
# Default config (no file present) prints cwd + vcs + exit:
$ cmdrs
~/repos/commandress $

$ AGNOSHI_LAST_EXIT=42 cmdrs
~/repos/commandress [42] $
```

Configure via `~/.commandress` — full annotated example at [`docs/examples/commandress.cyml.example`](docs/examples/commandress.cyml.example). Drop in a curated theme:

```sh
cp docs/themes/commandress.cyml ~/.commandress       # first-party royal palette
cp docs/themes/nord.cyml        ~/.commandress       # nord
cp docs/themes/dracula.cyml     ~/.commandress       # dracula
cp docs/themes/gruvbox.cyml     ~/.commandress       # gruvbox
cp docs/themes/monokai.cyml     ~/.commandress       # monokai
```

### Wire it into your shell

```sh
# zsh
source /path/to/commandress/adapters/zsh.sh         # see adapters/README.md

# bash
source /path/to/commandress/adapters/bash.sh

# agnoshi (contract; flips on when agnoshi reads $AGNOSHI_PROMPT_CMD)
source /path/to/commandress/adapters/agnoshi.sh
```

## Project layout

```
commandress/
├── VERSION                                    # canonical version — cyrius.cyml reads this
├── cyrius.cyml                                # package + build manifest
├── CHANGELOG.md, CLAUDE.md, README.md, LICENSE
├── adapters/                                  # first-party shell adapters
│   ├── zsh.sh, bash.sh, agnoshi.sh
│   └── README.md
├── src/
│   ├── main.cyr                               # entrypoint — wires config → context → render
│   ├── config.cyr                             # CYML config loader, schema, defaults
│   ├── context.cyr                            # per-invocation { home, last_exit } struct
│   ├── render.cyr                             # table-driven segment registry + dispatch
│   ├── shellout.cyr                           # per-call timeout watchdog
│   ├── cache.cyr                              # per-segment per-cwd probe cache
│   ├── pathlookup.cyr, fslookup.cyr           # shared lookup helpers
│   ├── color.cyr                              # ANSI SGR + sanitisation
│   └── segments/
│       ├── cwd.cyr, exit.cyr, vcs.cyr
│       ├── time.cyr, hostname.cyr, user.cyr
│       └── cyrius_env.cyr, python_env.cyr, node_env.cyr, rustup_env.cyr
├── tests/
│   ├── commandress.tcyr                       # 279 assertions across 131 tests
│   ├── commandress.bcyr                       # benchmark suite
│   └── commandress.fcyr                       # fuzz stub
├── scripts/                                   # bench-gate + bench-history
└── docs/
    ├── adr/                                   # decision records (0001–0007)
    ├── architecture/                          # non-obvious invariants
    ├── audit/                                 # security audit
    ├── benchmarks.md, benchmarks/             # finalised + historical timings
    ├── guides/                                # task-oriented how-tos
    ├── themes/                                # curated drop-in palettes
    ├── examples/                              # runnable examples + annotated config
    └── development/
        ├── roadmap.md                         # milestones (M9 closed)
        └── state.md                           # live state snapshot
```

## Documentation

- [`CHANGELOG.md`](CHANGELOG.md) — source of truth for what each release shipped
- [`docs/examples/prompt-tour.md`](docs/examples/prompt-tour.md) — gallery of `cmdrs` output for different configs + states; shell-integration recipes
- [`docs/examples/commandress.cyml.example`](docs/examples/commandress.cyml.example) — annotated config showing every knob
- [`docs/guides/getting-started.md`](docs/guides/getting-started.md) — build + first run
- [`docs/development/state.md`](docs/development/state.md) — current version, sizes, benchmarks, in-flight work
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — milestones through v1.0
- [`docs/adr/`](docs/adr/) — architectural decisions (rendering model, config format, VCS-via-sit, schema freeze, etc.)
- [`docs/architecture/`](docs/architecture/) — non-obvious invariants (prompt render budget, shellout watchdog, etc.)
- [`docs/audit/2026-05-18-audit.md`](docs/audit/2026-05-18-audit.md) — v1.0 security audit
- [`docs/benchmarks.md`](docs/benchmarks.md) — finalised v1.0 benchmark numbers
- [`CLAUDE.md`](CLAUDE.md) — agent instructions for this repo

## Place in the AGNOS ecosystem

`commandress` sits beside [`agnoshi`](https://github.com/MacCracken/agnoshi) (the shell) — it's a prompt renderer, not a shell. The split mirrors starship-vs-bash: one tool owns the input loop and execution, the other owns the visual prompt. Decoupling means upgrading the prompt's design surface doesn't require a shell release, and the prompt can serve other shells without taking on shell complexity.

VCS state comes from [`sit`](https://github.com/MacCracken/sit) — the AGNOS-native VCS, on the same Cyrius toolchain cadence. See [ADR 0004](docs/adr/0004-vcs-probe-via-sit.md) for the trade.

Standards: [first-party-standards.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)

## License

[GPL-3.0-only](LICENSE)
