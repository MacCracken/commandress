# 001 — Prompt render budget

The full-prompt render-time budget that `cmdrs` lives inside, the per-segment slice within it, and what the code does when a segment overruns. Not a decision (those are in `../adr/`); a statement of how the runtime works that a reader cannot derive from the code alone.

## Total budget

**5 ms cold start** on Cyrius-current hardware. This is the v1.0 acceptance gate (`docs/development/roadmap.md` v1.0 criteria) and the figure agnoshi assumes when it shells out to `cmdrs` per redraw. The number folds in:

- Process exec — ~1 ms on Linux for a static binary of `cmdrs`'s class.
- `Context` initialization — env-var slurp, `getcwd`, parse last-exit. Target: ≤ 250 µs.
- Config load + parse — read `~/.commandress`, walk it. Target: ≤ 500 µs (memory-mapped; CYML parser is zero-copy).
- All segments combined — ≤ 2.5 ms.
- Render + final write — ≤ 250 µs.

Headroom: ~500 µs. This isn't slack; it's the buffer that absorbs jitter on busy systems. Burn it and the redraw goes from invisible to perceptible.

## Per-segment slice

Default per-segment budget: **500 µs**. Override in config (`[segments.<name>] budget_us = N`) for segments known to be slow (git on a giant repo, language env probing with subprocess exec).

Segments that don't shell out (cwd, exit, time, hostname, user) trivially clear 500 µs — they're env-var reads + `fmt_*` calls. Segments that shell out (git, language env) eat the bulk of the budget and need their own watchdog (M2 will add a per-segment timeout via `setitimer`-or-equivalent; M6 finishes the parallel-segment work).

## Overrun behavior

A segment whose render fn doesn't return within budget renders as **empty** (drops out of the line). The prompt always paints — `cmdrs` never stalls. The user sees a shorter prompt for one redraw; the next redraw tries again from scratch.

What this means concretely:

- A render fn returning `0` (the empty-segment sentinel) is indistinguishable from a timed-out segment. The pipeline treats both the same way.
- No retry-with-cached-value behavior in M1. M6 may layer a 1 s TTL cache on shellout-heavy probes; until then, every redraw runs every segment from scratch.
- Strict mode (debug builds, or `--debug` flag) prints overrun events to stderr so users can spot slow segments.

## Total-budget overrun

If the *aggregate* prompt render time exceeds the 5 ms total even after per-segment timeouts, `cmdrs` still finishes painting (we never tear down mid-render) but the next CI bench cycle will surface the regression. No runtime degradation gate beyond per-segment; the total budget is a CI gate, not a runtime gate.

## Measurement

`cyrius bench tests/commandress.bcyr` (added at M1) captures the full-render time on the bench host and appends a row to a benchmark history CSV (M6 work). Regressions on the bench host are visible in the row-over-row diff.

The cold-start figure on a real shell is end-to-end: `time cmdrs > /dev/null` includes process exec which the bench harness can't measure from inside the binary. The two numbers track each other but the bench's number is always smaller by the exec overhead.
