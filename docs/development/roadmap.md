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
this file. Current release is **1.2.3**. The 1.1.x line was toolchain refreshes, the cmdit
CLI adoption, a security audit, and the bayan parser swap. The 1.2.x line was toolchain and
dependency refreshes, the quick roadmap items, and the
[2026-11-06 audit](../audit/2026-11-06-audit.md). The public API is frozen
per [ADR 0007](../adr/0007-schema-freeze.md): everything below is either **additive** on a
not-frozen surface, or routed through the documented 3-step deprecation path. No item here
breaks a v1 config.

| Slot | Theme |
|---|---|
| **1.3.x** | Colour and theming completion |
| **1.4.x** | Language-env depth |
| **1.5.x** | Per-segment control |
| **1.x.x** | Unscheduled: gated on something outside this repo |

---

## 1.3.x — Colour and theming completion

The colour model shipped deliberately narrow at 0.6.0 (16 named colours). Every slot below was
reserved at schema freeze, so all of it is additive.

| Release | Item | Source of the deferral |
|---|---|---|
| **1.3.0** | **Hex and 256-colour values** — `fg = "#8be9fd"` / `fg = "33"` alongside the named set. These are the two forms ADR 0007 § 3 reserved; an earlier draft here said `"38;5;117"`, which is not what was frozen. | `src/color.cyr:6` — *"Hex / 256-color / palette references are deferred (v0.6.x+)"* |
| **1.3.0** | **Right-prompt powerline transitions** — on `--side=right` the closing glyph trails the last block, so a left-pointing arrow sits after the text instead of leading it. The shipped powerline theme leaves `right_segments` out until this lands. | `src/render.cyr`, end of `render_prompt` |
| **1.3.1** | **Multi-palette** — `[[palettes.<name>]]` tables plus a top-level `palette = "<name>"` selector. Single-palette `[[palette]]` shipped 0.6.0; the multi form was reserved, not built. | [ADR 0007](../adr/0007-schema-freeze.md) reserved-for-additive; `state.md` post-v1 theme track |

**Gate**: none. All of it is additive config surface plus `src/color.cyr` and `src/render.cyr` work.

---

## 1.4.x — Language-env depth

The language-env segments are file-first by explicit user direction (2026-05-18): read a pin file,
never pay a subprocess. That policy stands. This slot finishes the *file* half and puts the
subprocess half behind opt-in config.

| Release | Item | Source of the deferral |
|---|---|---|
| **1.4.0** | **`package.json` → `engines.node`** — a second `node_env` source when `.nvmrc` is absent. | `src/segments/node_env.cyr:14` |
| **1.4.1** | **Opt-in version shellouts** — `python --version`, `node --version`, `rustup show active-toolchain`, each behind a per-segment config flag, default off. The 1 s TTL cache (`src/cache.cyr`) is what makes them affordable, and vcs `budget_ms` is the pattern for bounding them. | `src/segments/node_env.cyr`, `src/segments/rustup_env.cyr`; `state.md` "deferred by policy" |

**Gate for 1.4.0**: `package.json` needs a JSON parser and is repo-controlled, so it is the
`rust-toolchain.toml` question again with a larger file. Measure `bayan-json`'s size and cold-start
cost first, and apply what the 1.2.3 audit learned about hostile parser input. It earns an ADR.

---

## 1.5.x — Per-segment control

Knobs the config schema was always shaped for but never grew, plus the output-shape gap the
2026-08-26 audit recorded.

| Release | Item | Source of the deferral |
|---|---|---|
| **1.5.0** | **Per-segment output length cap** — a hostile repository can push text into every redraw: 255 bytes from a pin file, 8,182 from a `sit` branch, and an environment can push more through `VIRTUAL_ENV`. Sanitized and inert, but visually disruptive; `max_length` applies to `cwd` only. | [2026-11-06 audit](../audit/2026-11-06-audit.md), *Known gaps* |
| **1.5.0** | **What a pin file may look like** — a probe follows symlinks, so `.python-version -> ~/.ssh/id_ed25519` shows the start of that file in the prompt, and a co-tenant's `/tmp/.python-version` applies under `/tmp`. `O_NOFOLLOW` would blank monorepo pins, so the better fix is a shape rule for a version string, which also cuts the length problem above. | [2026-11-06 audit](../audit/2026-11-06-audit.md) T-05, T-06 |
| **1.5.1** | **Local time and `TZ`** — the `time` segment is UTC-only; `TZ` lookup plus offset application is its own piece of work. | `src/segments/time.cyr:23` |

**Gate**: none. Both are additive per-segment config fields.

---

## 1.x.x — Unscheduled: gated on something outside this repo

These are **not** in a numbered slot because commandress cannot schedule them. Each is listed with
what would unblock it, so the gate is checkable rather than folkloric.

| Item | Real gate | Checked |
|---|---|---|
| **agnoshi adoption** — flips on when agnoshi reads `$AGNOSHI_PROMPT_CMD` per redraw. The 5-point contract is specified in `adapters/agnoshi.sh`. **It needs one commandress change**: agnos has no `getcwd` by design, so `cmdrs_getcwd` must read `$PWD`, which agnsh has passed since 2.2.0. Every cwd-based segment is empty there until then, and the default prompt is bare ` $ `. That change makes repo-controlled files reachable on a target where `read_regular_file` has neither guard, so it needs that reviewed at the same time. | agnoshi implements the contract | Re-checked 2026-11-06: `agnoshi/src` does not read it yet. `adapters/agnoshi.sh:16` — *"agnoshi has not yet adopted it"* |
| **Retire `src/pathlookup.cyr`** — 99 lines re-implementing `execvp`'s PATH walk, because `execve(2)` does not do PATH lookup and no stdlib helper exposes one. | Cyrius grows a `which()`-equivalent (papercut Item 8) | Re-checked 2026-11-06 against the 6.7.18 snapshot: **still open**, no public stdlib fn resolves a bare name against `$PATH`. The workaround ships and is correct. |
| **`--bogus --side=right` honours the side** — cmdit stops at the first bad token, so a flag before `--side=right` renders the left prompt. No adapter produces that order. | cmdit grows a continue-on-error mode | [2026-11-06 audit](../audit/2026-11-06-audit.md) D-05 |
| **cmdit's stderr escaper strips C1** — a C1 pair in a bad flag reaches stderr. Argv is not an attacker position. | cmdit filters `0x80..0x9F` | [2026-11-06 audit](../audit/2026-11-06-audit.md) D-06 |
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
