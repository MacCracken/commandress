---
name: commandress Documentation Health
description: Living state of doc currency in the commandress repo — fresh / stale / evergreen / archived, refreshed as docs are touched.
type: state
---

# Documentation Health — commandress

> **Last refresh**: 2026-05-17 (v0.3.0 prep — README + roadmap trim + new `prompt-tour.md` + this file scaffolded). | **Refresh cadence**: when docs are touched, update the affected row. **Scope**: this repo only (`commandress`) — the entire `docs/` tree plus root-level files (README, CHANGELOG, CLAUDE.md, VERSION, LICENSE). Stdlib docs live in [cyrius](https://github.com/MacCracken/cyrius) and aren't audited here.
>
> **Convention adopted from cyrius** (2026-05-17): pattern from [`cyrius/docs/doc-health.md`](https://github.com/MacCracken/cyrius/blob/main/docs/doc-health.md). commandress's tree is small (~16 docs) so this file stays leaner than cyrius's — single tier table, not the multi-tier breakdown.

This is a **ledger**, not a one-time audit. Rewrite-in-place as docs change.

---

## At a glance — 2026-05-17 inventory

**17 docs total** (15 markdown + 1 annotated `.cyml.example` + this ledger).

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh / touched in current cycle** | 13 | Touched during the v0.2.0–v0.3.0 work (2026-05-17). Includes everything in `docs/development/`, `docs/architecture/`, three of four ADRs, both examples, this ledger, and all three root docs (README, CHANGELOG, VERSION lockstep). |
| 🟡 **Stale — refresh in place** | 1 | `docs/guides/getting-started.md` — references the pre-M1 config schema (`[prompt] order =` instead of `[[prompt]] segments =`), mentions `--config` / `--debug` flags that aren't implemented, says "M0 scaffold — not yet usable" which is two releases out of date, and lists `git` as a segment instead of `vcs`. Refresh queued. |
| 🔵 **Probably evergreen** | 3 | CLAUDE.md (delegates volatile state to state.md per its own rule — refresh only when process/rules change); `docs/adr/0001-separate-repo-from-agnoshi.md` (Accepted, scaffold-era, decision stands); `docs/adr/template.md` (template). |
| 📦 **Archive — frozen by design** | 0 | No archived docs yet; this section exists for when 0.x → 1.0 retrospective docs land. |

---

## Inventory

| File | Last touched | Status | Action |
|---|---|---|---|
| `README.md` | 2026-05-17 | ✅ Fresh | Rewritten at v0.3.0 prep — segment table, accurate src/ layout, removed phantom CONTRIBUTING/SECURITY/CODE_OF_CONDUCT refs, dropped non-existent `--config`/`--debug` flags. |
| `CHANGELOG.md` | 2026-05-17 | ✅ Fresh | **Source of truth per CLAUDE.md.** Through v0.3.0 (vcs segment via sit). Reconciled split between [0.1.0] / [0.2.0] / [0.3.0] sections this cycle. |
| `CLAUDE.md` | 2026-05-15 | 🔵 Evergreen | Preferences + process + procedures + project identity. Volatile state (version, cyrius pin, binary size) delegated to `state.md` per its own principle, so version drift doesn't propagate here. Refresh when rules or process change. |
| `VERSION` | 2026-05-17 | ✅ Fresh | Single source of truth for version (`0.3.0`). `cyrius.cyml` reads via `${file:VERSION}`; `release.yml` gates `cat VERSION == $GITHUB_REF_NAME`. |
| `docs/development/state.md` | 2026-05-17 | ✅ Fresh | **Rotates every release.** Through v0.3.0 — source modules table, benchmarks, upstream-filing pointers, in-flight work. |
| `docs/development/roadmap.md` | 2026-05-17 | ✅ Fresh | **Rotates every release.** Trimmed at v0.3.0 prep — M0/M1/M2 (shipped) removed; opens at M3. Per-segment timeout (carried over from M2) lives in M3 now; cwd length-trunc + bench-history-CSV carried into M5/M6. |
| `docs/architecture/README.md` | 2026-05-17 | ✅ Fresh | Index. Updated when a new numbered entry lands. |
| `docs/architecture/001-prompt-render-budget.md` | 2026-05-17 | ✅ Fresh | The 5 ms budget, 500 µs per-segment slice, overrun behavior. Loaded by ADR 0002, 0004, and bench acceptance gates. |
| `docs/adr/README.md` | 2026-05-17 | ✅ Fresh | ADR index — 4 entries (0001–0004). |
| `docs/adr/0001-separate-repo-from-agnoshi.md` | 2026-05-15 | 🔵 Evergreen | Status: Accepted. Scaffold-era decision; stands. |
| `docs/adr/0002-segment-rendering-model.md` | 2026-05-17 | ✅ Fresh | New at v0.2.0 prep. Status: Accepted. |
| `docs/adr/0003-config-format.md` | 2026-05-17 | ✅ Fresh | New at v0.2.0 prep. Status: Accepted. |
| `docs/adr/0004-vcs-probe-via-sit.md` | 2026-05-17 | ✅ Fresh | New at v0.3.0 prep. Status: Accepted. |
| `docs/adr/template.md` | 2026-05-15 | 🔵 Evergreen | Template for new ADRs. Refresh only if the ADR shape itself changes. |
| `docs/guides/getting-started.md` | 2026-05-15 | 🟡 **Stale** | Lists "M0 scaffold — not yet usable", references pre-M1 config schema (`[prompt] order = [...]`), mentions `cmdrs --config` / `cmdrs --debug` flags that aren't implemented, segments section names `git` instead of `vcs`. Refresh queued — should mirror `README.md` + `prompt-tour.md` content. |
| `docs/examples/commandress.cyml.example` | 2026-05-17 | ✅ Fresh | Annotated config with every knob (cwd/exit/vcs sections) + body-zone notes. Refreshed when schema gains a field. |
| `docs/examples/prompt-tour.md` | 2026-05-17 | ✅ Fresh | New at v0.3.0 prep. Output gallery + bash/zsh integration recipes. |
| `docs/doc-health.md` | 2026-05-17 | ✅ Fresh | This ledger. Self-referenced — every doc touch should update its row here. |

---

## Sweep notes

**2026-05-17 (v0.3.0 prep)** — first doc-health pass. Ten files touched fresh during the v0.2.0–v0.3.0 work; one stale flagged (`getting-started.md` — three-release lag). Three docs identified as evergreen (CLAUDE.md, ADR 0001, ADR template). No archived docs yet.

The previous v0.1.0-tagged set lived under `[Unreleased]` in CHANGELOG before being reconciled at v0.3.0 prep into clean per-release sections — that reconciliation is the only retroactive doc change this cycle.

## Refresh policy

- **Touch a doc, update its row.** This file is part of the doc-change unit, not a separate audit pass.
- **At every release tag**: check that `state.md`, `roadmap.md`, `CHANGELOG.md`, `VERSION`, and `README.md`'s status line are all aligned. They form a tight quintet; drift between them is the canonical "release prep" check.
- **At every minor closeout** (M1→M2 → M3 → …): sweep evergreen rows and confirm they still are.
- **Programmatic gates** — none yet. Cyrius runs `_doc_size_currency_gate()` for cc5-size claims; commandress's analog (binary size in `state.md` benchmarks table) is small enough to refresh by hand. Revisit if state.md grows past ~50 numbers worth tracking.
