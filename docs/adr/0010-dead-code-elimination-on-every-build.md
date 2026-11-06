# 0010 — Dead-code elimination on every build

**Status**: Accepted
**Date**: 2026-11-06

## Context

Every vendored stdlib refresh added code `cmdrs` never calls. By 1.2.1 the x86_64 binary was 313,392 B, of which 165,267 B was reachable from nowhere. The roadmap had carried "decide `CYRIUS_DCE=1` for release builds" since 1.1.4, with the note that it should be a decision and not a drift.

Size is not a budgeted metric here, and render time is. So the question was whether DCE costs anything in correctness or speed.

## Decision

**Set `[build] dce = true` in `cyrius.cyml`, so every `cyrius build` eliminates dead code, including CI, release builds and `--agnos`.**

CI also runs the suite with `CYRIUS_DCE=1`, because `cyrius test` does not apply the manifest's setting. Without that, CI would exercise different code from the binary that ships.

## Consequences

- **Positive**
  - x86_64 goes from 313,392 B to 149,552 B (−52.3 %), and `--agnos` from 317,808 B to 145,776 B (−54.1 %), measured before 1.2.2's own additions.
  - Cold start improves: −9.5 µs with no config and −12 µs with the largest theme, in interleaved A/B.
  - Stdlib refreshes stop inflating the binary, so the size note in `state.md` can close.
- **Negative**
  - DCE is one more compiler pass between source and binary, and it has a recent bug: cyrius 6.7.18 fixed it NOP-filling live functions in a program whose reachability took more than 512 rounds. This repo's segment table reaches its dispatchers through function pointers, which is the shape such a pass has to get right. The mitigation is the CI line above, plus the differential run each release.
- **Neutral**
  - The build no longer prints its `unreachable fns` note, so that number needs `CYRIUS_DCE=0` to see.
  - One line reverses this.

## Alternatives considered

- **DCE for release builds only.** Rejected: CI would then test one pipeline and ship another, which is the failure this decision is trying to avoid.
- **Leave it off.** Size is not budgeted, so this was defensible. But DCE turned out to cost nothing measurable and to be slightly faster, so there was nothing to keep it off for.
