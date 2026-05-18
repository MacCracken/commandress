# Getting started with commandress

> **Status**: v0.5.0 — `cmdrs` is a working prompt. The first-party shell adapters (agnoshi M7 → v0.8.0; bash + zsh same milestone) aren't shipped yet, but the binary is usable today via a `precmd` hook. For zsh in particular, see [`zsh-testing.md`](zsh-testing.md).

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
                              ──read─→ ~/.commandress.cyml
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

## Config (planned for M1)

`~/.commandress.cyml`:

```cyml
[prompt]
order = ["cwd", "git", "exit"]
separator = " · "

[segments.cwd]
home_shorten = true
max_length = 40

[segments.git]
budget_ms = 80
show_dirty = true
show_ahead_behind = false

[segments.exit]
show_when_zero = false
color_nonzero = "red"
```

Missing config file → baked-in defaults. Invalid config field → log to stderr, render with defaults.

## Adding a segment (M1+)

1. Create `src/segments/your_segment.cyr` exporting `render_your_segment(ctx) → str`
2. Add a unit test in `tests/commandress.tcyr` — at least one happy path + one error path
3. Add a benchmark in `tests/commandress.bcyr` measuring render time
4. Register the segment in `src/render.cyr`'s dispatch table
5. Add it to the default order in `src/config.cyr`'s defaults
6. Bump `CHANGELOG.md` `[Unreleased] / Added`
7. If the segment design is non-trivial, file an ADR (see [`../adr/template.md`](../adr/template.md))

## Running standalone

Once segments land:

```sh
AGNOSHI_LAST_EXIT=0 PWD=/tmp ./build/cmdrs               # default config
AGNOSHI_LAST_EXIT=1 ./build/cmdrs --config /tmp/test.cyml # custom config
./build/cmdrs --debug                                     # per-segment timing
```

## Integrating with agnoshi (M7+)

```sh
# In your agnoshi rc file:
export AGNOSHI_PROMPT_CMD=cmdrs
```

agnoshi invokes `cmdrs` once per prompt redraw, captures stdout, paints it.

## Testing today in zsh (pre-M7)

The first-party zsh adapter is M7 (v0.8.0). Until then, a four-line `precmd` hook in `~/.zshrc` is enough to drive `cmdrs` from current zsh — see [`zsh-testing.md`](zsh-testing.md) for the recipe + caveats.

## Next

See [`../development/roadmap.md`](../development/roadmap.md) for the milestone plan and [`../adr/template.md`](../adr/template.md) for writing decision records.
