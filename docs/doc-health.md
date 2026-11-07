---
name: commandress Documentation Health
description: Living state of doc currency in the commandress repo — fresh / stale / evergreen / archived, refreshed as docs are touched.
type: state
---

# Documentation Health — commandress

> **Last refresh**: 2026-11-06 (1.2.3 sweep — full re-inventory; the previous refresh was at
> 1.1.6). | **Refresh cadence**: when docs are touched, update the affected row. **Scope**: this
> repo only — the whole `docs/` tree, `adapters/README.md`, and root-level files. Stdlib
> docs live in [cyrius](https://github.com/MacCracken/cyrius) and aren't audited here.

This is a **ledger**, not a one-time audit. Rewrite in place as docs change.

---

## What the 2026-11-06 sweep found

The ledger had gone stale again, across five releases and three more ADRs. Four findings
were security-relevant, and three of them are the shape the last sweep warned about: **a fix
landed, and the docs either kept teaching the old advice or stated a guarantee it did not give.**

1. `guides/zsh-setup.md` and `guides/bash-setup.md` gave manual pastes that were themselves
   vulnerable to T-01 and T-02. Both said to rely on `prompt_subst` / `promptvars` being off.
   The replacement pastes were **run through `scripts/adapter-check.sh`** before being written down.
2. All three self-tests used `.python-version`, which the default segments do not read, so they
   passed on a vulnerable setup (T-10).
3. `adapters/README.md` taught "the shell must never expand the prompt string", the rule that failed.
4. `adapters/agnoshi.sh` said zsh could consume raw escapes. It cannot, and every zsh user had a
   width bug because of it (T-08).

Three more were stale claims rather than stale advice:

5. `roadmap.md` said agnoshi adoption needed "no commandress change". It does: agnos has no `getcwd`
   by design, so nothing cwd-based can render until `cmdrs_getcwd` reads `$PWD`.
6. `audit/2026-08-26-audit.md` holds eight statements that turned out wrong. It is a dated record,
   so it stays as written, and `audit/2026-11-06-audit.md` lists the corrections.
7. "About 12 KB of init stack" has been out of date since agnos kernel 1.56.46, where it is 2 MB.

---

## At a glance

**52 docs**: 31 markdown under `docs/`, 6 theme `.cyml` + 1 annotated `.example`, the benchmark CSV,
plus `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `adapters/README.md`, and the three adapters and six
scripts whose header comments carry rationale.

| Bucket | Meaning |
|---|---|
| ✅ **Fresh** | Touched in the 1.2.x cycle or this sweep. |
| 🟢 **Current, untouched** | Accurate as written. Last edit predates this cycle because nothing invalidated it. |
| 🔵 **Evergreen** | Refresh only when the underlying process or decision changes. |
| 📦 **Archived by design** | A dated snapshot. Never edited. |
| 🟡 **Stale** | None. |

---

## Inventory

### Root

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | 2026-11-06 | ✅ Fresh | Status line, layout tree, roadmap pointers. |
| `CHANGELOG.md` | 2026-11-06 | ✅ Fresh | **Source of truth per CLAUDE.md.** Through 1.3.0. |
| `CLAUDE.md` | 2026-08-26 | 🔵 Evergreen | Process + rules. |
| `adapters/README.md` | 2026-11-06 | ✅ Fresh | Security section rewritten around the reference rule (ADR 0011). |

### `docs/development/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `state.md` | 2026-11-06 | ✅ Fresh | **Rotates every release.** Through 1.3.0. |
| `roadmap.md` | 2026-11-06 | ✅ Fresh | 1.2.3 and 1.3.0 moved to the CHANGELOG. New items at 1.5.0 and 1.x.x, each pinned to the audit. |

### `docs/adr/` — 12 records

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | 2026-11-06 | ✅ Fresh | Index; 12 entries. |
| `0001-separate-repo-from-agnoshi.md` | 2026-05-15 | 🔵 Evergreen | Accepted; stands. |
| `0002-segment-rendering-model.md` | 2026-05-17 | 🟢 Current | Accepted. Still describes the shipped model. |
| `0003-config-format.md` | 2026-05-17 | 🟢 Current | Accepted. |
| `0004-vcs-probe-via-sit.md` | 2026-05-17 | 🟢 Current | Accepted. |
| `0005-language-env-probe-pattern.md` | 2026-11-06 | ✅ Fresh | Accepted. Annotated at 1.2.2. |
| `0006-config-path-rename.md` | 2026-05-18 | 🟢 Current | Accepted. |
| `0007-schema-freeze.md` | 2026-11-06 | ✅ Fresh | Accepted, and load-bearing. Annotated at 1.2.2 and 1.3.0, when the reserved colour forms shipped. |
| `0008-cli-parsing-via-cmdit.md` | 2026-08-26 | 🟢 Current | Accepted. |
| `0009-config-parsing-via-bayan.md` | 2026-11-06 | ✅ Fresh | Accepted. Its "never reads a repo-local config" is annotated as out of date. |
| `0010-dead-code-elimination-on-every-build.md` | 2026-11-06 | ✅ Fresh | Accepted at 1.2.2. |
| `0011-prompt-holds-a-reference-not-the-bytes.md` | 2026-11-06 | ✅ Fresh | Accepted at 1.2.3. Reverses P-01's approach. |
| `0012-cache-bounded-by-construction.md` | 2026-11-06 | ✅ Fresh | Accepted at 1.2.3. Replaces the planned eviction. |
| `template.md` | 2026-05-15 | 🔵 Evergreen | Refresh only if the ADR shape changes. |

### `docs/architecture/` — 3 notes

| File | Last touched | Status | Notes |
|---|---|---|---|
| `README.md` | 2026-08-26 | 🟢 Current | Index; 3 entries. |
| `001-prompt-render-budget.md` | 2026-11-06 | ✅ Fresh | Now says which CI step sees a real cold start. |
| `002-shellout-watchdog.md` | 2026-11-06 | ✅ Fresh | "Nothing after the loop may block", with the third way that was got wrong. |
| `003-cyrius-lock-shape.md` | 2026-11-06 | ✅ Fresh | New § 5: what each guard catches, with the measured misses. |

### `docs/audit/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `2026-05-18-audit.md` | 2026-05-18 | 📦 Archived | Dated snapshot (F-1…F-12). Never edit. |
| `2026-08-26-audit.md` | 2026-08-26 | 📦 Archived | Dated snapshot. Never edit. Corrected by the next row. |
| `2026-11-06-audit.md` | 2026-11-06 | ✅ Fresh | 1.2.3 sweep — 2 HIGH / 6 MEDIUM / 20 LOW / 5 INFO, plus *Verified clean*, *Confirmed but deliberately not fixed*, *Known gaps*. |

### `docs/guides/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `getting-started.md` | 2026-11-06 | ✅ Fresh | Updated at 1.2.2 and 1.2.3. Colour forms at 1.3.0. |
| `zsh-setup.md` | 2026-11-06 | ✅ Fresh | **Security-relevant repair.** New paste, executed under attack. |
| `bash-setup.md` | 2026-11-06 | ✅ Fresh | **Security-relevant repair.** New paste, executed under attack. |

### `docs/examples/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `prompt-tour.md` | 2026-11-06 | ✅ Fresh | **Security-relevant repair.** The warning no longer describes the old hook as safe. |
| `commandress.cyml.example` | 2026-11-06 | ✅ Fresh | Gained `budget_ms` at 1.2.2, and the colour forms at 1.3.0. |

### `docs/benchmarks*` and `docs/themes/`

| File | Last touched | Status | Notes |
|---|---|---|---|
| `benchmarks.md` | 2026-11-06 | ✅ Fresh | Budget section now separates the two gates and gives real cold-start figures. Its per-segment table is still the v1.1.6 run; `state.md` carries current numbers. |
| `benchmarks/README.md` | 2026-05-18 | 🟢 Current | Column semantics; unchanged. |
| `benchmarks/history.csv` | 2026-11-06 | ✅ Fresh | Rows through 1.2.3. |
| `themes/README.md` | 2026-11-06 | ✅ Fresh | Six themes. No longer says the colour forms are coming. |
| `themes/*.cyml` (6) | 2026-11-06 | ✅ Fresh | commandress / nord / dracula / gruvbox / monokai, plus powerline at 1.2.2, which gained `right_segments` at 1.3.0. |
| `doc-health.md` | 2026-11-06 | ✅ Fresh | This ledger. |

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
- **When a security fix lands in code, grep the docs for the old advice.** This has now
  gone wrong twice: 1.1.6 fixed the adapters and nothing swept the guides that documented
  them, and 1.2.3 found the replacement guides taught a fix that was itself incomplete.
- **Run a paste before you publish it.** `scripts/adapter-check.sh` takes any adapter, so a
  manual paste in a guide can go through the same attacks as the real one.
