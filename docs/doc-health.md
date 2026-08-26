---
name: commandress Documentation Health
description: Living state of doc currency in the commandress repo — fresh / stale / evergreen / archived, refreshed as docs are touched.
type: state
---

# Documentation Health — commandress

> **Last refresh**: 2026-08-26 (post-1.1.6 doc sweep — full re-inventory, roadmap
> reorganised into 1.2.x→1.x.x, five stale docs repaired, two of them security-relevant).
> | **Refresh cadence**: when docs are touched, update the affected row. **Scope**: this
> repo only — the whole `docs/` tree, `adapters/README.md`, and root-level files. Stdlib
> docs live in [cyrius](https://github.com/MacCracken/cyrius) and aren't audited here.

This is a **ledger**, not a one-time audit. Rewrite in place as docs change.

---

## What the 2026-08-26 sweep found

The previous refresh was **2026-05-17, at v0.3.0** — five releases and three months
stale. It inventoried 17 docs; there are now 36. It listed ADRs 0001–0004; there are
eight. The ledger had itself gone stale, which is the failure mode a ledger exists to
prevent.

Two findings were security-relevant, and both are the same shape: **v1.1.6 fixed the
adapters, but the docs still taught the vulnerable configuration.**

1. `guides/zsh-setup.md` documented `setopt prompt_subst` and gave a manual paste
   containing it. That is the exact arbitrary-command-execution vector the
   [2026-08-26 audit](audit/2026-08-26-audit.md) (P-01) removed from `adapters/zsh.sh`.
   A user following the guide re-created the vulnerability by hand.
2. `examples/prompt-tour.md` recommended `PROMPT='$(_cmdrs_prompt)'` — single-quoted,
   which *only works* with `prompt_subst`. Same vector, taught as the zsh idiom.

`guides/bash-setup.md`'s manual recipe was missing both bash fixes (`shopt -u promptvars`
and backslash-doubling). All three now carry vetted pastes plus a security section, and
**the replacement recipes were executed against the live attack before being written
down** — not just reasoned about.

Two more findings were stale *blockers* rather than stale prose:

3. `src/config.cyr` and `src/segments/rustup_env.cyr` both deferred work to a Cyrius gap
   (papercut Item 3, single-bracket TOML sections). **The gap has closed.** Verified
   against the 6.5.35 stdlib, with a control case. `rust-toolchain.toml` is now scheduled
   work (roadmap 1.3.0) rather than blocked work, and single-bracket `[section]` config
   *already works* — undocumented until this sweep, now documented and pinned by a test.
4. Item 8 (no stdlib `which()`) was re-checked and **genuinely still holds**, so
   `src/pathlookup.cyr` stays. Recorded with the date it was checked.

`guides/getting-started.md` had been flagged 🟡 **stale in the 2026-05-17 ledger and never
fixed** — it still documented a `[prompt] order =` schema that never shipped, a
`[segments.git]` section (it is `vcs`), and `--config` / `--debug` flags that do not
exist. Rewritten against the real schema, and the replacement config was run through
`cmdrs` to confirm it renders with no warnings.

---

## At a glance

**36 docs** (26 markdown under `docs/`, 5 theme `.cyml` + 1 annotated `.example`, plus
`README.md`, `CHANGELOG.md`, `CLAUDE.md`, `adapters/README.md`).

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh** | 21 | Touched in the 1.1.4–1.1.6 cycle or this sweep. |
| 🟢 **Current, untouched** | 11 | Accurate as written; last edit predates this cycle because nothing invalidated them (themes, older ADRs, benchmark README). |
| 🔵 **Evergreen** | 3 | CLAUDE.md, ADR 0001, ADR template — refresh only when the underlying process/decision changes. |
| 📦 **Archived by design** | 1 | `audit/2026-05-18-audit.md` — a dated snapshot; never edited, superseded by the 2026-08-26 pass. |
| 🟡 **Stale** | 0 | — |

---

## Inventory

### Root

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | 2026-08-26 | ✅ Fresh | Status line, test counts (2×), segment-table header, vcs timing, layout tree (added `cli.cyr`, `cyrius.lock`, `lock-check`), ADR range, audit links — all corrected this sweep. |
| `CHANGELOG.md` | 2026-08-26 | ✅ Fresh | **Source of truth per CLAUDE.md.** Through 1.1.6. |
| `CLAUDE.md` | 2026-08-26 | 🔵 Evergreen | Process + rules. Dependency rule rewritten at 1.1.5 (runtime vs first-party source deps, ADR 0008). Volatile state delegated to `state.md`. |
| `adapters/README.md` | 2026-08-26 | ✅ Fresh | Gained the *"prompt string is DATA, not a script"* section at 1.1.6, with a per-shell rule table and a two-line self-test. |

### `docs/development/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `state.md` | 2026-08-26 | ✅ Fresh | **Rotates every release.** Through 1.1.6. |
| `roadmap.md` | 2026-08-26 | ✅ Fresh | **Reorganised this sweep** from v1.0 milestone framing into 1.2.0 → 1.5.0 slots plus an unscheduled/externally-gated section. Every item links to the source line that defers it. |

### `docs/adr/` — 8 records

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | 2026-08-26 | ✅ Fresh | Index; 8 entries. |
| `0001-separate-repo-from-agnoshi.md` | 2026-05-15 | 🔵 Evergreen | Accepted; scaffold-era decision, stands. |
| `0002-segment-rendering-model.md` | 2026-05-17 | 🟢 Current | Accepted. Still describes the shipped model. |
| `0003-config-format.md` | 2026-05-17 | 🟢 Current | Accepted. |
| `0004-vcs-probe-via-sit.md` | 2026-05-17 | 🟢 Current | Accepted. |
| `0005-language-env-probe-pattern.md` | 2026-05-18 | 🟢 Current | Accepted. The file-first policy it records is still policy; 1.3.0 adds opt-in shellouts *alongside* it, not instead. |
| `0006-config-path-rename.md` | 2026-05-18 | 🟢 Current | Accepted. |
| `0007-schema-freeze.md` | 2026-05-18 | 🟢 Current | Accepted, and load-bearing — it reserved `--help`/`--version`, which ADR 0008 then delivered. |
| `0008-cli-parsing-via-cmdit.md` | 2026-08-26 | ✅ Fresh | Accepted. First non-stdlib dependency; costs measured before acceptance. |
| `template.md` | 2026-05-15 | 🔵 Evergreen | Refresh only if the ADR shape changes. |

### `docs/architecture/` — 3 notes

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | 2026-08-26 | ✅ Fresh | Index; 3 entries. |
| `001-prompt-render-budget.md` | 2026-05-18 | 🟢 Current | The 5 ms / 500 µs budgets still hold and still gate CI. |
| `002-shellout-watchdog.md` | 2026-08-26 | ✅ Fresh | Gained the `close(rfd)`-before-`waitpid` invariant at 1.1.6, with both measurements. |
| `003-cyrius-lock-shape.md` | 2026-08-26 | ✅ Fresh | New at 1.1.5 — lock line-order instability, and what a `path` override erases. |

### `docs/audit/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `2026-05-18-audit.md` | 2026-05-18 | 📦 Archived | Dated snapshot (F-1…F-12). Never edit; superseded, not replaced. |
| `2026-08-26-audit.md` | 2026-08-26 | ✅ Fresh | 1.1.6 P-1 sweep — 4 HIGH / 3 MEDIUM / 12 LOW / 2 INFO, plus *Verified clean*, *Confirmed but not fixed*, and *Known gaps*. |

### `docs/guides/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `getting-started.md` | 2026-08-26 | ✅ Fresh | **Was 🟡 stale since 2026-05-17 and never fixed.** Config section, segment-authoring steps, and standalone-run examples rewritten against the real schema and the real CLI; replacement config verified to render with zero warnings. |
| `zsh-setup.md` | 2026-08-26 | ✅ Fresh | **Security-relevant repair** — removed `setopt prompt_subst` from prose and the manual paste, added `%`-doubling and a security section. Replacement recipe executed against the live attack. |
| `bash-setup.md` | 2026-08-26 | ✅ Fresh | **Security-relevant repair** — manual paste gained `shopt -u promptvars` and backslash-doubling; security section added; stale "with `prompt_subst` set" aside removed. Recipe verified. |

### `docs/examples/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `prompt-tour.md` | 2026-08-26 | ✅ Fresh | **Security-relevant repair** — dropped the single-quoted `PROMPT='$(...)'` recipe, now points at the shipped adapters. v0.3.0 framing and the M3–M7 "upcoming" list replaced with the current roadmap pointer. |
| `commandress.cyml.example` | 2026-05-17 | 🟢 Current | Annotated config. Refresh when the schema gains a field — next expected at 1.2.0 (multi-palette). |

### `docs/benchmarks*` and `docs/themes/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `benchmarks.md` | 2026-08-26 | ✅ Fresh | Re-measured at 1.1.6; "v1.0 finalised" framing dropped, `cli_parse` row added, the 0.9.0→1.1.4 CSV gap called out. |
| `benchmarks/README.md` | 2026-05-18 | 🟢 Current | Column semantics; unchanged by the re-measure. |
| `themes/README.md` | 2026-05-18 | 🟢 Current | Its "powerline-ready theme variant is planned" note is now pinned in the roadmap (1.2.0) rather than floating. |
| `themes/*.cyml` (5) | 2026-05-18 | 🟢 Current | commandress / nord / dracula / gruvbox / monokai. Valid against the frozen schema. |
| `doc-health.md` | 2026-08-26 | ✅ Fresh | This ledger. Rebuilt from scratch this sweep. |

---

## Refresh policy

- **Touch a doc, update its row.** This file is part of the doc-change unit, not a
  separate pass.
- **At every release tag**, check the tight quintet is aligned: `VERSION`,
  `cyrius.cyml`, `CHANGELOG.md`, `state.md`, and `README.md`'s status line. Drift between
  them is the canonical release-prep bug. (1.1.5 added a sixth: `src/cli.cyr`'s compiled-in
  version literal — the suite asserts it matches `VERSION`, so that one self-checks.)
- **When you defer work in code**, add it to `roadmap.md` in the same change. The roadmap
  claims every item is pinned to a source line; that only stays true if it is maintained
  as a pair.
- **Re-check upstream gates at each toolchain refresh.** Two of three "blocked on Cyrius"
  claims in this repo were stale by the time anyone re-read them. A gate is a claim about
  the world, and it expires.
- **When a security fix lands in code, grep the docs for the old advice.** Both
  security-relevant findings in this sweep existed because 1.1.6 fixed the adapters and
  nothing swept the guides that documented them.
