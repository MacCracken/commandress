# commandress — Roadmap

> Milestone plan from the **current cycle** through v1.0. State lives in
> [`state.md`](state.md); this file is the sequencing — what ships, in
> what order, against what dependency gates. Shipped milestones move to
> [`../../CHANGELOG.md`](../../CHANGELOG.md) at release time; only the
> next-up + future work lives here.

## v1.0 criteria

- [x] Stable config schema — every field documented; breaking changes only via deprecation. **Shipped 0.9.0** ([ADR 0007](../adr/0007-schema-freeze.md)).
- [x] Core segment set: `cwd`, `exit_code`, `time`, `vcs` (sit-backed), `language_env` (`cyrius_env` / `python_env` / `node_env` / `rustup_env`), `hostname`, `user`. **Shipped 0.5.0**.
- [x] Full-prompt render under **5 ms** cold start on Cyrius-current hardware (CI gate). **Shipped 0.7.0** — current measurement 9 µs (0.2 % of budget); CI gate via `scripts/bench-gate.sh`.
- [x] Per-segment time budget enforced — slow segments degrade to empty, not stall. **Shipped 0.4.0** (`src/shellout.cyr` watchdog).
- [x] At least one downstream consumer green — **zsh + bash adapters shipped 0.8.0** under `adapters/`. agnoshi adoption pending; contract spec locked in `adapters/agnoshi.sh` header.
- [x] CHANGELOG complete from v0.1.0 onward.
- [x] Security audit pass — **shipped 0.9.0** ([`docs/audit/2026-05-18-audit.md`](../audit/2026-05-18-audit.md)).
- [x] Benchmarks captured in `docs/benchmarks.md` — **shipped 0.9.0**.

All criteria satisfied. M9 ships the v1.0 tag.

## Milestones

### M9 — v1.0 freeze

- [ ] All v1.0 criteria above check off
- [ ] CHANGELOG complete
- [ ] Tag `1.0.0`

## Out of scope (for v1.0)

- Windows / non-Linux support — AGNOS is Linux-derived; cross-platform comes later if ever
- GUI / TUI configuration editor — config file editing is fine
- Plugin system / dynamic segment loading — adds complexity, breaks the static-binary story; segments are first-party
- Right-prompt animation, blink, etc. — render is one-shot, not stateful
- Multi-line prompts as a default — supported via config if a user wants it, not the default
- External `git` fallback for the vcs segment — `sit` is the AGNOS-native VCS and the only supported backend (per ADR 0004)
