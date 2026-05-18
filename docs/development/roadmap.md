# commandress — Roadmap

> Milestone plan from the **current cycle** through v1.0. State lives in
> [`state.md`](state.md); this file is the sequencing — what ships, in
> what order, against what dependency gates. Shipped milestones move to
> [`../../CHANGELOG.md`](../../CHANGELOG.md) at release time; only the
> next-up + future work lives here.

## v1.0 criteria

- [ ] Stable config schema — every field documented; breaking changes only via deprecation
- [ ] Core segment set: `cwd`, `exit_code`, `time`, `vcs` (sit-backed), `language_env` (one of pyenv/nvm/rustup-equivalent), `hostname`, `user`
- [ ] Full-prompt render under **5 ms** cold start on Cyrius-current hardware (CI gate)
- [ ] Per-segment time budget enforced — slow segments degrade to empty, not stall
- [ ] At least one downstream consumer green ([agnoshi](https://github.com/MacCracken/agnoshi))
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] Security audit pass (`docs/audit/YYYY-MM-DD-audit.md`) — config parsing, env-var handling, subprocess exec (sit probe)
- [ ] Benchmarks captured in `docs/benchmarks.md` — cold start, per-segment render, end-to-end

## Milestones

### M3 — Time + hostname + user (v0.4.0)

- [ ] `src/segments/time.cyr` — configurable strftime-style format
- [ ] `src/segments/hostname.cyr` — `gethostname` syscall
- [ ] `src/segments/user.cyr` — `getuid` + passwd-lookup (or fall back to `$USER`)
- [ ] **Per-segment timeout enforcement** — carried over from M2. Watchdog around any segment that shells out (vcs today, language-env in M4). Implementation: fork + pipe + `poll`/`select` with timeout, kill child on overrun, render empty. Lives in `src/render.cyr` so every segment inherits the same gate.

### M4 — Language env segments (v0.5.0)

- [ ] `src/segments/python_env.cyr` — `$VIRTUAL_ENV` parse, version probe
- [ ] `src/segments/node_env.cyr` — `.nvmrc` / `package.json` parse
- [ ] `src/segments/rustup_env.cyr` — `rustup show` (or AGNOS-native equivalent)
- [ ] One ADR capturing the per-env-probe pattern (so additions follow precedent)

### M5 — Theming + visuals (v0.6.0)

- [ ] ANSI color palette in config
- [ ] Segment separator (powerline-style optional)
- [ ] Right-prompt support (if shell exposes it)
- [ ] `docs/themes/` with examples
- [ ] cwd length-truncation (deferred from M1)

### M6 — Performance hardening (v0.7.0)

- [ ] Parallel segment evaluation (where safe)
- [ ] Cached probe results across rapid redraws (1s TTL on vcs state, etc.) — the change that makes `vcs` cheap enough for default-on
- [ ] Default segments flip from `["cwd", "exit"]` to `["cwd", "vcs", "exit"]` once caching lands
- [ ] Cold-start ≤ 5 ms gate enforced in CI
- [ ] Benchmark history CSV (deferred from M1)

### M7 — Shell adapters (v0.8.0)

- [ ] agnoshi adapter (drops `AGNOSHI_PROMPT_CMD=cmdrs` into the shell's prompt hook)
- [ ] bash adapter (PROMPT_COMMAND integration)
- [ ] zsh adapter (precmd + PROMPT integration)

### M8 — Public-API + security audit (v0.9.0)

- [ ] Freeze config schema
- [ ] Security audit pass — config parsing, env-var handling, subprocess exec
- [ ] Benchmarks finalized

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
