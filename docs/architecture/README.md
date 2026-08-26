# Architecture notes

Non-obvious constraints, quirks, and invariants that a reader cannot derive from the code alone. Numbered chronologically — never renumber.

Not decisions (those live in [`../adr/`](../adr/)) and not guides (those live in [`../guides/`](../guides/)). An item here describes *how the world is*, not *what we chose* or *how to do something*.

## Items

| # | Title |
|---|---|
| [001](001-prompt-render-budget.md) | Prompt render budget — total / per-segment / overrun behavior |
| [002](002-shellout-watchdog.md) | Shellout watchdog — fork + epoll + kill enforcement for per-segment budgets |
| [003](003-cyrius-lock-shape.md) | `cyrius.lock` — unstable line order, and what a `path` override erases |
