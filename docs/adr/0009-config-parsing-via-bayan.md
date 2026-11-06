# 0009 — Config parsing via bayan's TOML and CYML sublibs

**Status**: Accepted
**Date**: 2026-11-06

## Context

`~/.commandress` was parsed by `lib/toml.cyr` and `lib/cyml.cyr`. Both were left over from before the stdlib moved them into bayan at cyrius 6.1.25. No toolchain snapshot has shipped either file since, so `cyrius lib sync` could not update them and no pin described them. They were last edited by hand for the 6.6.0 value form.

Meanwhile bayan fixed real defects in the same code. Each of these was reproduced against the shipped binary before anything changed:

| Config | What the forks did |
|---|---|
| `hide_zero = false # note` | Read the comment as part of the value, so the bool was silently ignored |
| `hide_zero = false` with a CRLF ending | Same, because of the stray CR |
| `trailer = '> '` | Printed the quotes |
| `fg = 'red'` | Lost the colour |
| `separator = "oops` (no closing quote) | Swallowed the next line, silently deleting that key |
| `segments = ["cwd` (no closing quote) | Swallowed the rest of the file |
| `segments = ["cwd", # not "vcs"` | Read the comment's `"vcs"` as an element (the hand-rolled splitter in `src/config.cyr`) |
| `trailer = """> """` | Dropped the whole value |

ADR 0008 admits first-party source deps when they remove hand-rolled code. This is that case, and here the hand-rolled code was parsing an input CLAUDE.md says not to trust without validation.

## Decision

**Parse the config with bayan's `toml` and `cyml` sublibs, pinned to tag 1.5.12, and delete both forks.**

- `[deps.bayan]` vendors `dist/bayan-toml.cyr` and `dist/bayan-cyml.cyr`. 1.5.12 is the bayan that cyrius 6.6.20 bundles, and later tags need cyrius 6.7.x.
- `src/config.cyr` calls the canonical `bayan_toml_*` and `bayan_cyml_*` names. The sublibs do not carry the old aliases.
- `bayan_toml_array_parse` replaces the hand-rolled `_parse_str_array`.
- `src/config.cyr` keeps three rules that a plain swap would have broken. Each has a test:
  - **The first populated section wins.** bayan emits empty tables, so an empty `[[segments.cwd]]` would otherwise shadow a populated one. See `_section_pairs`.
  - **Palette names may contain dots.** TOML reads `ui.primary = "red"` as a sub-table, but [ADR 0007](0007-schema-freeze.md) § 2 makes palette names arbitrary, so `_load_palette` keeps `palette:ui.primary` resolvable.
  - **Unknown fields warn.** A dotted key lands in a sub-table where the allow-lists never see it, so `_warn_nested_keys` reports it, with the same text as before. A `[[prompt.foo]]` header now warns too, where it used to be ignored silently.

### How this sits with the schema freeze

ADR 0007 freezes fields, their types and their semantics. It does not freeze how a string is spelled, and [ADR 0003](0003-config-format.md) defines the header zone as TOML. So decoding `"\n"` makes a `string` field mean what TOML says it means, and this ADR does not treat it as a change of field semantics needing the three-step deprecation path.

The promise in ADR 0007's context still counts, though: *a user's `~/.commandress` keeps working*. Every shipped theme and example renders byte-identically, and every frozen field reads as before. Configs relying on a few behaviours do change, and those are listed in the 1.1.9 CHANGELOG under **Breaking** with a migration for each.

## Consequences

- **Positive**
  - The eight defects above are gone, and the parser now has an owner and a pin. A toolchain bump moves it instead of leaving it behind.
  - The `lib/toml.cyr` compiler warnings are gone, so the build is warning-free.
  - `rust-toolchain.toml` (roadmap 1.3.0) needs no new dependency.
  - `\u` escapes and `\n` give users Unicode glyphs and two-line prompts without new schema.
  - Eight more unused `lib/` files could go at the same time, including `lib/agnosys.cyr`, a copy of a retired library.
- **Negative**
  - **Size**: +32,832 B on x86_64 (254,840 B → 287,672 B), of which +20,544 B is live code.
  - **Time**: `config_load` on the largest theme goes from 70.0 µs to 82.2 µs (+12 µs). That is about 0.25 % of the 5 ms budget.
  - **A quadratic worst case**: bayan looks up a dotted key's table linearly, so a config of thousands of unique dotted keys takes 464 ms where the forks took 3 ms. It takes about 8,000 such keys to get there, the 64 KB read cap bounds it near 0.6 s, and a real theme still takes 1.26 ms. This is accepted because only the user's own file can reach it: `cmdrs` never reads a repo-local config.
  - **A CRLF `---` divider is still not recognised**, so notes below it are read as config, as they were before. bayan fixed this at 1.8.0, which needs cyrius 6.7.x.
  - Escapes can now spell control bytes, such as `\u001b`. This adds no capability: raw ESC bytes in the file already reached stdout, and the [2026-08-26 audit](../audit/2026-08-26-audit.md) records `separator`, `trailer` and glyphs as deliberately unsanitized output of the user's own file. Segment output stays sanitized.
  - A `\u0000` escape cuts the value at that point, because config values become cstrings.
- **Neutral**
  - The tag now has to track the toolchain, as cmdit's does. See [architecture 003](../architecture/003-cyrius-lock-shape.md).
  - Audit finding [F-6](../audit/2026-05-18-audit.md) worried about recursion on deep nesting. bayan tracks depth with a counter rather than recursing, and 60,000 unclosed `[` parse cleanly. The 64 KB read cap stays as it is.

## Alternatives considered

- **Keep the forks.** Rejected: their defects are real, reachable from an ordinary config, and nothing could ever update them.
- **Patch the forks in place.** Rejected: that means owning a second TOML parser, which is what bayan exists to prevent.
- **`include "lib/bayan.cyr"` from the toolchain snapshot.** It needs no new dep, but it builds to 607,600 B against 287,672 B and starts about 11 µs slower. A config file needs only two of bayan's modules.
- **Keep the old raw-string behaviour.** Rejected: it would need a parser fork again, and the strings it preserves, such as a literal `\n` in a prompt, are not what anyone writes on purpose.
- **Move to a newer bayan.** Blocked: 1.5.13 and later need cyrius 6.7.x, and this release pins 6.6.20.
