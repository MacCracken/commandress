# commandress — Roadmap

> **Post-v1 sequencing.** State lives in [`state.md`](state.md); this file is the
> *order* — what ships in which release, against what gate. Shipped work moves to
> [`../../CHANGELOG.md`](../../CHANGELOG.md); only next-up and future work lives here.
>
> Every item below is **pinned work**: it exists because something in the codebase,
> an audit, or an ADR defers it. Each carries a **source** link back to the line that
> defers it, so the roadmap and the code cannot drift apart. If you add a `TODO`,
> `deferred`, or `follow-up` to the source, add it here too — that is the contract.
>
> Version slots are **planned sequencing, not commitments**. Items move between slots
> as priorities change; what does not move is the pinned list itself.

## Status

**v1.0 shipped 2026-05-18.** All v1.0 criteria are met and archived at the bottom of
this file. Current release is **1.6.0**. The 1.1.x line was toolchain refreshes, the cmdit
CLI adoption, a security audit, and the bayan parser swap. The 1.2.x line was toolchain and
dependency refreshes, the quick roadmap items, and the
[2026-11-06 audit](../audit/2026-11-06-audit.md). The 1.3.x line completed the colour model reserved
at the freeze, the 1.4.x line finished the language-env segments, and the 1.5.x line closed the audit's symlink and length gaps, made the clock local, and took cmdit's fixes for D-05 and D-06. The 1.6.x line makes the cwd-based segments work on agnos. The public API is frozen
per [ADR 0007](../adr/0007-schema-freeze.md): everything below is either **additive** on a
not-frozen surface, or routed through the documented 3-step deprecation path. No item here
breaks a v1 config.

| Slot | Theme |
|---|---|
| **1.x.x** | Unscheduled: gated on something outside this repo |

---

## 1.x.x — Unscheduled: gated on something outside this repo

These are **not** in a numbered slot because commandress cannot schedule them. Each is listed with
what would unblock it, so the gate is checkable rather than folkloric.

| Item | Real gate | Checked |
|---|---|---|
| **agnoshi adoption** — flips on when agnoshi reads `$AGNOSHI_PROMPT_CMD` per redraw. The 5-point contract is specified in `adapters/agnoshi.sh`. The one commandress change it needed shipped in 1.6.0: on agnos, `cmdrs_getcwd` asks the kernel's `getcwd`#113 (agnos 1.57.18) and falls back to the normalized `$PWD` agnsh exports, and the pin readers keep ADR 0015's name rule there by walking the link chain with `readlink` ([ADR 0017](../adr/0017-agnos-working-directory.md)). Booted on kernel 1.57.19 under agnsh 2.2.0. Nothing is left to do here. | agnoshi implements the contract | Re-checked 2026-11-10: `agnoshi/src` does not read it yet (2.2.0 is the newest tag). `adapters/agnoshi.sh:16` — *"agnoshi has not yet adopted it"* |
| **Retire `find_in_path`** — the half of `src/pathlookup.cyr` that re-implements `execvp`'s PATH walk, because `execve(2)` does not do PATH lookup and no stdlib helper exposes one. | cyrius ships `path_which` ([proposal](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-11-06-path-which.md)) | Re-checked 2026-11-10: 6.7.18 is still the newest cyrius, and the proposal is unchanged, so **still open**, no public stdlib fn resolves a bare name against `$PATH`. The workaround ships and is correct, with one known gap: `access(X_OK)` passes a directory, so a directory named `node` in a `PATH` entry ahead of the real tool hides it and the segment renders empty. A repo cannot reach this, because relative `PATH` entries are skipped. |
| **`cyrius deps --locked` fails on a stale pin** — it prints a `note:` saying fail-closed, and exits 0. `scripts/lock-check.sh` does not need this, but it would make `--locked` usable alone. | Upstream cyrius | [Architecture 003](../architecture/003-cyrius-lock-shape.md) § 3 |

> **Check the gate before repeating it.** Two of the three "blocked on Cyrius" claims in
> this repo were stale by the time anyone re-read them — Item 3 had shipped, and the
> `[[X]]` config workaround it justified had become unnecessary without anyone noticing.
> Item 8 was re-verified and genuinely still holds. Re-test the gate at each toolchain
> refresh rather than carrying the claim forward.

---

## Explicitly not planned

Unchanged from v1.0, restated so nobody re-proposes them:

- **Windows / non-Linux support** — AGNOS is Linux-derived. agnos is a build target; other OSes are not.
- **GUI / TUI config editor** — editing a config file is fine.
- **Plugin system / dynamic segment loading** — breaks the static-binary story; segments are first-party.
- **Right-prompt animation, blink, stateful render** — the render is one-shot by design.
- **Multi-line prompts as the default** — configurable if a user wants it; not the default.
- **External `git` fallback for `vcs`** — `sit` is the AGNOS-native VCS and the only backend ([ADR 0004](../adr/0004-vcs-probe-via-sit.md)).
- **Changing the canonical `[[X]]` config spelling to `[X]`** — single-bracket now *works* and is documented as accepted, but `[[X]]` stays canonical: every shipped theme and example uses it, and a churn of every user's config buys nothing.

---

## Archived — v1.0 criteria (all met, shipped 2026-05-18)

- [x] Stable config schema, breaking changes only via deprecation — **0.9.0** ([ADR 0007](../adr/0007-schema-freeze.md))
- [x] Core segment set (`cwd`, `exit`, `time`, `vcs`, the four language envs, `hostname`, `user`) — **0.5.0**
- [x] Full-prompt render under 5 ms cold start, CI-gated — **0.7.0**
- [x] Per-segment time budget; slow segments degrade to empty — **0.4.0** (`src/shellout.cyr`)
- [x] At least one downstream consumer green — zsh + bash adapters, **0.8.0**
- [x] CHANGELOG complete from v0.1.0
- [x] Security audit pass — **0.9.0** ([2026-05-18](../audit/2026-05-18-audit.md)); second pass **1.1.6** ([2026-08-26](../audit/2026-08-26-audit.md))
- [x] Benchmarks captured — **0.9.0** ([`benchmarks.md`](../benchmarks.md))
