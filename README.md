# commandress

> A fast, structured shell prompt for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Sovereign-stack equivalent of [starship](https://starship.rs/), in [Cyrius](https://github.com/MacCracken/cyrius).

**Binary**: `cmdrs` (short for *commandress*). **Status**: v0.3.0 — cwd / exit / vcs segments shipped; M3 (time, hostname, user) next. **License**: GPL-3.0-only.

## What it is

A small, self-contained binary that takes shell context as input (`$CWD`, last exit code, current VCS state, etc.) and prints a configurable, segment-based prompt line. The shell invokes it once per prompt redraw.

- **Zero deps** beyond the Cyrius stdlib — single static binary, fast cold start
- **Segment model** — independent producers (cwd, vcs, exit; time/hostname/user/lang-env land in M3+) each rendering into a slot
- **Config-driven** — appearance, segment order, and per-segment toggles live in a CYML file (`~/.commandress` — no extension; format is implicit, see [ADR 0006](docs/adr/0006-config-path-rename.md))
- **Sovereign stack** — VCS state comes from [`sit`](https://github.com/MacCracken/sit), not external `git` ([ADR 0004](docs/adr/0004-vcs-probe-via-sit.md))
- **agnoshi-first** — the shell that ships with AGNOS is the primary integration target; bash/zsh adapters follow at M7

## What it is not

- Not a shell — `cmdrs` only renders the prompt; agnoshi (or your shell) still owns history, completion, and execution
- Not a replacement for `PS1` mode-switching — config is declarative, not procedural
- Not a port of starship — convergent design, separate implementation, Cyrius-native conventions
- Not a polyglot VCS surface — the vcs segment shells out to `sit` only; there's no external-`git` fallback (per [ADR 0004](docs/adr/0004-vcs-probe-via-sit.md))

## Build

```sh
cyrius deps                                    # resolve stdlib deps (no-op if already synced)
cyrius build src/main.cyr build/cmdrs          # compile (binary named cmdrs)
cyrius test                                    # 47 assertions across cwd / exit / vcs / config
cyrius bench tests/commandress.bcyr            # per-segment + full-prompt timings
```

## Available segments (v0.3.0)

| Name | Source | Renders | Per-segment options |
|---|---|---|---|
| `cwd` | `getcwd(2)` | Current directory, optionally `~`-shortened | `home_shorten: bool` |
| `exit` | `$AGNOSHI_LAST_EXIT` | `[N]` on non-zero; empty on success | `hide_zero: bool` |
| `vcs` | `sit status` | `<branch>` / `<branch>*` inside a `sit` repo | `show_dirty: bool`, `dirty_marker: string` |

Default segment order is `["cwd", "vcs", "exit"]` — `vcs` became default-on in v0.7.0 once the 1 s TTL probe cache (see `src/cache.cyr`) made it cheap enough (~66 µs hot avg vs ~1.8 ms cold). Outside a `sit` repo the `vcs` segment renders empty, so the prompt stays clean for non-VCS directories.

## Quick use

```sh
# Default config (no file present) prints cwd + exit:
$ cmdrs
~/repos/commandress $

$ AGNOSHI_LAST_EXIT=42 cmdrs
~/repos/commandress [42] $
```

Configure via `~/.commandress` — full annotated example at [`docs/examples/commandress.cyml.example`](docs/examples/commandress.cyml.example). Minimum to enable the `vcs` segment:

```cyml
[[prompt]]
segments = ["cwd", "vcs", "exit"]
```

Once agnoshi's prompt hook lands (M7), wiring is one env var:

```sh
export AGNOSHI_PROMPT_CMD=cmdrs
```

## Project layout

```
commandress/
├── VERSION                                    # canonical version — cyrius.cyml reads this
├── cyrius.cyml                                # package + build manifest
├── CHANGELOG.md, CLAUDE.md, README.md, LICENSE
├── src/
│   ├── main.cyr                               # entrypoint — wires config → context → render
│   ├── config.cyr                             # CYML config loader, schema, defaults
│   ├── context.cyr                            # per-invocation { home, last_exit } struct
│   ├── render.cyr                             # table-driven segment registry + dispatch
│   └── segments/
│       ├── cwd.cyr                            # current working directory
│       ├── exit.cyr                           # last-command exit code
│       └── vcs.cyr                            # sit-backed branch + dirty indicator
├── tests/
│   ├── commandress.tcyr                       # unit tests (47 assertions)
│   ├── commandress.bcyr                       # benchmark suite
│   └── commandress.fcyr                       # fuzz stub
└── docs/
    ├── adr/                                   # decision records (0001–0004)
    ├── architecture/                          # non-obvious invariants
    ├── guides/                                # task-oriented how-tos
    ├── examples/                              # runnable examples + annotated config
    └── development/
        ├── roadmap.md                         # milestones M3 → M9
        └── state.md                           # live state snapshot
```

## Documentation

- [`CHANGELOG.md`](CHANGELOG.md) — source of truth for what each release shipped
- [`docs/examples/prompt-tour.md`](docs/examples/prompt-tour.md) — gallery of `cmdrs` output for different configs + states; shell-integration recipes
- [`docs/examples/commandress.cyml.example`](docs/examples/commandress.cyml.example) — annotated config showing every knob
- [`docs/guides/getting-started.md`](docs/guides/getting-started.md) — build + first run
- [`docs/development/state.md`](docs/development/state.md) — current version, sizes, benchmarks, in-flight work
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — milestones through v1.0
- [`docs/adr/`](docs/adr/) — architectural decisions (rendering model, config format, VCS-via-sit, etc.)
- [`docs/architecture/`](docs/architecture/) — non-obvious invariants (prompt render budget, etc.)
- [`docs/doc-health.md`](docs/doc-health.md) — doc-currency ledger: which docs are fresh / stale / evergreen
- [`CLAUDE.md`](CLAUDE.md) — agent instructions for this repo

## Place in the AGNOS ecosystem

`commandress` sits beside [`agnoshi`](https://github.com/MacCracken/agnoshi) (the shell) — it's a prompt renderer, not a shell. The split mirrors starship-vs-bash: one tool owns the input loop and execution, the other owns the visual prompt. Decoupling means upgrading the prompt's design surface doesn't require a shell release, and the prompt can serve other shells without taking on shell complexity.

VCS state comes from [`sit`](https://github.com/MacCracken/sit) — the AGNOS-native VCS, on the same Cyrius toolchain cadence. See [ADR 0004](docs/adr/0004-vcs-probe-via-sit.md) for the trade.

Standards: [first-party-standards.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)

## License

[GPL-3.0-only](LICENSE)
