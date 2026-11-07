# commandress

> A fast, structured shell prompt for [agnoshi](https://github.com/MacCracken/agnoshi), zsh, and bash. Sovereign-stack equivalent of [starship](https://starship.rs/), in [Cyrius](https://github.com/MacCracken/cyrius).

**Binary**: `cmdrs` (short for *commandress*). **Status**: **v1.5.3** — public API frozen at v1.0 ([ADR 0007](docs/adr/0007-schema-freeze.md)); the 1.1.x line is toolchain refreshes, the [cmdit](https://github.com/MacCracken/cmdit) CLI adoption, and a security audit, and the 1.2.x line ends in [another](docs/audit/2026-11-06-audit.md). **License**: GPL-3.0-only.

## What it is

A small, self-contained binary that takes shell context as input (`$CWD`, last exit code, current VCS state, etc.) and prints a configurable, segment-based prompt line. The shell invokes it once per prompt redraw.

- **Single static binary, no runtime deps** — the Cyrius stdlib plus three first-party AGNOS source deps ([cmdit](https://github.com/MacCracken/cmdit) for CLI parsing, [ADR 0008](docs/adr/0008-cli-parsing-via-cmdit.md); [darshini](https://github.com/MacCracken/darshini)'s zone code for local time, [ADR 0016](docs/adr/0016-local-time-through-darshini.md); [bayan](https://github.com/MacCracken/bayan) for config parsing, [ADR 0009](docs/adr/0009-config-parsing-via-bayan.md)), compiled in. Fast cold start (default `cwd + vcs + exit` prompt renders in ~11 µs — 0.2 % of the 5 ms budget)
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
cyrius test                                    # 308 assertions across 146 tests
cyrius bench tests/commandress.bcyr            # per-segment + full-prompt timings
```

## Available segments

| Name | Source | Renders | Per-segment options |
|---|---|---|---|
| `cwd` | `getcwd(2)` | Current directory, optionally `~`-shortened, optionally truncated | `home_shorten`, `max_length`, `fg`/`bg`/`style` |
| `exit` | `$AGNOSHI_LAST_EXIT` | `[N]` on non-zero; empty on success | `hide_zero`, `max_length`, `fg`/`bg`/`style` |
| `vcs` | `sit status` (cached, 1 s TTL) | `<branch>` / `<branch>*` inside a `sit` repo | `show_dirty`, `dirty_marker`, `budget_ms`, `max_length`, `fg`/`bg`/`style` |
| `time` | `CLOCK_REALTIME`, in the zone from `TZ` or `/etc/localtime` | strftime-subset (`%H %M %S %Y %y %m %d %%`), local time | `format`, `utc`, `max_length`, `fg`/`bg`/`style` |
| `hostname` | `uname(2)` nodename | Host short name | `max_length`, `fg`/`bg`/`style` |
| `user` | `getuid()` + `/etc/passwd` | Current user; falls back to `$USER` | `max_length`, `fg`/`bg`/`style` |
| `cyrius_env` | `cyrius.cyml` ancestor + `VERSION` | Cyrius project version | `max_length`, `fg`/`bg`/`style` |
| `python_env` | `$VIRTUAL_ENV` / `.python-version` | venv basename or pinned version | `max_length`, `fg`/`bg`/`style`, `shellout`, `budget_ms` |
| `node_env` | `.nvmrc` ancestor walk, else the nearest `package.json`'s `engines.node` | Pinned Node version, channel or range | `max_length`, `fg`/`bg`/`style`, `shellout`, `budget_ms` |
| `rustup_env` | `rust-toolchain` / `rust-toolchain.toml` ancestor walk | Pinned Rust toolchain | `max_length`, `fg`/`bg`/`style`, `shellout`, `budget_ms` |

Default segment order is `["cwd", "vcs", "exit"]` — `vcs` became default-on in v0.7.0 once the 1 s TTL probe cache (`src/cache.cyr`) made it cheap enough (~7.6 µs hot avg vs ~1.8 ms cold). Outside a `sit` repo the `vcs` segment renders empty, so the prompt stays clean for non-VCS directories.

Colour, powerline-style separators, named palettes, and right-prompt all ship — see [`docs/examples/commandress.cyml.example`](docs/examples/commandress.cyml.example) and the curated theme files in [`docs/themes/`](docs/themes/).

## Quick use

```sh
# Default config (no file present) prints cwd + vcs + exit:
$ cmdrs
~/repos/commandress $

$ AGNOSHI_LAST_EXIT=42 cmdrs
~/repos/commandress [42] $

# Right prompt (zsh RPROMPT); renders `right_segments`, no trailer:
$ cmdrs --side=right

$ cmdrs --version
cmdrs 1.5.3

$ cmdrs --help          # generated from the flag table; prints to stderr
```

Context is taken from the environment, not from flags — `HOME` for config lookup and
`~` shortening, `AGNOSHI_LAST_EXIT` for the `exit` segment. An unrecognised flag is
reported on stderr and still renders the left prompt, so a typo never blanks the
prompt in `PROMPT="$(cmdrs)"` ([ADR 0008](docs/adr/0008-cli-parsing-via-cmdit.md)).

Configure via `~/.commandress` — full annotated example at [`docs/examples/commandress.cyml.example`](docs/examples/commandress.cyml.example). Drop in a curated theme:

```sh
cp docs/themes/commandress.cyml ~/.commandress       # first-party royal palette
cp docs/themes/nord.cyml        ~/.commandress       # nord
cp docs/themes/dracula.cyml     ~/.commandress       # dracula
cp docs/themes/gruvbox.cyml     ~/.commandress       # gruvbox
cp docs/themes/powerline.cyml   ~/.commandress       # solid blocks; needs a nerd-patched font
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
├── cyrius.lock                                # dep pins, committed (see architecture/003)
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
│   ├── probe.cyr                              # opt-in version probes, run outside the repo
│   ├── cache.cyr                              # per-segment per-cwd probe cache
│   ├── cli.cyr                                # CLI surface (cmdit flag table, degrade policy)
│   ├── pathlookup.cyr, fslookup.cyr           # shared lookup helpers
│   ├── color.cyr                              # ANSI SGR + sanitisation
│   └── segments/
│       ├── cwd.cyr, exit.cyr, vcs.cyr
│       ├── time.cyr, hostname.cyr, user.cyr
│       └── cyrius_env.cyr, python_env.cyr, node_env.cyr, rustup_env.cyr
├── tests/
│   ├── commandress.tcyr                       # test suite
│   ├── commandress.bcyr                       # benchmark suite
│   └── commandress.fcyr                       # fuzz stub
├── scripts/                                   # CI gates: lock-check, smoke, adapter-check, bench-gate
└── docs/
    ├── adr/                                   # decision records (0001–0008)
    ├── architecture/                          # non-obvious invariants
    ├── audit/                                 # security audits (2026-05-18, 2026-08-26)
    ├── benchmarks.md, benchmarks/             # budgets + historical timings
    ├── guides/                                # task-oriented how-tos
    ├── themes/                                # curated drop-in palettes
    ├── examples/                              # runnable examples + annotated config
    └── development/
        ├── roadmap.md                         # post-v1 sequencing
        └── state.md                           # live state snapshot
```

## Documentation

- [`CHANGELOG.md`](CHANGELOG.md) — source of truth for what each release shipped
- [`docs/examples/prompt-tour.md`](docs/examples/prompt-tour.md) — gallery of `cmdrs` output for different configs + states; shell-integration recipes
- [`docs/examples/commandress.cyml.example`](docs/examples/commandress.cyml.example) — annotated config showing every knob
- [`docs/guides/getting-started.md`](docs/guides/getting-started.md) — build + first run
- [`docs/development/state.md`](docs/development/state.md) — current version, sizes, benchmarks, in-flight work
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — post-v1 sequencing, every item pinned to the line that defers it
- [`docs/adr/`](docs/adr/) — architectural decisions (rendering model, config format, VCS-via-sit, schema freeze, cmdit adoption, config parsing via bayan, build DCE)
- [`docs/architecture/`](docs/architecture/) — non-obvious invariants (prompt render budget, shellout watchdog, etc.)
- [`docs/audit/2026-08-26-audit.md`](docs/audit/2026-08-26-audit.md) — latest security audit (1.1.6 P-1 sweep); prior pass [2026-05-18](docs/audit/2026-05-18-audit.md)
- [`docs/benchmarks.md`](docs/benchmarks.md) — what we measure, the budgets, and the current numbers
- [`CLAUDE.md`](CLAUDE.md) — agent instructions for this repo

## Place in the AGNOS ecosystem

`commandress` sits beside [`agnoshi`](https://github.com/MacCracken/agnoshi) (the shell) — it's a prompt renderer, not a shell. The split mirrors starship-vs-bash: one tool owns the input loop and execution, the other owns the visual prompt. Decoupling means upgrading the prompt's design surface doesn't require a shell release, and the prompt can serve other shells without taking on shell complexity.

VCS state comes from [`sit`](https://github.com/MacCracken/sit) — the AGNOS-native VCS, on the same Cyrius toolchain cadence. See [ADR 0004](docs/adr/0004-vcs-probe-via-sit.md) for the trade. Use `sit` 1.13.1 or later: from that release it refuses a `.sit`, `.git` or HEAD symlink out of the repository, so a hostile repo cannot show another repo's branch in your prompt.

Standards: [first-party-standards.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)

## License

[GPL-3.0-only](LICENSE)
