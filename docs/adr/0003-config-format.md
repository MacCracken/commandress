# 0003 — Config format: CYML for the user config file

**Status**: Accepted
**Date**: 2026-05-17

## Context

`cmdrs` reads a user-editable config at `~/.commandress.cyml` (declared name; format TBD here). The config drives: segment order, segment toggles, per-segment options (date format, cwd home-shortening, color), separators, and theme. Realistic shape: a small dictionary with an array of segment names + per-segment subsections.

Two natural choices in the AGNOS stack:

1. **CYML** — Cyrius-native format. TOML-style headers on top, optional `---` divider, markdown body below. The `cyrius.cyml` manifest at the project root already uses it. Parser in `lib/cyml.cyr` (vendored).
2. **TOML** — broader-convention, native parser in `lib/toml.cyr` (vendored). Used by starship + Cargo + countless others; users coming from those tools already know the syntax.

Constraints:

- **One config file**, plain text, hand-edited. No JSON (no comments), no YAML (significant whitespace foot-guns).
- **No external deps** — both formats have a Cyrius-native parser in `lib/`. Either way, zero new deps.
- **Sovereign-stack default** — when a Cyrius project picks a format for its own data, the default should be the Cyrius-native one unless there's a reason to do otherwise.
- **User mental model** — a user who edits `~/.commandress.cyml` is a sovereign-stack user. They've already met `cyrius.cyml` at every other project. CYML costs them nothing; TOML asks them to switch parser-mode mid-stack.
- **Markdown body**: CYML's markdown zone (below `---`) is useful for in-file documentation — users can paste theme notes, command references, segment recipes alongside the config without a sidecar README. TOML can't carry prose without comment-bloat.

## Decision

**`~/.commandress.cyml` is CYML.** The TOML header zone holds all settable fields. The markdown zone (below `---`, if present) is ignored by the loader and reserved for user notes.

In scope:

- One parser path: `cyml_parse()` from `lib/cyml.cyr`.
- Schema lives in `src/config.cyr` (M1 deliverable) — validates every TOML field against an allow-list; unknown fields warn but don't fail.
- Defaults are baked into the binary — config file is optional; missing fields fall back to defaults.
- File path: `~/.commandress.cyml` first, then `$XDG_CONFIG_HOME/commandress.cyml`, then defaults.

Out of scope:

- TOML support. Not provided. Users wanting TOML can file the request; the v1.0 default is one format, one parser path.
- Per-format converters / migration tools. CYML from day one means no migration burden.
- Live reload on file change. Per-redraw `cmdrs` re-reads the config; that's the reload mechanism.

## Consequences

- **Positive**
  - Sovereign-stack consistency — `cyrius.cyml`, `~/.commandress.cyml`, future agnoshi configs all share one format. Users learn it once.
  - Markdown body is free annotation space — themes, color references, per-segment notes can travel inline with the config they configure.
  - One parser, one validation path, one schema source-of-truth.
- **Negative**
  - Users coming from starship have to re-type their config in a new syntax. Mitigation: provide a starship-compat example in `docs/examples/` (M5) showing equivalent configs side-by-side.
  - The markdown zone is dead weight if the user never uses it. Mitigation: parser already skips it; cost is zero bytes in memory.
- **Neutral**
  - The decision implicitly says: if `commandress` ever sprouts a sibling daemon, it also uses CYML. That's the right answer; pre-committing here just makes it explicit.

## Alternatives considered

- **TOML** — broader audience recognition, slightly smaller mental model (no markdown zone to ignore). Lost on sovereign-stack consistency and zero migration cost from `cyrius.cyml`.
- **JSON** — rejected outright: no comments, prompt config begs for inline notes.
- **YAML** — rejected outright: significant whitespace + tag soup is a foot-gun for a single-file user config.
- **Bespoke format** — not even considered. Two perfectly fine native parsers exist; rolling a third is pure cost.

## References

- [`lib/cyml.cyr`](../../lib/cyml.cyr) — vendored CYML parser.
- [`docs/adr/0002-segment-rendering-model.md`](0002-segment-rendering-model.md) — the model this config feeds.
- vidya `cyrius/field_notes/language/stdlib_format.cyml` — CYML format walkthrough.
