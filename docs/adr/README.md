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
| [0008](0008-cli-parsing-via-cmdit.md) | CLI parsing via the cmdit distlib, and the first non-stdlib dependency | Accepted |
| [0009](0009-config-parsing-via-bayan.md) | Config parsing via bayan's TOML and CYML sublibs | Accepted |
| [0010](0010-dead-code-elimination-on-every-build.md) | Dead-code elimination on every build | Accepted |
| [0011](0011-prompt-holds-a-reference-not-the-bytes.md) | The shell's prompt variable holds a reference, never the rendered bytes | Accepted |
| [0012](0012-cache-bounded-by-construction.md) | The probe cache is bounded by construction, not by eviction | Accepted |
| [0013](0013-package-json-via-flat-bayan-json.md) | `package.json` is read with bayan's flat JSON parser | Accepted |
| [0014](0014-version-probes-never-see-the-repo.md) | Version probes run outside the repo, and are cached per tool | Accepted |
| [0015](0015-pins-keep-their-name-and-shape.md) | A symlinked pin must keep its name, a pin has a shape, and repo text has a length | Accepted |
| [0016](0016-local-time-through-darshini.md) | The clock shows local time, through darshini's zone code | Accepted |
| [0017](0017-agnos-working-directory.md) | On agnos the directory is agnsh's `$PWD`, and a pin keeps its rules there | Accepted |
