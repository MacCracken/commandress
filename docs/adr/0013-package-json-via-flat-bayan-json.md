# 0013 — `package.json` is read with bayan's flat JSON parser

**Status**: Accepted
**Date**: 2026-11-06

## Context

`node_env` read `.nvmrc` only. Roadmap 1.4.0 adds `package.json` → `engines.node` as a second source when `.nvmrc` is absent. A repository the user merely `cd`s into chooses that file, and it needs a JSON parser, so this is the `rust-toolchain.toml` question again with a larger file. The roadmap gated the work on measuring the cost first and applying what the [2026-11-06 audit](../audit/2026-11-06-audit.md) learned about hostile parser input.

Three things shaped it.

**`engines.node` is the only thing wanted from the file.** No number in a `package.json` matters here, so most of a general JSON parser is unused.

**The audit's standard is high.** Before this, `cmdrs` had no recursion at all, and everything a hostile repo could reach was bounded and fuzzed. bayan's JSON parsers also read through bounds-checked slices, whose failure is `exit 134`, which would blank a prompt if hostile input could reach it.

**Real files are small.** Across 3,955 real `package.json` files on the dev host, the median is 1,153 B, 97.1 % fit in 4 KB and 99.7 % in 8 KB, and the longest `engines.node` is 51 characters. 3,930 of those are library packages in `node_modules`, so application and monorepo roots may run larger.

## Decision

**Read `package.json` with bayan's flat parser, `bayan_json_parse`, and use it twice: once on the file, and once on the raw span of `engines`.**

- `.nvmrc` wins from any level above the cwd. `package.json` is the fallback.
- Only the **nearest** `package.json` is read. One with no `engines` stops the search.
- The read stops at 16 KB. What came before the cut still counts, because the flat parser returns the members it read.
- A value over 255 bytes, or containing a backslash, renders empty.
- The value renders as written. `engines.node` is a range such as `>=18`: what the project asks for, not what is installed.

## Consequences

Measured against 1.3.1 on the dev host. All three candidates below read all 3,955 real files exactly as Python's `json` does, and survived 60,000 hostile fuzz runs each with no crash, no abort and nothing on stderr.

| | Tree parser | **Flat parser (chosen)** | Own scanner |
|---|---|---|---|
| Binary size | +40,432 B (+25 %) | **+19,952 B (+12 %)** | +4,136 B (+3 %) |
| Cold start, typical file, 1.2 KB | +50 µs | **+33 µs** | +17 µs |
| Cold start, large file, 6.3 KB | +171 µs | **+76 µs** | +39 µs |
| Cold start, worst hostile file, 16 KB | +1,884 µs | **+1,000 µs** | +18 µs |
| Recursion | yes, to 128 levels | **none** | none |
| Stack for a hostile file | 64 KB | **12 KB** | 16 KB |
| Peak memory, typical file | 260 KB | **232 KB** | 216 KB |
| Abort path on a bayan bounds bug | yes | **yes** | no |

All of it fits the 5 ms budget. Without `node_env` in the segments the cost is flat, because nothing runs. With it, and no `.nvmrc` anywhere above, each render pays about 20 µs for the second walk.

- **Positive** — A maintained first-party parser reads this file, not one more hand-written scanner in this repo. There is no recursion, so the audit's stack result still holds. A BOM is tolerated, and a cut file loses nothing before the cut.
- **Negative** — The binary grows by 12 %, for one display string. Size is not a budgeted metric ([ADR 0010](0010-dead-code-elimination-on-every-build.md)), so this is accepted.
- **Negative** — A hostile repo can slow its own prompt by about 1 ms, through thousands of distinct keys. The duplicate-key check is the cost. The scanner would not have this.
- **Negative** — The `exit 134` trap is in the binary. It fires on a read past the input, which would be a bug in bayan, and 60,000 hostile runs did not reach it. It is the safer failure, but it would blank that prompt.
- **Negative** — The flat parser is forgiving, so a comment or trailing comma still gives a value. A repo can put any string in a valid file, so this adds no capability.
- **Neutral** — Keys and values compare as written, so `"engines"` is not found. That is the warning in bayan's header, and it matters for allowlists. Here a miss renders nothing.
- **Neutral** — The prompt shows a range for any Node project with `engines` and no `.nvmrc`. A workspace package does not show its monorepo root's range. Showing the running version is a shellout: roadmap 1.4.1.
  > **Update 2026-11-06** (annotation, not a revision): since 1.5.0 the value must look like a semver range, so a value with a colon renders empty, and `package.json` goes through the same symlink rule as a pin. All 2,114 real values surveyed pass. See [ADR 0015](0015-pins-keep-their-name-and-shape.md).

## Alternatives considered

- **`bayan_json_v_parse`, the tree parser.** The obvious choice, and correct: it decodes escapes and refuses what a strict parser refuses. But it builds a tree and parses every number, so it carries bayan's correctly rounded float code and its tables into a path that wants one string. It also recurses, which would have been the first recursion in the binary.
- **An allocation-free scanner in this repo.** About 75 lines, and it wins every measurement. It saves about 16 µs on a typical file, which nobody can see, and it brings back what 1.1.9 removed: a hand-written parser in this repo, like the quote scanner that read `"x"` inside a comment as an element. [ADR 0009](0009-config-parsing-via-bayan.md) exists to stop owning those. Its one real advantage is on hostile files, and that slowdown lands only on the repo that chose it.
- **Climbing past a `package.json` with no `engines`.** It would find a monorepo root's range. It would also read and parse a file per level, up to `ANCESTOR_DEPTH_MAX` levels on every redraw, which is about 128 ms for a hostile tree.
- **Not doing it.** A range is less useful than a pin, and `.nvmrc` already covers projects that care. But it is a small, bounded addition, and many Node projects have `engines` and no `.nvmrc`.
