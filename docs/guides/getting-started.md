# Getting started with commandress

> **Status**: v0.8.0 — `cmdrs` is a working prompt with first-party shell adapters for zsh, bash, and agnoshi shipped under [`adapters/`](../../adapters/). See [`zsh-setup.md`](zsh-setup.md) / [`bash-setup.md`](bash-setup.md) for the one-line `source` integration.

## Build

```sh
cyrius deps                                    # resolve stdlib deps
cyrius build src/main.cyr build/cmdrs          # compile (binary: cmdrs)
cyrius test                                    # run [build].test + tests/*.tcyr
cyrius bench tests/commandress.bcyr            # benchmarks
```

The output binary is `build/cmdrs`.

## Conceptual model

`cmdrs` is **stateless**: it takes shell context as input (env vars + CLI flags), reads its config, and prints one rendered prompt to stdout. The shell calls it once per prompt redraw.

```
shell ──exec("cmdrs")──> cmdrs ──read─→ env vars ($AGNOSHI_LAST_EXIT, $PWD, ...)
                              ──read─→ ~/.commandress
                              ──compose segments─→
                              ──ANSI emit─→ stdout
shell ──capture stdout─→ paint as prompt
```

Each **segment** is a pure function of the input context. Examples:

- `cwd` — reads `$PWD`, renders `~/foo/bar` (home-shortened, truncated)
- `exit` — reads last-exit env var, renders empty if 0 or a colored marker otherwise
- `git` — probes git state, renders `branch ✗` (dirty) / `branch ✓` (clean)
- `time` — reads wall clock, renders `HH:MM:SS`

Segments are independent — no shared mutable state, no ordering dependencies. Order in the rendered prompt comes from config.

## Layout

- `src/main.cyr` — entry point. Top-level `var r = main(); syscall(SYS_EXIT, r);`.
- `src/test.cyr` — top-level test entry referenced by `cyrius.cyml [build].test`.
- `tests/commandress.tcyr` — primary test suite (`cyrius test` auto-discovers).
- `tests/commandress.bcyr` — benchmarks (`cyrius bench`).
- `tests/commandress.fcyr` — fuzz harness (`cyrius fuzz`).

## Config

`~/.commandress` (no extension — [ADR 0006](../adr/0006-config-path-rename.md)). CYML;
the header zone is TOML. Both `[[section]]` and `[section]` are accepted; `[[section]]`
is the canonical spelling every shipped theme uses.

```cyml
[[prompt]]
segments       = ["cwd", "vcs", "exit"]     # default order
right_segments = ["time"]                   # optional; rendered by `cmdrs --side=right`
separator      = " "
trailer        = " $ "

[[segments.cwd]]
home_shorten = true
max_length   = 40
fg           = "cyan"

[[segments.vcs]]
show_dirty   = true
dirty_marker = "*"
budget_ms    = 5                            # `sit status` watchdog, whole ms, 1 to 1000

[[segments.exit]]
hide_zero = true
fg        = "red"
```

A color can be a name, a 256-colour index, or hex, in `fg`, `bg` or a `[[palette]]` slot:

```cyml
[[segments.cwd]]
fg = "cyan"          # one of the 16 named colors; your terminal's theme picks the shade
bg = "24"            # a 256-colour index, 0 to 255
style = "bold"

[[segments.vcs]]
fg = "#8be9fd"       # exact, in a truecolor terminal
```

Anything else renders with no colour and no warning. `cmdrs` emits the form you wrote, so a
hex value on a terminal without truecolor shows however that terminal chooses.

To keep several colour schemes in one file, see
[switching between palettes](../themes/README.md#switching-between-palettes).

Missing config file → baked-in defaults. Unknown field → warning on stderr, render
continues with defaults for that field. Every knob is listed in
[`../examples/commandress.cyml.example`](../examples/commandress.cyml.example); drop-in
palettes live in [`../themes/`](../themes/).
A config over 64 KB warns and uses the defaults, rather than being cut part-way.

### Writing values

The header zone is read as TOML by [bayan](https://github.com/MacCracken/bayan)
([ADR 0009](../adr/0009-config-parsing-via-bayan.md)).

| Form | Example | Notes |
|---|---|---|
| Basic string | `trailer = "\n$ "` | Decodes `\n`, `\t`, `\"`, `\\` and `\u` code points. An unknown escape stays as written. |
| Literal string | `separator = ' \ '` | Exactly the bytes between the quotes. Use this when you want a backslash. |
| Bool or number | `hide_zero = false` | Unquoted. |
| Array | `segments = ["cwd", "exit"]` | May span lines and hold comments. |

Comments can follow any value. If a key is repeated, the last value wins. Quote every string:
an unquoted one ends at `#`, `,` or `}`.

A newline in `trailer` gives a two-line prompt:

```cyml
[[prompt]]
segments = ["cwd", "vcs"]
trailer  = "\n$ "
```

`separator`, `trailer` and the glyphs are printed exactly as written, so an escape such as
`\u001b` reaches your terminal. That is intended for a file you wrote, but read any config you
paste in from elsewhere.

## Adding a segment

1. Create `src/segments/your_segment.cyr` exporting a pure `your_segment_render(...) → cstring` (0 for "render nothing")
2. Add a unit test in `tests/commandress.tcyr` — at least one happy path + one error path
3. Add a benchmark in `tests/commandress.bcyr` measuring render time
4. Register the segment in `src/render.cyr`'s dispatch table (`_seg_fn_for`, plus `_sgr_for` / `_bg_for`)
5. If it should be on by default, add it to `src/config.cyr`'s defaults
6. Bump `CHANGELOG.md` `[Unreleased] / Added`
7. If the segment design is non-trivial, file an ADR (see [`../adr/template.md`](../adr/template.md))

Segment output is sanitized at one chokepoint in `src/render.cyr`, so a new segment gets
control-byte filtering for free — but read the [2026-08-26 audit](../audit/2026-08-26-audit.md)
first if your segment copies bytes from outside commandress.

## Running standalone

```sh
AGNOSHI_LAST_EXIT=0 ./build/cmdrs        # default config
AGNOSHI_LAST_EXIT=42 ./build/cmdrs       # non-zero exit rendered
./build/cmdrs --side=right               # right prompt (config `right_segments`)
./build/cmdrs --version                  # stdout
./build/cmdrs --help                     # generated flag table, stderr
HOME=/tmp/altconf ./build/cmdrs          # point at a different config
```

There is no `--config` or `--debug` flag; earlier drafts of this guide listed both and
neither was ever implemented. The config path is derived from `$HOME`, so set `HOME` to
test an alternative. The full CLI surface is `--side`, `--help`, `--version`
([ADR 0008](../adr/0008-cli-parsing-via-cmdit.md)).

## Integrating with agnoshi

```sh
# In your agnoshi rc file:
export AGNOSHI_PROMPT_CMD=cmdrs
```

agnoshi invokes `cmdrs` once per prompt redraw, captures stdout, paints it.

## Using `cmdrs` in zsh / bash

The first-party shell adapters live in [`adapters/`](../../adapters/). One `source` line in your shell rc wires `cmdrs` into the prompt loop:

```sh
# zsh (~/.zshrc)
source /path/to/commandress/adapters/zsh.sh

# bash (~/.bashrc)
source /path/to/commandress/adapters/bash.sh
```

Detailed setup + customization in [`zsh-setup.md`](zsh-setup.md) and [`bash-setup.md`](bash-setup.md). The agnoshi adapter ([`adapters/agnoshi.sh`](../../adapters/agnoshi.sh)) is the one-env-var contract (`AGNOSHI_PROMPT_CMD=cmdrs`) the AGNOS-native shell consumes.

## Next

See [`../development/roadmap.md`](../development/roadmap.md) for the milestone plan and [`../adr/template.md`](../adr/template.md) for writing decision records.
