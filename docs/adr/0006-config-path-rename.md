# 0006 — Config file lives at `~/.commandress`, not `~/.commandress.cyml`

**Status**: Accepted
**Date**: 2026-05-18

## Context

`commandress` shipped through v0.6.0 reading its config from `~/.commandress.cyml`. The `.cyml` extension was a holdover from [ADR 0003](0003-config-format.md), which chose CYML as the config format and made the file extension match — analogous to starship's `~/.config/starship.toml`.

Two problems surfaced as the user base (one daily user, the author) actually lived with the file:

1. **The dotfile convention doesn't carry extensions.** `.bashrc`, `.zshrc`, `.vimrc`, `.gitconfig`, `.tmux.conf`, `.editorconfig`, `.npmrc` — none advertise their format in the filename. The tool's identity is the marker; the format is implicit and documented elsewhere. `.commandress.cyml` reads like a stray rather than a settled dotfile.
2. **The schema-freeze criterion for v1 (see [`roadmap.md`](../development/roadmap.md)) locks the file path along with the schema fields.** Changing the path post-freeze would be a breaking change requiring a deprecation cycle. Doing it pre-freeze costs the author a `mv` command and a CHANGELOG line.

Constraints framing the change:

- **One daily user today** (the author). Zero migration cost beyond the author's own `mv ~/.commandress.cyml ~/.commandress`.
- **No installer / distribution layer to coordinate.** The binary is self-installed.
- **CYML is still the format.** The filename change doesn't touch the loader's parse path; the file is still parsed as CYML.

User direction recorded 2026-05-18: "we would probably just make it a .commandress file and expect it to be cyml" — picked **clean break** (single canonical path, no fall-back) over fall-back-support and defer-to-v1 in the question that followed.

## Decision

**`cmdrs` reads `~/.commandress` from v0.6.x onward.** No fall-back to `~/.commandress.cyml`; users with the old path get the baked-in defaults until they rename.

In scope for this ADR:

- `src/main.cyr::_default_config_path` builds `$HOME/.commandress` (no `.cyml` suffix).
- Schema, loader, and all parsing code are unchanged — the file is still CYML.
- Docs (README, getting-started, zsh-testing, themes/README, prompt-tour, state.md, CLAUDE.md, architecture/001) all updated to reference the new path.
- CHANGELOG `[Unreleased]` notes the rename as a **Breaking** change.

Out of scope (deferred):

- **Fall-back support for the old path.** Considered and rejected — see Alternatives below.
- **Stderr warning when `~/.commandress.cyml` is present alongside `~/.commandress`.** Not needed; we're not maintaining two paths.
- **Migration command** (`cmdrs init` or similar). Not justified for one user; `mv` is the migration. If a distribution path emerges, revisit.
- **`$XDG_CONFIG_HOME` support.** The original [ADR 0003](0003-config-format.md) noted `$XDG_CONFIG_HOME/commandress.cyml` as a future fall-back; this remains future work and is unrelated to the home-dotfile name.

## Consequences

- **Positive**
  - Matches dotfile convention (`.bashrc`, `.vimrc`, `.gitconfig`) — users encountering `~/.commandress` for the first time read it as "settled config", not "stray file".
  - Filename is one token shorter (`.commandress` vs `.commandress.cyml`); easier to type, easier to talk about.
  - Tool identity is the marker; the format is implicit (documented in the ADR + README), the way every other tool-config dotfile works.
  - Pre-v1 schema freeze ([`roadmap.md`](../development/roadmap.md) M8) locks the path. Doing this now means no breaking change at v1.
- **Negative**
  - **Breaking for v0.6.0 users.** Any existing `~/.commandress.cyml` stops being read; the user sees the default prompt until they `mv`. Mitigation: one CHANGELOG note + one line in the v0.7.0 release-notes / README. With the user base at one, this is a sentence, not a migration.
  - The file's format is no longer self-documenting from the filename — a stranger reading `~/.commandress` has to consult docs (or syntax-highlight) to know it's CYML. Same trade-off `.bashrc` makes: convention + docs replace explicit advertising.
  - **Drops a small forensics signal.** Tools / editors that index dotfiles by extension (some grep wrappers, ripgrep config) won't auto-treat `.commandress` as TOML / CYML. Workaround: tell those tools explicitly; not a real problem for a niche prompt config.
- **Neutral**
  - No code surface beyond `src/main.cyr::_default_config_path`'s suffix string. Parse path, schema, validation are all untouched.
  - This is the second filename-related decision in the ADR series ([ADR 0003](0003-config-format.md) chose the format; this one renames the file). ADR 0003 stands — CYML is still the answer — and historical references in it to `~/.commandress.cyml` reflect the original choice; this ADR supersedes those filename references only.

## Alternatives considered

- **Fall-back support during 0.6.x** — accept both `~/.commandress` and `~/.commandress.cyml`, prefer the new path, fall through to the old one if absent. Emit a stderr deprecation warning on the old path. Rejected: the userbase is one person, the migration is `mv`, and supporting both paths means carrying two strings + a deprecation timer for no real benefit. The cleanest signal *to ourselves* about the new contract is a single canonical path.
- **Defer until v1 schema freeze** — keep `.commandress.cyml` through 0.6.x and 0.7.x; rename at v0.9.0 alongside other config-stabilization work. Rejected: every release that uses the old name is one more reference to clean up; the path is the easiest thing to lock and the least costly to change *now*.
- **Keep `.commandress.cyml`** — do nothing. Rejected: the dotfile convention is real, the schema freeze is coming, and changing later costs more than changing now.
- **Use `$XDG_CONFIG_HOME/commandress/config.cyml`** — fully-XDG-conformant home. Rejected for v0.6.x — solves a real problem (Unix-fs-spec compliance) but is orthogonal to the dotfile naming question. XDG support can land additively without further rename if it's worth pursuing.

## References

- [ADR 0003](0003-config-format.md) — original config-format decision (CYML). Stands as-is; this ADR supersedes only its filename references.
- [`docs/development/roadmap.md`](../development/roadmap.md) M8 — schema freeze that this rename pre-empts.
- `.bashrc`, `.zshrc`, `.vimrc`, `.gitconfig`, `.editorconfig` — the convergent dotfile-naming convention being adopted.
