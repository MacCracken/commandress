# 0016 — The clock shows local time, through darshini's zone code

**Status**: Accepted
**Date**: 2026-11-06

## Context

The `time` segment has always painted UTC. `src/segments/time.cyr` deferred the rest as its own slot: `TZ` lookup plus offset application. No doc ever said the clock was UTC, so anyone using it saw a clock some hours wrong and could do nothing about it.

Reading a zone takes more than an offset. `/etc/localtime` is a TZif file with a transition table and a POSIX rule in its footer for the years after the table ends. `TZ` can name a zone, a file, or a POSIX string such as `EST5EDT,M3.2.0,M11.1.0` or `<+0530>-5:30`. That is several hundred lines to get right, and [darshini](https://github.com/MacCracken/darshini) already had them: its `src/tz.cyr` backs `--local-time`, and is checked against `date(1)` in its own CI.

It could not be pulled in as it stood. It called three helpers from darshini's `src/git.cyr`.

## Decision

**`time` shows local time, chosen as `date` chooses it: `TZ`, else `/etc/localtime`, else UTC. `utc = true` keeps UTC. The zone code is darshini's `src/tz.cyr`, pinned at 1.8.3.**

### Where the code lives

- **darshini 1.8.2 made `src/tz.cyr` self-contained**, against the stdlib alone, and its header now states what an outside project may rely on: `tz_init()` and `tz_offset(t)` keep their meaning, and the file stays standalone. Its `tests/tz-standalone.sh` holds it to that on x86_64, aarch64 and agnos.
- **Review here made 1.8.3.** Pinning it found a crash and some strings that disagreed with `date`, and those were fixed at the source, so both projects have them: a zone with `isdst` above 1 ended the process, `TZ=:EST5` read as UTC, and an offset past 24 hours was not clamped. The read cap also came down from 1 MB to 64 KB, because a 1 MB file cost 8 to 19 ms on each redraw.
- **It is a tag-pinned source dep**, `[deps.darshini]` with `modules = ["src/tz.cyr"]`, under [ADR 0008](0008-cli-parsing-via-cmdit.md). Only that file is included.
- **`cyrius deps` also vendors darshini's own dep, `lib/darshana.cyr`.** That is 109 KB in the tree and a lock line. Nothing includes it, so no byte of it reaches the binary.

### What local means

- **Local by default.** No doc promised UTC, so there is no contract to deprecate under [ADR 0007](0007-schema-freeze.md), and a prompt clock some hours off is a defect. The change goes under **Breaking** in the changelog, with its one-line way back.
- **`utc = true` skips all of it**: no read, no parse, the old clock. A new field with a documented default, so additive.
- **An offset no zone could have reads as UTC.** A zone file can claim anything, and a clock pushed before 1970 makes `epoch_to_date` print junk such as `1970-01-X0`. `time_shift` refuses an offset past 26 hours, and any result below zero, which an ordinary zone can reach on a clock near zero. RFC 9636 recommends a smaller range than that, and no real zone comes close.
- **A zone only moves the digits.** There is no `%Z`, so no name from a zone file or a `TZ` string reaches the prompt. `TZ` can name any file without its contents being shown.

## Consequences

- **Positive** — The clock is right. All 1,795 zone files on this machine and 18 POSIX and edge strings match `date` through the shipped binary.
- **Positive** — One zone parser for the whole stack, with its tests in one place, and darshini has the fixes this review found.
- **Positive** — `TZ` naming `/proc/self/environ`, a device or a directory shows nothing but the UTC clock.
- **Negative** — The hour changes for anyone already showing `time`. `utc = true` is the way back, and it goes under **Breaking** in the changelog.
- **Negative** — A prompt showing `time` reads a zone on each redraw: +31 µs here, +50 µs for the largest zone, +19 µs for a POSIX string. `utc = true` skips it. Prompts without `time` pay nothing.
- **Negative** — The binary grows by 17,744 B (+8.9 %), for a segment that is not in the default set. Size is not a budgeted metric ([ADR 0010](0010-dead-code-elimination-on-every-build.md)).
- **Negative** — `lib/darshana.cyr` is 109 KB of vendored source that nothing includes, because `cyrius deps` follows darshini's own manifest. No byte of it reaches the binary.
- **Negative** — This repo now pins a file from a binary, not a library. The file's header makes it a contract, and moving it to the stdlib later would change only an include.
- **Neutral** — A failed `vec` allocation in that file still aborts, as the stdlib does. With a 64 KB read cap that takes real memory pressure.
- **Neutral** — A few strings no zone uses still differ from glibc: `EST5EDT,M3.2.0`, `EST5,` and `EST5EDT ` read as UTC. The header of `src/tz.cyr` lists them.
- **Neutral** — `agnos` has no zone database, so it shows UTC.

## Alternatives considered

- **UTC by default, `local = true` to opt in.** What darshini does, and changes nothing for anyone. The clock stays wrong for most people until they find the field, and flipping it later would need the deprecation path.
- **Move the code into the Cyrius stdlib.** Its natural long-term home, beside `chrono`. It means a cyrius release and a toolchain bump first, and nothing here prevents that move later: `tz_init` and `tz_offset` would simply come from another file.
- **A small reader in this repo, for the offset at this moment only.** No outside step, and smaller. It would be a second zone parser to maintain, without the checks against `date` that darshini already has. This repo removed its forks of two parsers at 1.1.9 for that reason.
- **Pull `src/tz.cyr` as it stood, with shims for darshini's helpers.** Works, and names another project's internals in this repo. Any refactor there would break the build here.
