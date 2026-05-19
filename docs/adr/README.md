# Architecture Decision Records

Decisions about commandress — what we chose, the context, and the consequences we accept. Use these when a future reader would reasonably ask *"why did we do it this way?"*

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. Never renumber.
- **One decision per ADR.** If a decision supersedes a prior one, add a new ADR and set the old one's status to `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use [`template.md`](template.md) as the starting point.

## ADR vs. architecture note vs. guide

| Kind | Lives in | Answers |
|---|---|---|
| ADR | `docs/adr/` | *Why did we choose X over Y?* |
| Architecture note | `docs/architecture/` | *What non-obvious constraint is true about the code?* |
| Guide | `docs/guides/` | *How do I do X?* |

## Index

| # | Title | Status |
|---|---|---|
| [0001](0001-separate-repo-from-agnoshi.md) | Prompt rendering lives in its own repo, not inside agnoshi | Accepted |
| [0002](0002-segment-rendering-model.md) | Segment rendering model: pure function of context, no shared state | Accepted |
| [0003](0003-config-format.md) | Config format: CYML for the user config file | Accepted |
| [0004](0004-vcs-probe-via-sit.md) | VCS probe shells out to `sit`, not external `git` | Accepted |
| [0005](0005-language-env-probe-pattern.md) | Language-env segments follow a file-first probe pattern | Accepted |
| [0006](0006-config-path-rename.md) | Config file lives at `~/.commandress`, not `~/.commandress.cyml` | Accepted |
| [0007](0007-schema-freeze.md) | Public API + config schema freeze for v1.0 | Accepted |
