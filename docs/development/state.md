# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.6.0** — tagged release 2026-05-18. M5 partially closed: ANSI colour palette + per-segment `fg`/`bg`/`style` + opinionated default theme + cwd `max_length` truncation + optional `[[palette]]` reference layer (sets up the v1 theme-switching path). Three M5 deliverables remain — powerline-style separators, right-prompt support, `docs/themes/` curated examples — deferred to v0.6.x bites; contracts are stable enough that they land additively. Next: complete M5, then **M6 — performance hardening** (parallel segment evaluation, 1 s TTL probe cache, default-segment flip to include `vcs`, ≤ 5 ms cold-start CI gate, benchmark history CSV).

## Role

Structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Binary name: `cmdrs`. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius.

## Toolchain

- **Cyrius pin**: `5.11.63` (in `cyrius.cyml [package].cyrius`)

## Source

| Module | Status |
|---|---|
| `src/main.cyr` | M1 — loads config, builds Context, dispatches to `render_prompt(cfg, ctx)` |
| `src/config.cyr` | **M1 + M3 (0.4.0) + M5 (0.6.0)** — CYML loader for `~/.commandress.cyml`. Schema: `[[prompt]]` (segments, separator, trailer) + `[[segments.cwd]]` (home_shorten, max_length, fg/bg/style) + `[[segments.exit]]` (hide_zero, fg/bg/style) + `[[segments.vcs]]` (show_dirty, dirty_marker, fg/bg/style) + `[[segments.time]]` (format, fg/bg/style) + `[[segments.{hostname,user,cyrius_env,python_env,node_env,rustup_env}]]` (fg/bg/style only) + optional `[[palette]]` (named-slot table referenced via `fg = "palette:<name>"`). Defaults baked in (including opinionated default theme); partial-override-safe (boolean-only override keeps default theme); missing file → defaults; unknown fields warn to stderr |
| `src/context.cyr` | **M1 (0.2.0)** — `{ home, last_exit }` per-invocation context handed to every segment dispatcher |
| `src/render.cyr` | **M1 + M3 (0.4.0) + M4 (0.5.0) + M5 (0.6.0)** — table-driven registry (name → dispatcher fn ptr); paints `cfg.segments` joined by `cfg.separator`, `cfg.trailer` always. Dispatchers wired for `cwd`, `exit`, `vcs`, `time`, `hostname`, `user`, `cyrius_env`, `python_env`, `node_env`, `rustup_env`. Each painted segment is wrapped with its pre-computed SGR opening string + `\x1b[0m` reset when styled; emits raw bytes when the SGR slot is 0. `_sgr_for(cfg, name)` mirrors `_seg_fn_for` for SGR-by-name resolution. Unknown segments warn to stderr |
| `src/shellout.cyr` | **M3 (0.4.0)** — generic per-call timeout watchdog. `shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen)` returns bytes / `-1` (system error) / `-2` (timeout). Implements fork + pipe + `epoll_wait(timeout)` + `kill(SIGKILL)` on overrun + `waitpid` reap. See [`architecture/002-shellout-watchdog.md`](../architecture/002-shellout-watchdog.md) |
| `src/pathlookup.cyr` | **M4 (0.5.0)** — `find_in_path(name)` walks `$PATH`, returns the first heap-alloc'd absolute-path cstring that passes `access(X_OK)` (or 0). Lifted from `src/segments/vcs.cyr` once `cyrius_env` became a second shellout consumer. Still pending Cyrius v6.x Item 8 upstream |
| `src/fslookup.cyr` | **M4 (0.5.0)** — shared fs helpers used by every language-env segment. `find_ancestor_with(start_dir, marker)` walks cwd upward returning the dir containing `<dir><marker>`, or 0. `read_trimmed_file_at(root, suffix)` reads `<root><suffix>` (256-byte cap) and trims surrounding ws (space, tab, `\n`, `\r`). Marker must start with `/` (e.g. `"/cyrius.cyml"`) so the root-case join is correct |
| `src/color.cyr` | **M5 (0.6.0)** — ANSI SGR helpers. `color_to_sgr_fg(name)` / `color_to_sgr_bg(name)` map 16 named colours (8 standard + 8 bright) + `"default"` to SGR ints (30..37 / 90..97 fg; bg = fg + 10; 0 for absent/default/unknown). `style_to_sgr_mods(s, codes, max)` parses space-separated tokens (bold / italic / underline / reverse) writing mod codes as i64s. `sgr_open_for(fg, bg, style)` composes the `"\x1b[<mods>;<fg>;<bg>m"` opener, returns 0 when nothing to emit. `SGR_RESET` is `"\x1b[0m"`. Render closes every styled segment with `SGR_RESET` so terminal-defaults aren't leaked between segments |
| `src/segments/cwd.cyr` | **M1 + M5 (0.6.0)** — `getcwd` + optional `$HOME` → `~` shortening (strict-prefix only) + optional `max_length` truncation at `/` boundaries (`_truncate_cwd` helper: walks left→right for earliest `/` whose suffix fits `max_length - 3`; pathological `< 4` emits a row of `.` dots; no-qualifying-`/` falls back to `...` + raw tail) |
| `src/segments/exit.cyr` | M1 — empty on 0, `[N]` otherwise; `hide_zero = false` paints `[0]` too |
| `src/segments/vcs.cyr` | **M2 (0.3.0) + watchdog (0.4.0) + pathlookup lift (0.5.0)** — shells out to `sit status` via `shellout_capture` with a hardcoded 5 ms budget. Parses `On branch <name>` + scans for `nothing to commit, working tree clean`. Emits `<branch>` (clean) or `<branch><dirty_marker>` (dirty). Renders empty outside a sit repo, when sit isn't on PATH, on watchdog timeout, or on parse failure. PATH lookup now via `src/pathlookup.cyr::find_in_path`. Config-overridable `[[segments.vcs]] budget_ms = N` plumbing is a follow-up slot |
| `src/segments/time.cyr` | **M3 (0.4.0)** — strftime-subset formatter (`%H %M %S %Y %y %m %d %%`; unsupported specs pass through literal). UTC via `CLOCK_REALTIME`; local-time / `TZ` is a future slot. Default format `"%H:%M"`; config-overridable via `[[segments.time]] format = ...` |
| `src/segments/hostname.cyr` | **M3 (0.4.0)** — `uname(2)` nodename. One syscall, no config knobs |
| `src/segments/user.cyr` | **M3 (0.4.0)** — `getuid()` + `lib/pwd.cyr` direct /etc/passwd reader (musl-style; no glibc NSS). Falls back to `$USER`, then empty. No config knobs |
| `src/segments/cyrius_env.cyr` | **M4 (0.5.0)** — Cyrius project segment. Walks ancestors for `cyrius.cyml`, reads `<root>/VERSION`, falls back to `cyrius --version` shellout (5 ms budget). Emits raw version string. Per [ADR 0005](../adr/0005-language-env-probe-pattern.md) |
| `src/segments/python_env.cyr` | **M4 (0.5.0)** — Python project/venv segment. `$VIRTUAL_ENV` basename first, else `.python-version` ancestor walk + read+trim. `python --version` shellout deferred pre-v1. Per ADR 0005 |
| `src/segments/node_env.cyr` | **M4 (0.5.0)** — Node project segment. `.nvmrc` ancestor walk + read+trim. Passes numeric (`20.11.1`) and channel-style (`lts/iron`) content verbatim. `package.json engines.node` + `node --version` shellout deferred. Per ADR 0005 |
| `src/segments/rustup_env.cyr` | **M4 (0.5.0)** — Rust toolchain segment. Plain-format `rust-toolchain` ancestor walk + read+trim. `rust-toolchain.toml` deferred (blocked on Cyrius single-bracket TOML, papercut Item 3); `rustup show` shellout deferred per file-first policy. Per ADR 0005 |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: **188,495 B** on Cyrius 5.11.63, x86_64 (text 133,799 B; bss 54,696 B). Up from 176,088 B at the 0.5.0 baseline by **+12,407 B** for the M5 theming foundation — `src/color.cyr` (~140 LoC), 10 per-segment SGR slots + parsing + the `_apply_seg_style` / `_load_color_only_section` / `_load_palette` / `_palette_lookup` / `_resolve_color_value` helpers, render's `_sgr_for` resolver + SGR wrapping, and cwd `max_length` truncation logic. Text grew +12,279 B; bss +128 B. Net win vs 0.3.0 baseline (395,115 B): **−206,620 B**.

## Benchmarks

Captured 2026-05-18 on the dev host (Linux 7.0.5-arch1-1, x86_64):

| Operation | Avg | Min | Max |
|---|---|---|---|
| `cwd_render` | 664 ns | 620 ns | 786 ns |
| `exit_render(nonzero)` | 38 ns | 35 ns | 50 ns |
| `config_default` | 2 µs | 2 µs | 3 µs |
| `vcs_parse_render` (pure parser) | 229 ns | 222 ns | 258 ns |
| `vcs_render` (fork + `sit status` + parse) | 3.902 ms | 3.730 ms | 4.163 ms |
| `cyrius_env_parse_version` (pure parser) | 73 ns | 69 ns | 93 ns |
| `cyrius_env_render` (file path, no shellout) | 7 µs | 6 µs | 7 µs |
| `python_env_basename` (pure parser) | 95 ns | 90 ns | 121 ns |
| `python_env_render` (empty walk) | 12 µs | 11 µs | 13 µs |
| `node_env_render` (empty walk) | 6 µs | 5 µs | 6 µs |
| `rustup_env_render` (empty walk) | 6 µs | 5 µs | 6 µs |
| `render_prompt (cwd+exit)` | 3 µs | 3 µs | 3 µs |

Budget: 5 ms cold start total ([`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)). M5 deltas: `config_default` 166 ns → 2 µs (10 `sgr_open_for` calls during default-theme bake — one-time per redraw, 0.04 % of budget); `render_prompt (cwd+exit)` 2 µs → 3 µs (~1 µs SGR wrap overhead per painted segment under the default theme). `vcs_render` measured at **3.9 ms** vs 1.8 ms in 0.5.0 — the vcs code path is unchanged in this release, so this is dev-host variance (fork+exec is sensitive to system state); to be re-baselined in 0.6.x. M6 caching closes the vcs cost regardless. The seven file-walk segments combined still sum to ~36 µs — three orders of magnitude under budget.

## Tests

- `tests/commandress.tcyr` — **217 assertions across 95 tests**: existing M1–M4 coverage + M5 additions for `color` (16 cases — named/bright fg + bg = fg + 10 + absent/default/unknown + four style modifiers + multi-mod ordering + unknown-skip + empty/whitespace + sgr_open all-paths including three-digit codes + `SGR_RESET`), `config theme` (6 cases — default-bake-in with exact bytes for cwd + exit + per-segment non-null check, partial-override safety, fg-only-override, full reset, hostname color-only, python_env color-only), `config palette` (5 cases — single-ref, multi-slot, unknown-ref-unstyled, mixed-raw-and-ref, absent-section), and 8 `_truncate_cwd` cases (no-ops, '/' boundary collapse, exact-budget, leaf-only, `< 4` pathological, no-qualifying-`/` fallback, render-path bound). Helper tests are hermetic. `cyrius test` green.
- `tests/commandress.bcyr` — per-segment + config + parser + full-prompt timings (above).
- `tests/commandress.fcyr` — fuzz stub (no harness yet).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert` (and via includes: `cyml`, `toml`, `fnptr`, `bench`).

External: none (and none planned for v1.0).

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

- **M5 partially closed in 0.6.0** (tagged 2026-05-18): `src/color.cyr` (SGR helpers + named-colour table) + 10 per-segment SGR slots in Config + opinionated default theme baked into `config_default` + `[[palette]]` reference layer (`fg = "palette:<name>"`) + cwd `max_length` truncation (M1 carry-over).
- **M5 remaining (deferred to v0.6.x bites)**:
  - **Powerline-style separators** — decorative glyph separators (``) with fg/bg transitions between segments. Bigger surface — needs separator-pair config (glyph + fg/bg per pair) and a render-side block-style layer. The colour foundation is in place; this is an additive change.
  - **Right-prompt support** — shell-specific (zsh `RPROMPT`, no clean bash equivalent). Output-shape design (delimiter on stdout? second invocation? env hint?) still to settle.
  - **`docs/themes/` curated examples** — landing trivially once the contract is exercised by an `[[palettes.<name>]]` multi-palette layer that ships in v0.7.x. For now users copy / paste the schema directly.
- **Deferred behind upstream gaps**:
  - `rust-toolchain.toml` parsing — blocked on Cyrius single-bracket TOML (papercut Item 3, v6.x).
  - `find_in_path` itself — pending Cyrius v6.x Item 8 (no stdlib `which()`); the `src/pathlookup.cyr` workaround ships.
  - LSP transitive-include false positives across `src/render.cyr` — Cyrius Item 4, v6.x. Build is clean; the noise stays.
- **Deferred by policy (file-first, per user direction 2026-05-18)**:
  - `python --version`, `node --version`, `rustup show` shellouts. Parked pre-v1 alongside M6 caching.
  - `package.json` `engines.node` parsing. Same reasoning.
- **Known regression**: `vcs_render` measured at 3.9 ms (vs 1.8 ms in 0.5.0). Code path untouched in this release; suspect dev-host variance. Re-baseline in 0.6.x.
- Next: complete M5, then **M6 — performance hardening** (parallel segment evaluation, 1 s TTL probe cache, default-segment flip to include `vcs`, ≤ 5 ms cold-start CI gate, benchmark history CSV).

## Next

See [`roadmap.md`](roadmap.md).
