# 0001 — Prompt rendering lives in its own repo, not inside agnoshi

**Status**: Accepted
**Date**: 2026-05-15

## Context

AGNOS needs a structured shell prompt. The natural starting question: should the prompt renderer live *inside* [agnoshi](https://github.com/MacCracken/agnoshi) (the shell), or as a separate binary that agnoshi invokes per redraw?

Two reference points:

- **starship** ships as a separate static binary that bash/zsh/fish/etc. shell out to. The shell owns the input loop; starship owns the visual prompt. The split has held across years and many shell integrations.
- **bash's `PS1`** is in-shell. Result: every prompt enhancement is a shell feature, every prompt bug is a shell bug, and the prompt's design surface is locked to the shell's release cadence.

AGNOS's posture is monolithic-by-design at the *subsystem* boundary, not the *binary* boundary (see `project_monolithic_by_design` in the genesis repo's memory). Subsystems are separately-releasable repos; coupling happens at the ABI/contract level, not the codebase level.

## Decision

**`commandress` is a separate repo + separate binary (`cmdrs`).** agnoshi invokes `cmdrs` per prompt redraw, captures stdout, paints it. The contract between them is an environment-variable + CLI-flag interface — not a Cyrius API.

In scope for this repo:
- The `cmdrs` binary
- The config schema (`~/.commandress.cyml`)
- Segment implementations (cwd, git, time, exit, language env, etc.)
- ANSI rendering + theme support

Out of scope (lives elsewhere):
- Shell input loop, history, completion, execution (agnoshi)
- Prompt-hook plumbing (an agnoshi-side feature; bash/zsh adapters are first-party scripts shipped here but executed by their host shells)

## Consequences

- **Positive**
  - Prompt design changes don't need an agnoshi release. Iteration speed on the visual surface is uncoupled from shell stability concerns.
  - `cmdrs` can serve bash/zsh/fish as a side effect — multi-shell support comes nearly free.
  - agnoshi stays focused on shell concerns; doesn't carry git probing, time formatting, ANSI palettes, segment ordering, etc.
  - One binary, one CHANGELOG, one CI lane per concern — easier to reason about each.
- **Negative**
  - One subprocess exec per prompt redraw. On modern hardware this is sub-millisecond, but it IS a cost that an in-shell prompt doesn't pay. Cold-start budget is now a feature (≤ 5 ms on Cyrius-current hardware — enforced via CI gate per the v1.0 roadmap).
  - Context flow is via env vars + CLI flags — text serialization with all the foot-guns that brings. Validation discipline is non-negotiable (see Rules in CLAUDE.md).
  - Two repos to keep in sync at agnoshi integration boundaries.
- **Neutral**
  - Forces a stable contract between shell and prompt. That contract IS the integration surface — designed, documented, ADR'd.

## Alternatives considered

- **In-shell prompt (built into agnoshi)** — fastest possible redraw, but couples every prompt change to a shell release and makes the prompt agnoshi-only forever. Rejected.
- **Library, not binary (linked into agnoshi)** — eliminates the exec but reintroduces the coupling. The Cyrius-side dep would mean every commandress version bump triggers an agnoshi rebuild. Rejected.
- **In-tree subdir of agnoshi (`agnoshi/cmdrs/`)** — separate code, same release boundary. Half-measure that gets the worst of both. Rejected.

## References

- [starship](https://starship.rs/) — convergent design (independent binary, shell-agnostic)
- `project_monolithic_by_design` memory in the genesis repo — subsystem-boundary monolithism
- agnoshi repo (the consumer)
