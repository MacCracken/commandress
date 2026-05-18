# 0004 — VCS probe shells out to `sit`, not external `git`

**Status**: Accepted
**Date**: 2026-05-17

## Context

M2 adds the VCS-context segment — current branch + dirty/clean indicator on the prompt line. Three plausible probe strategies:

1. **Shell out to external `git`** — the universal default in the broader ecosystem (starship, p10k, etc.). Every Linux distro ships it; users have it installed.
2. **Shell out to [`sit`](https://github.com/MacCracken/sit)** — the AGNOS-native VCS, first-party Cyrius binary on the same toolchain cadence.
3. **Reimplement git-state read in-tree** — walk `.git/`, parse refs, hash the working tree against the index, no fork/exec overhead.

Constraints in play:

- **Sovereign-stack default** — commandress commits to zero non-stdlib Cyrius deps (`CLAUDE.md` Key Principles). Adding a hard runtime dep on `git` is the same problem in a different layer: the prompt would silently fail without an external Linux package present. AGNOS systems may not ship `git` at all.
- **Sovereign-stack alignment with `sit`** — `sit` is shipped as part of the first-party set. Other consumers in the ecosystem (agnoshi, kavach, sit's own commit chain) target it. commandress falling back to `git` would be the one notable defection.
- **Single subprocess exec per redraw** — already accepted by the rendering model (ADR 0002) for any segment that needs external state. Both `git` and `sit` pay the same exec cost.
- **Surface coverage** — `sit status` produces both the current branch (`On branch <name>`) and the dirty/clean signal (`nothing to commit, working tree clean` substring) in a single invocation. That's the minimum surface M2 needs.
- **Reimplementing VCS in-tree** is a non-starter for M2 scope — the storage-format coupling alone makes it a separate project, not a 200-LoC segment.

User direction recorded 2026-05-17: "shell out to sit." Settled the choice between (1) and (2).

## Decision

**`src/segments/vcs.cyr` shells out to `sit status` via `lib/process.cyr::exec_capture`.** Parses the captured stdout for branch name + dirty flag; emits `<branch>` (clean) or `<branch><dirty_marker>` (dirty); renders empty when `sit` exits non-zero (not a sit repo / sit not installed / probe errored).

In scope for M2:

- Branch name extraction from `sit status`'s `On branch <name>` line.
- Dirty/clean discrimination via the `nothing to commit, working tree clean` substring.
- Per-segment config under `[[segments.vcs]]` — `show_dirty: bool`, `dirty_marker: string`.
- Registry entry — `vcs → _dispatch_vcs` in `src/render.cyr`.
- Graceful empty render on non-zero exit (covers: not-a-repo, sit-not-installed, sit-errored).

Out of scope (deferred):

- **Per-segment timeout enforcement** — landing in v0.4.0 (or M6's perf hardening). Implementation needs a non-blocking pipe + `poll`/`select` watchdog; ~100 LoC of fork+pipe+poll+kill discipline that deserves its own slot. `sit status` is fast enough on healthy repos that v0.3.0 ships without a runtime watchdog. Noted as a known gap in `state.md`.
- **Ahead/behind counts.** `sit status` doesn't surface remote-tracking divergence today; would need a second probe. Layered as v0.4.x.
- **Detached-HEAD / tag/commit-hash display.** When `sit status` reports something other than `On branch <name>` (e.g. a checkout of a tag or raw commit), the segment renders empty rather than misparse. Improvement track.
- **External `git` fallback.** Not provided. Users wanting `git` can re-derive their own segment locally; the first-party default is `sit`. If demand surfaces from a real consumer, file an issue.

## Consequences

- **Positive**
  - First-party stack stays self-contained — no `git` install dependency on AGNOS hosts.
  - `sit` evolves alongside Cyrius/AGNOS — schema breakages are caught at the same release cadence; we don't track GNU `git`'s plumbing/porcelain churn.
  - `sit status` produces both signals (branch + dirty) in one fork+exec — minimum process overhead for the M2 surface.
  - Parser surface is small (one substring scan + one line-prefix strip). Easy to unit-test the parser separately from the integration.
- **Negative**
  - On a host without `sit` installed, the segment renders empty. Same failure mode as a missing `git`, but where `git` is universal, `sit` is AGNOS-specific. Pre-AGNOS consumers (Linux users wanting to try commandress on a stock distro) get nothing here. Mitigation: clear "vcs segment requires sit" note in the example config + README.
  - When `sit`'s output format changes, our parser needs an update. The same is true of `git --porcelain` — both contracts are stable but only by convention. Mitigation: pin to specific `sit status` output prefix substrings (`On branch `, `nothing to commit`); fail closed (empty render) on parse mismatch.
  - One fork+exec per redraw is real cost — typically 1–3 ms wall-clock. Inside the 5 ms cold-start budget but not free. M6 (cache + parallel segment evaluation) eats this.
- **Neutral**
  - Schema convention adopted: segment file is `src/segments/vcs.cyr` (not `git.cyr` or `sit.cyr`). A future fossil/jj/etc. probe can land alongside without a rename; the file name describes the *role*, the implementation chooses the back-end. (As of v0.3.0, the back-end is sit-only.)

## Alternatives considered

- **External `git`** — already covered above. Sovereign-stack alignment is the explicit user direction.
- **Reimplement VCS-state read in-tree** — `.sit/` (or `.git/`) walk + ref parse + index/working-tree hash compare. Removes the fork+exec but bakes the storage format into commandress; every sit/git version that touches the on-disk layout becomes our problem. Order-of-magnitude more code than the shell-out path. Rejected.
- **Library-link `sit` as a Cyrius dep** — would skip fork+exec entirely. Currently `sit` doesn't ship a library surface. Could be revisited if `sit` ever grows one.

## References

- [sit](https://github.com/MacCracken/sit) — AGNOS-native VCS, first-party Cyrius binary.
- [`docs/development/roadmap.md`](../development/roadmap.md) M2 — the milestone this decision unblocks.
- [`docs/architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md) — the budget the probe lives inside.
- starship `[git_status]`, p10k `gitstatus` — the convergent designs in the broader ecosystem.
