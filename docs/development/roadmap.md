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

### M1 — Minimum viable prompt (v0.2.0) — ✅ feature-complete on `main`, awaiting tag

Three segments + config loader + render pipeline.

- [x] **ADR 0002**: rendering model — segment pipeline is pure-function-of-context, no shared state.
- [x] **ADR 0003**: config format — CYML wins over TOML (sovereign-stack consistency + markdown body for user notes).
- [x] **Architecture note 001**: prompt render budget — 5 ms total, 500 µs per-segment default, slow segments degrade to empty.
- [x] `src/config.cyr` — CYML loader for `~/.commandress.cyml`. Defaults baked in; missing file → defaults; unknown fields warn to stderr (per-section allow-list).
- [x] `src/segments/cwd.cyr` — getcwd + optional `$HOME → ~` strict-prefix shortening. (Length-truncation deferred to M5 with the rest of theming.)
- [x] `src/segments/exit.cyr` — `[N]` non-zero, empty on 0 by default; `hide_zero = false` paints `[0]` too.
- [x] `src/render.cyr` — table-driven registry, `fncall2` dispatch, joins with `cfg.separator`, paints `cfg.trailer`. (ANSI/color comes at M5.)
- [x] `src/context.cyr` — per-invocation Context struct (HOME + last_exit). Earned its own file once render became table-driven.
- [x] `src/main.cyr` — `getenv` → `config_load` → `context_new` → `render_prompt`.
- [x] Tests: cwd + exit + config_default + config_load (missing/null/full-override/partial-override). 36 assertions green.
- [x] Benchmark: per-segment + full-prompt timings (CSV history deferred to M6).

**Acceptance hit**: `AGNOSHI_LAST_EXIT=0 cd /tmp && cmdrs` prints `/tmp $ `. With `AGNOSHI_LAST_EXIT=42` prints `/tmp [42] $ `. With a `~/.commandress.cyml` overriding segment order/separator/trailer the prompt picks up the changes per redraw.

### M2 — VCS context (v0.3.0)

- [ ] **ADR 0004**: VCS probe strategy — shell out to [`sit`](https://github.com/MacCracken/sit) (AGNOS-native VCS), **not** external `git`. Sovereign-stack alignment — commandress already commits to zero non-stdlib deps, and adding a hard dep on `git` would re-introduce one in spirit. `sit` is a first-party Cyrius binary, on the same toolchain/version cadence, and exposes the plumbing we need (branch, status, log). Capture the trade vs reimplementing VCS-state read in-tree (rejected: more code, every storage-format bump becomes our problem).
- [ ] `src/segments/vcs.cyr` (filename hedges so a future fossil/jj/etc. probe can land alongside without renaming) — branch name, dirty/clean state, ahead/behind counts. Probe via `exec_vec("sit", ...)` with explicit argv (no shell, no command injection surface).
- [ ] Per-segment timeout enforcement — kill the `sit` probe at the per-segment budget and render empty (per [`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)).
- [ ] Graceful fallback when no `sit` repo is detected (`sit status` non-zero exit / no `.sit/` walked-up) — render empty, not noisy.

**Acceptance**: prompt shows current `sit` branch + dirty indicator inside a `sit` repo, blank elsewhere. Probe stays under the per-segment 500 µs budget on a small repo; larger repos respect the watchdog.

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
