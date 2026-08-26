# 0008 — CLI parsing via the cmdit distlib, and the first non-stdlib dependency

**Status**: Accepted
**Date**: 2026-08-26

## Context

commandress's entire command-line surface is one flag: `--side=left|right`, which
selects whether `render_prompt` paints `segments` or `right_segments`. Through 1.1.4
that was hand-rolled in `src/main.cyr`:

```cyr
fn _parse_side(): i64 {
    var side_flag = "--side=right";
    ...
    if (memeq(a, side_flag, side_flag_len) == 1) { return 1; }
    ...
    return 0;                       # everything else, including --side=bogus
}
```

A single-pass walk over argv, byte-comparing each entry against the one string
`--side=right`. Three things follow from that shape:

- **The choice set was never validated.** `--side=bogus`, `--side=rihgt`, and
  `--sid=right` all silently rendered the left prompt. A typo looked like a
  working prompt.
- **`--help` and `--version` did not exist.** [ADR 0007](0007-schema-freeze.md)
  explicitly *reserved* both — "**Reserved**: `--side=<other>`, `--config=<path>`,
  `--version`, `--help` for future extension" — and nothing ever delivered them.
  `cmdrs --version` rendered a prompt.
- **It was untestable.** `_parse_side` read the real process argv from inside
  `src/main.cyr`, a file no test can `include` because it ends in a bare
  `_agnos_entry();` top-level call. The suite had zero coverage of the CLI.

Meanwhile [cmdit](https://github.com/MacCracken/cmdit) exists precisely for this:
an ecosystem review found ~40 AGNOS binaries hand-rolling flag/help/version parsing
on the bare `args` primitive. cmdit is the stdlib `flags` parser productized as a
standalone distlib and extended, with its API frozen at 1.0.0. kii is the canonical
precedent — it dropped stdlib `flags` for `[deps.cmdit]` at its v1.1.0.

The tension is that commandress's own rules said not to. CLAUDE.md carried
"**Static binary** — zero non-stdlib deps" and "Do not add external runtime deps",
and `docs/development/state.md` recorded "External: none (and none planned for
v1.0)". Adopting cmdit means changing a stated project constraint, which is why
this is an ADR and not a patch note.

## Decision

**Adopt cmdit 1.2.4 as commandress's CLI parser**, declared as
`[deps.cmdit] modules = ["dist/cmdit.cyr"]` and pinned by git tag. `--side` becomes
a `cmdit_enum` over `left|right`; `--help`/`--version` come registered from
`cmdit_new` and are now delivered as ADR 0007 reserved them.

**The "zero non-stdlib deps" rule is narrowed, not deleted**, to the distinction it
was always really making:

- **First-party AGNOS source dependencies are permitted.** They are vendored into
  `lib/` by `cyrius deps`, compiled into the binary, and pinned by tag in
  `cyrius.lock`. The binary stays static and self-contained; nothing new is
  required at runtime.
- **Runtime dependencies remain forbidden.** `cmdrs` still links nothing dynamic,
  requires no daemon, and reads no new input channel. Config + context-from-env
  remains the only input surface — cmdit parses the same argv that was always
  parsed.

Two behavioural decisions inside that adoption:

1. **A parse error degrades to the left prompt; it does not exit non-zero.**
   `cmdit_print_error` writes the diagnosis to stderr, and rendering continues.
2. **The version literal lives in `src/cli.cyr`, guarded by a test.** The CLI
   policy moved out of `main.cyr` into its own module so it can be tested through
   cmdit's pure `cmdit_parse_argv` core with synthetic argv.

## Consequences

- **Positive** — `--side` is validated against its choice set, so `--side=bogus` is
  now *named on stderr* instead of silently rendering the wrong side. `--help` and
  `--version` exist, generated from the flag table, so they cannot drift from the
  parser the way a hand-written help wall does. getopt-long forms (`--side right`,
  `--`) come free. The CLI gained 16 assertions across 10 tests where it had none,
  because `src/cli.cyr` is includable and cmdit's parse core is pure. One less
  hand-rolled parser in the ecosystem's ~40.

- **Negative** — **the parse got ~212× slower in isolation**: the hand-rolled walk
  benched **56 ns**, cmdit **11.914 µs**, of which ~98 % is `cmdit_new` zeroing a
  64-entry × 112-byte flag table for a program that registers one flag. The binary
  grew **168,264 B → 211,768 B (+43,504 B, +25.9 %)**. commandress now owns a
  dependency-update obligation it did not have: a `cyrius.lock`, a tag to advance,
  and cmdit's security releases to track (1.2.4 is itself a security release).

  Both costs were measured before accepting them. The parse cost is **not** inside
  `render_prompt` — that takes `side` as a parameter — so the 5 ms cold-start gate
  is untouched and `render_prompt` still benches **10.769 µs**. Against the ~940 µs
  the binary actually spends per invocation (process exec plus the vcs probe
  dominate), an interleaved A/B of the 1.1.4 and 1.1.5 binaries measured deltas of
  **−15 µs, +1 µs, +11 µs** — straddling zero, i.e. below the noise floor. The
  regression is real on the microbenchmark and undetectable in the shell.

- **Neutral** — `args` and `bench` are now *declared* in `[deps].stdlib`. They were
  always compiled in via includes; cmdit's `dist/cmdit.deps` sidecar requires them
  in scope, so the declaration caught up with the build. `cyrius deps` now writes a
  `cyrius.lock` (119 entries, 1 commit-pinned), which is committed.

## Alternatives considered

- **Keep the hand-rolled walk.** Cheapest by far and the 56 ns is honest. Rejected
  because it leaves `--help`/`--version` permanently unbuilt (ADR 0007 reserved
  them and something has to deliver them), keeps the CLI untestable, and keeps
  `--side=bogus` silently wrong — the exact failure mode CLAUDE.md's "if the prompt
  is wrong, the bugs own you" warns about.

- **Hand-roll only the additions** — extend the walk to recognise `--help`,
  `--version`, and validate the `--side` value. Rejected: that is re-implementing
  cmdit's job by hand, in the repo, forever, and it is precisely the drift cmdit
  was extracted to stop. The ~40-binary survey exists because this option is the
  one everyone picks.

- **Use the stdlib `flags` parser** (`lib/flags.cyr`) instead of the distlib.
  Rejected for the reason cmdit was extracted: `flags` lives in the toolchain, so
  it cannot grow `enum`/`repeat`/verb features without a Cyrius release, and cmdit
  is a byte-compatible superset of it. kii made the same call at its v1.1.0.

- **Adopt cmdit but keep a fast path** — hand-check argv for the common bare case
  and only construct a cmdit handle when a flag is actually present. Rejected as
  premature: it reintroduces the hand-rolled parser this ADR removes, to buy back
  ~11.9 µs that the A/B above could not detect end-to-end. Revisit only if
  cold-start measurement ever shows it.

- **Exit non-zero on a parse error** (the conventional `CMDIT_EXIT_USAGE` path that
  kii and stiva take). Rejected *for this binary specifically*: `cmdrs` is invoked
  as `PROMPT="$(cmdrs)"` once per redraw, so exiting 2 with empty stdout blanks the
  user's prompt over a typo. Degrading preserves 1.1.4's forgiving behaviour, and
  ADR 0007 declines to promise behaviour on unknown flags, so the choice is ours.
  stderr still carries the diagnosis, and `$( )` does not capture it.
