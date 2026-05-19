# 0007 — Public API + config schema freeze for v1.0

**Status**: Accepted
**Date**: 2026-05-18

## Context

[`roadmap.md`](../development/roadmap.md) M8 calls for a public-API freeze ahead of M9's v1.0 tag. v1.0 criteria #1 — *"Stable config schema — every field documented; breaking changes only via deprecation"* — turns into an enforceable contract here. After tagging v1.0 we promise that:

- A user's `~/.commandress` keeps working across v1.x.
- A shell adapter sourcing `adapters/zsh.sh` / `bash.sh` / setting `AGNOSHI_PROMPT_CMD=cmdrs` keeps working across v1.x.
- A script invoking `cmdrs` / `cmdrs --side=right` keeps working across v1.x.

This ADR enumerates exactly what's frozen, what isn't, and what the deprecation path looks like for anything in the frozen set that we later regret.

The freeze comes *after* the v0.9.0 audit ([`docs/audit/2026-05-18-audit.md`](../audit/2026-05-18-audit.md)) and *before* the v1.0 tag — sequence is intentional. Audit findings F-1 / F-3 / F-4 / F-5 / F-7 / F-8 land in v0.9.0; those code changes don't affect the schema surface, so freezing the schema afterward doesn't lock in a known vulnerability.

## Decision

**The following surfaces are frozen at v1.0 and changeable only via the deprecation path described below:**

### 1. Config file path

`$HOME/.commandress`. Format implicit (CYML; documented in [ADR 0003](0003-config-format.md), filename in [ADR 0006](0006-config-path-rename.md)).

### 2. Config schema — fields

The exhaustive set of accepted fields per `[[…]]` section. Unknown fields warn to stderr but don't fail (per `_warn_unknown_pairs` in `src/config.cyr`); the v1.0 freeze means *these specific* known fields cannot be removed or have their type/semantics changed.

**`[[prompt]]`** — prompt-level config:

| Field | Type | Default | Semantic |
|---|---|---|---|
| `segments` | `[string]` | `["cwd", "vcs", "exit"]` | Left-prompt segment list, rendered in array order |
| `right_segments` | `[string]` | `[]` | Right-prompt segment list (rendered when `--side=right`) |
| `separator` | `string` | `" "` | Joined between adjacent painted segments in plain mode |
| `trailer` | `string` | `" $ "` | Appended after the last left-segment (never on right-prompt) |
| `separator_style` | `string` | `"plain"` | `"plain"` or `"powerline"`. Unknown strings → plain |
| `separator_glyph` | `string` | `""` | Powerline transition glyph (left-prompt) |
| `right_separator_glyph` | `string` | `""` | Powerline transition glyph (right-prompt) |

**`[[palette]]`** — named colour slots. Key-value pairs of `name = "color"`. Names are arbitrary user-chosen identifiers; values are 16-named-ANSI strings (see §3) or the literal `"default"`.

**`[[segments.cwd]]`**:

| Field | Type | Default | Semantic |
|---|---|---|---|
| `home_shorten` | `bool` | `true` | Replace leading `$HOME` with `~` |
| `max_length` | `int` | `0` | Truncate at `/` boundaries when > N bytes (`0` = no limit) |
| `fg` / `bg` / `style` | `string` | — | Per-segment styling (see §3) |

**`[[segments.exit]]`**:

| Field | Type | Default | Semantic |
|---|---|---|---|
| `hide_zero` | `bool` | `true` | Render empty when `$AGNOSHI_LAST_EXIT == 0` |
| `fg` / `bg` / `style` | `string` | — | Per-segment styling |

**`[[segments.vcs]]`**:

| Field | Type | Default | Semantic |
|---|---|---|---|
| `show_dirty` | `bool` | `true` | Append `dirty_marker` when working tree is dirty |
| `dirty_marker` | `string` | `"*"` | Appended after branch name when dirty |
| `fg` / `bg` / `style` | `string` | — | Per-segment styling |

**`[[segments.time]]`**:

| Field | Type | Default | Semantic |
|---|---|---|---|
| `format` | `string` | `"%H:%M"` | strftime-subset format: `%H %M %S %Y %y %m %d %%`; unknown specs pass through literally |
| `fg` / `bg` / `style` | `string` | — | Per-segment styling |

**`[[segments.hostname]] / [[segments.user]] / [[segments.cyrius_env]] / [[segments.python_env]] / [[segments.node_env]] / [[segments.rustup_env]]`** — colour-only sections, fields `fg` / `bg` / `style` only.

### 3. Colour value space

| Form | Example | Accepted |
|---|---|---|
| 16 named ANSI colours | `"red"`, `"bright_cyan"` | yes |
| The literal `"default"` | `"default"` | yes — emits no SGR code |
| Palette reference | `"palette:primary"` | yes — resolved at config-load |
| Hex (`#rrggbb`) | `"#5fafff"` | **reserved** — accepted as a future extension (returns "no code" today; never errors) |
| 256-colour index | `"33"` | **reserved** — same as hex |

The 16 named colours are: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`, and their `bright_*` variants.

The `style` field accepts space-separated tokens: `bold`, `italic`, `underline`, `reverse`. Unknown tokens are silently skipped. Empty `style = ""` means no modifiers.

### 4. CLI

| Invocation | Stdout | Stderr |
|---|---|---|
| `cmdrs` | Left prompt (config `segments` + `trailer`) | warnings on unknown config keys / segments |
| `cmdrs --side=right` | Right prompt (config `right_segments`, no trailer) | same |
| `cmdrs --side=left` | Same as bare `cmdrs` | same |

Unknown flags currently fall through to left-side default. **Reserved**: `--side=<other>`, `--config=<path>`, `--version`, `--help` for future extension. We don't promise behaviour on unknown flags today; v1.0+ extends here without breakage.

### 5. Env-var contract — what cmdrs reads

| Env var | Type | Role |
|---|---|---|
| `$HOME` | path | Config path build + cwd home-shorten |
| `$AGNOSHI_LAST_EXIT` | int (`0..65535`, clamped — see [audit F-7](../audit/2026-05-18-audit.md)) | Exit-code segment input |
| `$PATH` | colon-list | `find_in_path` for vcs (sit) and cyrius_env (cyrius). Absolute entries only — [audit F-8](../audit/2026-05-18-audit.md) |
| `$VIRTUAL_ENV` | path | python_env segment |
| `$USER` | string | user segment fallback |

### 6. Env-var contract — what cmdrs writes

`cmdrs` does **not** modify the environment of its calling shell. Output is stdout only.

### 7. Adapter contract — what cmdrs's consumer must do

The five-point contract in [`adapters/agnoshi.sh`](../../adapters/agnoshi.sh)'s header. Frozen at v1.0. Summary:

1. Read `$AGNOSHI_PROMPT_CMD` (consumer side) once per prompt cycle.
2. Export `$AGNOSHI_LAST_EXIT` before invoking the command.
3. Capture stdout as the prompt string — **literal byte string**, no shell-syntax pass.
4. Optional `--side=right` for right-prompt.
5. Direct exec semantics (no shell-string interpretation of `$AGNOSHI_PROMPT_CMD`).

### 8. File paths

| Path | Purpose | Owner |
|---|---|---|
| `$HOME/.commandress` | Config | user |
| `/tmp/commandress-<uid>/` | Per-redraw cache (1 s TTL) | cmdrs |
| `/tmp/commandress-<uid>/<seg>-<hash>` | Cached segment value | cmdrs |
| `/tmp/commandress-<uid>/<seg>-<hash>.tmp.<pid>` | Atomic-write staging (audit F-5) | cmdrs (ephemeral) |

The cache layout is implementation-bound but the public-facing `/tmp/commandress-<uid>/` prefix is frozen — system administrators provisioning hosts know what to clean up / what to grant perms on.

## What is NOT frozen

- **The set of segments.** New segments can be added (e.g. `ruby_env`, `go_env`, `kubernetes`, `aws_region`); the registry table in `src/render.cyr::_seg_fn_for` grows. Existing segments stay registered.
- **The set of named colours.** Could extend to a wider named palette if we ever need it (e.g. `gray`, `orange`); current 16 stay accepted.
- **The set of style modifiers.** `dim`, `strikethrough`, `blink` could land later; current four stay accepted.
- **Hex / 256-colour values.** Reserved in §3 — when implemented, they become first-class accepted values without breaking anyone.
- **Multi-palette via `[[palettes.<name>]]` + top-level `palette = "<name>"` selector.** This is the v1 theme-switching path committed during the M5 colour work; lands in a v1.x release as additive grammar. Single `[[palette]]` (the v0.6.0 form) stays accepted.
- **Per-segment `budget_ms` / cache TTL override.** The M2 follow-up slot for `[[segments.vcs]]`; additive.
- **The internal `Config` struct layout.** Field offsets in `src/config.cyr` are implementation; nothing external depends on them.
- **The cache file format.** Currently raw bytes; could become headered + checksummed without breaking the public path layout.
- **The SGR-baking logic.** SGR strings are generated at config-load and never exposed to the user. Free to change.

## Deprecation path — for anything we later regret

If a frozen field needs to change semantics in v1.x:

1. **v1.x release**: introduce the new field / new value. Old form continues to work. Add a stderr deprecation warning when the old form is detected — gated on a `COMMANDRESS_DEPRECATION_WARNINGS=1` env var so users not yet ready to migrate aren't spammed.
2. **v1.x+N release (after at least one minor cycle)**: change the default behaviour. Old form still works but is documented as deprecated. Deprecation warning becomes default-on.
3. **v2.0 release**: only path that can remove a field. Bumps major. CHANGELOG carries the migration.

We do NOT delete or rename fields in v1.x. We do NOT add new required fields in v1.x (added fields must have a documented default).

## Consequences

- **Positive**
  - Users can write a `~/.commandress` against v0.9.0 and know it'll keep working through every v1.x release. The trust this builds is the entire point of a v1.0 release.
  - Adapter authors (us; future agnoshi maintainers; third-party shell integrations) have a stable env-var + CLI contract to write against.
  - The audit doc + this ADR together codify *which* surfaces are part of the public contract — review for new contributions has an explicit "is this changing a frozen surface?" gate.
  - The deprecation path is concrete enough to follow without re-debating the rules each time.
- **Negative**
  - **Refactoring debt.** Anything we frozen that turns out to be the wrong shape — we live with it until v2.0. Mitigation: the schema is small (10 fields per typical segment block, ~50 fields total across the schema). Auditable in one sitting.
  - **Reserved value spaces (hex, 256-colour, multi-palette) commit us to delivering them additively.** If we later want to deny hex entirely, we can't. Considered acceptable — the costs of denying hex post-v1.0 are abstract; the costs of breaking existing themes are real.
  - **`AGNOSHI_LAST_EXIT` clamps to `[0, 65535]`** ([audit F-7](../audit/2026-05-18-audit.md)). If a shell ever emits exit codes outside that range, we silently floor/ceiling. POSIX is `0..255` + signal-killed `128+sig`; 65535 is generous. No real shell hits this.
  - **`/tmp/commandress-<uid>/` prefix is frozen** even though distributions might want different cache homes. XDG-compliant `$XDG_CACHE_HOME` support could land as an *additional* path (read fallback) but the prefix stays.
- **Neutral**
  - **Audit findings F-2 (sit hooks) and F-6 (TOML parser depth) are deferred upstream.** This freeze doesn't bind those — they're filed against `sit` and the Cyrius stdlib respectively, and any fixes flow through new versions of those tools without touching the commandress contract. The audit doc tracks them; this ADR doesn't.

## Alternatives considered

- **Defer freeze to v1.1.** Argument: more time to discover schema warts. Rejected: pushes v1.0 by months for the sake of *finding* issues, when we could equally well *find* them after freeze and fix them via the deprecation path. The freeze date is a forcing function for surface-area discipline.
- **Don't freeze the env-var contract** — only freeze the config file. Rejected: the env vars *are* the public contract for shell adapters. Half-freezing breaks the adapter authors' ability to write against a stable target.
- **Freeze less** — drop the `[[palette]]` / `palette:<name>` ref syntax from the freeze; treat as experimental. Rejected: it's the substrate the curated `docs/themes/` files use, and they're shipped. Demoting it post-ship is the breaking change we're trying to avoid.
- **Freeze more** — lock the cache file format, hash function, internal offsets. Rejected: those are implementation; freezing them prevents performance / soundness improvements (e.g. switching djb2 to a better hash, or adding a header to cache files) for no user benefit.

## References

- [ADR 0002](0002-segment-rendering-model.md) — segment model.
- [ADR 0003](0003-config-format.md) — CYML config format.
- [ADR 0004](0004-vcs-probe-via-sit.md) — sit (not git) for VCS.
- [ADR 0005](0005-language-env-probe-pattern.md) — language-env probe pattern.
- [ADR 0006](0006-config-path-rename.md) — `~/.commandress.cyml` → `~/.commandress`.
- [`docs/audit/2026-05-18-audit.md`](../audit/2026-05-18-audit.md) — v0.9.0 audit with findings F-1..F-12 and CVE cross-references.
- [`docs/development/roadmap.md`](../development/roadmap.md) — M8 / M9 sequencing.
