# 0002 — Segment rendering model: pure function of context, no shared state

**Status**: Accepted
**Date**: 2026-05-17

## Context

`cmdrs` renders the prompt by composing N independent "segments" (cwd, exit, time, git, etc.). Three model shapes are on the table:

1. **Pure-function pipeline** — each segment is a function from input context (env vars, cwd, last exit) to a rendered string. Segments share no state, run in any order (parallelizable later), and a segment's output depends only on its inputs.
2. **OO/object pipeline** — segments are objects with `init / probe / render` lifecycle, holding state across redraws (cached git result, accumulated timings).
3. **Streaming pipeline** — segments push fragments into a shared output stream as they finish, in completion order.

Constraints to satisfy:

- **Cold start ≤ 5 ms** (v1.0 criterion). Init overhead per redraw matters.
- **Per-segment time budget** — slow segments degrade to empty, not stall. Easier when segments are leaves with no dependencies.
- **No config-coupled order** — the user re-orders segments in `~/.commandress.cyml`. If segment B reads output from segment A, ordering becomes load-bearing and config breaks.
- **One subprocess per redraw** — `cmdrs` is invoked fresh each prompt. Persistent state across redraws would need a daemon or a cache file — out of scope for v1.0.
- **Cyrius-native ergonomics** — Cyrius prefers flat fns over OOP. Method dispatch is convention-based (`Segment_render(&seg, ...)`) but composes worse than first-class fn pointers for a small registry of segments.

## Decision

**Each segment is a pure function of the context struct, returning a small heap-allocated rendered buffer (or 0 for empty).** The render pipeline holds a static array of `{ name, render_fn }` pairs, walks it in config-declared order, and concatenates outputs with the configured separator.

```cyrius
fn cwd_render(ctx): i64 { ... return out_ptr; }  // or 0 for empty
fn exit_render(ctx): i64 { ... return out_ptr; }
```

In scope:

- One pure render fn per segment file (`src/segments/<name>.cyr`).
- A `Context` struct built once at startup (cwd, env vars, last exit, etc.) and passed to every segment.
- A flat segment registry in `src/render.cyr` — order-of-iteration = config order.
- Each segment owns its output buffer (heap-allocated via `alloc`), reusing the per-redraw bump arena means no free needed before process exit.

Out of scope:

- Cross-segment data flow (segment B reading segment A's output). Forbidden by design — each segment reads only the context.
- Persistent state across redraws. M6 may add a `~/.cache/commandress/` cache for git, but that's an opt-in optimization, not a model change.
- Object-style segments. If a segment grows internal phases, those are private to its file.

## Consequences

- **Positive**
  - Trivial parallelization later (M6) — pure fns with no shared state are embarrassingly parallel. `cmdrs` can sprout a thread per segment without rearchitecting.
  - Per-segment time budgets become a simple watchdog around each fn call.
  - Config re-ordering Just Works — the registry walks in array order; segments don't care who came before.
  - Testing is trivial — feed a synthetic `Context`, assert on returned string.
  - Failure mode is "empty segment" — a render fn returning 0 drops out of the line, prompt still ships.
- **Negative**
  - Duplicate work between segments isn't shared. If two segments both want the current branch, they each call git. Mitigation: bake the genuinely-shared probes into `Context` at startup (cwd, last exit, hostname, user, time-now). Subprocess-heavy probes (git) stay segment-local for now.
  - No streaming output — the prompt is one `write(2)` at the end. For a 5 ms budget that's fine; if we ever need <50 µs first-byte latency, this gets revisited.
- **Neutral**
  - Forces every segment to be a self-contained leaf. New segment = one file + one registry entry. The bar to add a segment is low; the bar to make segments depend on each other is "no".

## Alternatives considered

- **Object-style with init / probe / render** — clean per-segment encapsulation, but every redraw pays init overhead even for trivial segments, and Cyrius's method-dispatch convention adds zero help (one call indirection either way). Rejected — too much ceremony for the cold-start budget.
- **Streaming pipeline (write fragments as ready)** — wins ~tens of microseconds of perceived latency but makes config-driven ordering impossible (you'd render in completion order, not config order). Rejected — config-order is non-negotiable.

## References

- [`docs/architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md) — the budget this model has to live inside.
- [`docs/development/roadmap.md`](../development/roadmap.md) M1 + M6 — the milestones this decision unblocks.
- starship's segment model — convergent design (per-module render fn, pure-ish input, JSON-configured order).
