# commandress — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

## v1.0 criteria

- [ ] Stable config schema — every field documented; breaking changes only via deprecation
- [ ] Core segment set: `cwd`, `exit_code`, `time`, `git_branch`, `git_status`, `language_env` (one of pyenv/nvm/rustup-equivalent), `hostname`, `user`
- [ ] Full-prompt render under **5 ms** cold start on Cyrius-current hardware (CI gate)
- [ ] Per-segment time budget enforced — slow segments degrade to empty, not stall
- [ ] At least one downstream consumer green ([agnoshi](https://github.com/MacCracken/agnoshi))
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] Security audit pass (`docs/audit/YYYY-MM-DD-audit.md`) — config parsing, env-var handling, subprocess exec (git probe)
- [ ] Benchmarks captured in `docs/benchmarks.md` — cold start, per-segment render, end-to-end

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-05-15

- `cyrius init commandress` scaffold landed
- Doc-tree per [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)
- ADR / architecture / guides / examples folders ready
- Binary output renamed `commandress` → `cmdrs` in `cyrius.cyml`

### M1 — Minimum viable prompt (v0.2.0)

The first build that produces a usable prompt for agnoshi. Three segments + config loader + render pipeline.

- [ ] **ADR 0001**: rendering model (segment pipeline shape — pure-function-of-context, no shared state)
- [ ] **ADR 0002**: config format — CYML (Cyrius-native) vs TOML (broader convention). Capture the trade
- [ ] **Architecture note 001**: prompt render budget — total budget, per-segment slice, what happens on overrun
- [ ] `src/config.cyr` — CYML loader for `~/.commandress.cyml`. Validate every field. Fallback to baked-in defaults if file missing.
- [ ] `src/segments/cwd.cyr` — render current working directory, optionally home-shortened (`~/foo`) and length-truncated
- [ ] `src/segments/exit.cyr` — last-exit-code segment (reads `$AGNOSHI_LAST_EXIT` or arg)
- [ ] `src/render.cyr` — compose segments left-to-right with separator, emit ANSI
- [ ] `src/main.cyr` — wire config → segments → render → stdout
- [ ] Tests: one happy path + one error path per segment
- [ ] Benchmark: full-prompt render time, captured in CSV history

**Acceptance**: `AGNOSHI_LAST_EXIT=0 cd /tmp && cmdrs` prints a recognizable prompt with cwd + exit segments.

### M2 — Git context (v0.3.0)

- [ ] **ADR 0003**: git probe strategy — shell out to `git` vs reimplement git-state read. Trade-off: dep on git binary vs additional Cyrius surface. Recommendation: shell out via `exec_vec()` for MVP.
- [ ] `src/segments/git.cyr` — branch name, dirty/clean state, ahead/behind counts
- [ ] Per-segment timeout enforcement (kill the git probe at budget, render empty)

**Acceptance**: prompt shows current git branch + dirty indicator on a repo, blank elsewhere.

### M3 — Time + hostname + user (v0.4.0)

- [ ] `src/segments/time.cyr` — configurable strftime-style format
- [ ] `src/segments/hostname.cyr` — `gethostname` syscall
- [ ] `src/segments/user.cyr` — `getuid` + passwd-lookup (or fall back to `$USER`)
- [ ] Config field for segment order (declarative array in CYML)

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

### M6 — Performance hardening (v0.7.0)

- [ ] Parallel segment evaluation (where safe)
- [ ] Cached probe results across rapid redraws (1s TTL on git state, etc.)
- [ ] Cold-start ≤ 5 ms gate enforced in CI

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
