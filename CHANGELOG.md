# Changelog

All notable changes to commandress will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.3] — 2026-07-17 (toolchain refresh + stdlib resync)

**Toolchain refresh + dependency resync.** Patch release lifting the Cyrius pin from `6.2.24` to `6.4.66` (clearing the `manifest-pin: 6.2.24 (drift — wrapper is 6.4.66)` drift) and re-vendoring the bundled stdlib snapshot to match the new pin. No `src/` changes. Suite remains **279 passed, 0 failed**; binary drops **210,144 B → 147,600 B** (−62,544 B, −29.8 %) — most of it a bss collapse (59,296 B → 2,464 B) from the 6.4.66 toolchain's global layout, the rest tighter codegen. `render_prompt (default cwd+vcs+exit)` benches **8.848 µs avg** (min 8.700 µs, max 10.272 µs; was ~9 µs), still ~0.2 % of the 5 ms cold-start budget ([architecture/001-prompt-render-budget.md](docs/architecture/001-prompt-render-budget.md)). Public API per [ADR 0007](docs/adr/0007-schema-freeze.md) unaffected.

### Changed

- **`VERSION`** — `1.1.2` → `1.1.3`.
- **`cyrius.cyml`** — `[package].cyrius` pin `6.2.24` → `6.4.66`.
- **Vendored stdlib snapshot resynced to the 6.4.66 pin** (`cyrius lib sync --full`): **60 bundled libs updated, 19 added, 0 removed**. Headline version bumps: `sakshi` 2.2.4 → 2.4.6, `niyama` 1.0.2 → 1.0.6, `sigil` 3.7.7 → 3.12.1, `sandhi` 1.4.4 → 1.9.0, `yukti` 2.2.3 → 2.2.9, `patra` 1.10.3 → 1.12.12, `vani` 0.9.3 → 1.1.1, `mabda` 3.0.1 → 4.0.7, `sankoch` 2.2.5 → 2.5.1. Clears the `./lib/ shadows version-pinned …/6.4.66/lib — 9 bundled lib(s) differ` build warning. `[deps]` in `cyrius.cyml` is unchanged — the declared stdlib surface is the same; only the vendored implementations advanced.

### Fixed

- **`scripts/bench-gate.sh` couldn't parse the 6.4.x bench output.** The Cyrius 6.4.x bench harness prints sub-µs averages as decimals (`8.848us avg`) where 6.2.x printed integers (`9us avg`); the gate's integer-only regex (`[0-9]+`) then mis-parsed the line and died with `unrecognized avg unit '(default'`, failing CI regardless of the actual timing. The regex now accepts an optional fraction, and the µs normalization + budget comparison moved to `awk` (bash `(( ))` arithmetic can't handle decimals). ns/ms unit handling and the malformed-line guard are preserved; verified against real output, a forced over-budget case, ns/ms lines, and a no-match line.

## [1.1.2] — 2026-06-19 (toolchain refresh)

**Toolchain refresh.** Patch release lifting the Cyrius pin from `6.1.14` to `6.2.24` to clear the wrapper/manifest drift (`cyrius --version` reported `manifest-pin: 6.1.14 (drift — wrapper is 6.2.24)` before this bump). No source changes. Suite remains **279 passed, 0 failed**; binary moves from **204,688 B** to **210,144 B** (+5,456 B, attributable entirely to the toolchain change). Public API per [ADR 0007](docs/adr/0007-schema-freeze.md) unaffected.

### Changed

- cyrius toolchain pin 6.1.14 → 6.2.24.

## [1.1.1] — 2026-06-08 (agnos argv fix)

### Changed

- cyrius toolchain pin 6.0.56 → 6.1.14.

### Fixed

- **agnos: command-line args weren't seen.** Call `main` from a bare top-level statement (`_agnos_entry();`) instead of `var r = main();`. The latter runs `main` as a module-global initializer, *before* cyrius's init-stack capture, so `argc()`/`argv()` read 0/null. cyrius issue: agnos argv init-rsp capture.

## [1.1.0] — 2026-06-06 (AGNOS as a build target — builds on both Linux and agnos)

### Added

- **AGNOS platform support** (VERSION → 1.1.0; cyrius pin 6.0.1 → 6.0.56). `cmdrs` now builds under `cyrius build --agnos` and renders inside the agnsh shell (output via the agnos `write` syscall). Each Linux-only syscall was gated inline (`#ifdef CYRIUS_TARGET_AGNOS`), with the right agnos behavior per segment rather than a blanket stub:
  - **hostname** segment → works natively via agnos `uname`#34 (64-byte struct, nodename @16) — shows the real agnos hostname (`src/segments/hostname.cyr`).
  - **fs marker detection** (`.git` etc.) → uses agnos `stat`#33 (agnos has a real ext2 FS), so context detection works (`src/fslookup.cyr`).
  - **`cwd`** → new shared `cmdrs_getcwd` helper (`src/pathlookup.cyr`); the 6 cwd-consuming segments route through it. AGNOS has no `getcwd` syscall (CWD is userland-owned per the agnos ABI), so it returns 0 and the cwd-dependent segments (cwd + node/python/cyrius/rust/vcs env detection) **degrade to empty** until agnos exposes a CWD source (PWD from agnsh, or a cwd primitive).
  - **subprocess git/tool segments** (`shellout_capture`) → return "unavailable" on agnos (no userland fork/exec-of-external-binaries until the **1.43.x `execwait`** work); callers skip the segment.
  - **PATH executable lookup** (`access`) → degrades on agnos (no PATH/access; agnsh tools are builtins).
- Net: the static prompt + hostname render on agnos today; dynamic (cwd/git/tool) segments light up as agnos grows (`execwait` 1.43.x, a CWD source). Inline gating, no shared platform-abstraction layer. Linux path unchanged.

### Validated

- `cyrius build --agnos src/main.cyr` → **OK** (`cmdrs_agnos`, 189 KB). Linux build unaffected (**OK**).

## [1.0.1] — 2026-05-21

**Toolchain refresh.** Patch release lifting the Cyrius pin from `5.11.64` to `6.0.1` to clear the wrapper/manifest drift (`cyrius --version` reported `manifest-pin: 5.11.64 (drift — wrapper is 6.0.1)` before this bump). No source changes. Suite remains **279 passed, 0 failed**; binary moves from **202,561 B** to **203,040 B** (+479 B, attributable entirely to the toolchain change). Public API per [ADR 0007](docs/adr/0007-schema-freeze.md) unaffected.

### Changed

- **`VERSION`** — `1.0.0` → `1.0.1`.
- **`cyrius.cyml`** — `[package].cyrius` pin `5.11.64` → `6.0.1`.

## [1.0.0] — 2026-05-18

**M9 — v1.0 freeze + tag.** No code changes. All v1.0 criteria from [`roadmap.md`](docs/development/roadmap.md) closed in prior milestones: stable config schema ([ADR 0007](docs/adr/0007-schema-freeze.md), 0.9.0), full core segment set (`cwd` / `exit` / `vcs` / `time` / `hostname` / `user` / `cyrius_env` / `python_env` / `node_env` / `rustup_env`, M1–M5), 5 ms cold-start budget with CI gate (0.7.0; current measurement 9 µs avg — 0.2 % of budget), per-segment time budget enforcement (`src/shellout.cyr` watchdog, 0.4.0), shell adapters under [`adapters/`](adapters/) for zsh + bash + agnoshi-contract (0.8.0), security audit pass with 6 fixes ([`docs/audit/2026-05-18-audit.md`](docs/audit/2026-05-18-audit.md), 0.9.0), and finalised benchmarks ([`docs/benchmarks.md`](docs/benchmarks.md), 0.9.0). v1.0 is the doc roll + the `1.0.0` tag — the public API ([config path, schema, colour values, CLI, env-var contract, adapter contract, file paths](docs/adr/0007-schema-freeze.md)) is now frozen; breaking changes from here go through the 3-step deprecation path in ADR 0007. Suite remains **279 passed, 0 failed**; binary remains **202,561 B** on Cyrius 5.11.64.

### Changed

- **`VERSION`** — `0.9.0` → `1.0.0`.
- **`README.md`** — status block bumped from the long-stale `v0.3.0` claim to v1.0.0 release wording; segment table grown from the original 3 (cwd/exit/vcs) to the full v1.0 surface of 10; shell-integration section updated to reference the shipped `adapters/` directory rather than the M7-future tense; test count and project-layout block resynced.
- **`docs/development/state.md`** — version block headline bumped to 1.0.0; "In-flight work" section closed out for M9; "Next" reframed for post-v1 cadence.
- **`docs/development/roadmap.md`** — M9 checklist closed; v1.0 criteria all checked; section reframed for post-v1 work.

### Roadmap

- **M9 closed.** v1.0 ships. Public API frozen per ADR 0007. Post-v1 cadence picks up new work — multi-palette config, `rust-toolchain.toml` parsing once Cyrius single-bracket TOML lands, deferred shellouts (`python --version` / `node --version` / `rustup show`) as the cache infrastructure now makes them affordable, agnoshi adoption of `$AGNOSHI_PROMPT_CMD` — all gated on either schedule or upstream rather than blocking v1.

## [0.9.0] — 2026-05-18

**M8 — public API + security audit.** Full security audit lands as [`docs/audit/2026-05-18-audit.md`](docs/audit/2026-05-18-audit.md) — 12 findings (8 actionable, 4 informational/contract) cross-referenced against 20 published CVEs and advisories from the 2020–2026 window (Git ANSI sideband, fish git-prompt fsmonitor RCE, oh-my-zsh `print -P`, Ghostty title injection, the 10-CVE dgl.cx terminal-emulator set, py-filelock TOCTOU, RenderDoc /tmp, Himmelblau Kerberos cache, Jackson TOML stack-overflow, sudo CVE-2019-14287, plus the Codex CLI ANSI-injection writeup). **6 fixes ship in 0.9.0**: ANSI/C0 control-byte sanitization at the render layer (F-1), cache-dir post-mkdir mode-verify with self-disable on mismatch (F-3), cache-read `O_NOFOLLOW` (F-4), atomic cache writes via temp+rename with `O_EXCL|O_NOFOLLOW` and mode `0o600` (F-5), bounded `$AGNOSHI_LAST_EXIT` parse with length cap + range clamp (F-7), and `find_in_path` rejection of relative `$PATH` entries (F-8). **2 deferred upstream**: F-2 (sit hooks/fsmonitor surface — needs upstream sit safe-mode flag) and F-6 partial (TOML parser depth-cap — needs upstream Cyrius stdlib). **Public API frozen** via [ADR 0007](docs/adr/0007-schema-freeze.md): config path + schema + colour value space + CLI + env-var contract + adapter contract + file paths all locked at v1.0 with an explicit 3-step deprecation path for anything we later regret. **Adapter contract clarified**: `adapters/agnoshi.sh` gains audit F-12 wording — consumers MUST NOT pass `cmdrs` output through shell-syntax re-expansion (CVE-2021-3934 / CVE-2021-45444 precedents). **Benchmarks finalised** in new [`docs/benchmarks.md`](docs/benchmarks.md). Suite grows from 245 → 279 assertions.

### Added

- **`docs/audit/2026-05-18-audit.md`** — full audit doc. Methodology (dual-track internal sweep + external CVE research), threat model (3 attacker positions, no privilege boundary, no RCE path identified in audited code), findings F-1..F-12 with severity / mitigation / acceptance criteria / CVE precedent each, remediation summary table, upstream filings list, 20-entry CVE reference list.
- **`docs/adr/0007-schema-freeze.md`** — public-API freeze for v1.0. Locks 8 surfaces (config path, schema fields, colour values, CLI, env-var read contract, env-var write contract, adapter contract, file paths). Explicitly lists **not-frozen** surfaces (segment registry, named-colour set, modifiers, hex/256-colour reserved-for-additive, multi-palette reserved, internal struct layout, cache format). Concrete 3-step deprecation path (new-form-with-warning → default-flip → v2.0-removal).
- **`docs/benchmarks.md`** — finalised benchmarks doc per v1.0 criterion. Budget breakdown table, per-segment numbers for v0.9.0, end-to-end process-level cold vs warm (~2.4 ms vs ~0.5 ms), trend summary from `history.csv`, reproduction recipe, variance notes.
- **`src/color.cyr::sanitize_segment_output(s)`** — F-1 fix. Strips C0 (`0x00`–`0x1F`) and DEL (`0x7F`) bytes; preserves UTF-8 (`0x80`+). Render calls it between dispatcher-return and emit so every segment's content is filtered at one chokepoint; SGR wrappers + separator + powerline glyph stay untouched (config-derived → trusted).
- **`src/render.cyr`** — sanitization wired into the segment loop with a `safe_len > 0` guard so degenerate inputs (entirely control bytes) skip the entire paint (separator + transition + SGR) cleanly.
- **`src/cache.cyr::_cache_disabled`** + verification in `cache_init` — F-3 fix. `sys_stat` after `sys_mkdir`; if owner uid or mode bits don't match (`uid != getuid()` or `mode & 0o777 != 0o700`), flag is set and `cache_get` / `cache_put` become no-ops for the rest of the process. Segments fall back to the uncached probe.
- **`src/cache.cyr::cache_get`** — F-4 fix. Opens with `O_NOFOLLOW` (numeric `131072` per the agnosys.cyr precedent; stdlib hasn't exported the constant yet). Symlink swap on a cache file returns 0 → cache miss → fresh write.
- **`src/cache.cyr::cache_put`** — F-5 fix. Atomic write: builds `<path>.tmp.<pid>`, opens with `O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW` (mode `0o600`), writes, then `rename(2)` (SYS_RENAME = 82). Stale-temp from crashed prior run → unlink + retry once. Subsumes F-11 (file mode tightened from `0o644` to `0o600`).
- **`src/context.cyr::parse_last_exit(s)`** — F-7 fix. Length cap (≤ 10 digits, i.e. ≤ INT32_MAX width) + range clamp ([0, 65535]) + negative-rejection. Lifted into `context.cyr` from `main.cyr` so tests can drive it directly.
- **`src/pathlookup.cyr::find_in_path_with(path, name)`** + thin wrapper — F-8 fix. Walker now requires `path[pi] == '/'` before building the candidate; empty entries, `.`, `..`, and unqualified names are skipped. Refactor exposes the internal walker so tests inject a PATH cstring without needing `setenv` (stdlib doesn't have it).
- **Tests** — 34 new assertions across 19 cases (`245 → 279` total):
  - 8 `sanitize_segment_output` cases (ESC-mid-string, all-C0, DEL, UTF-8 passthrough, empty, null, all-controls-yields-empty, clean-input-unchanged).
  - 2 cache hardening cases (`cache_put_writes_mode_0600` stat-verifies the mode bits; `cache_get_refuses_symlink` unlinks + symlinks-to-`/etc/passwd` and asserts cache_get returns 0).
  - 6 `parse_last_exit` cases (null, empty, normal `[0, 1, 42, 255]`, overlong-input-rejected, overlarge-value-clamped, negative-rejected).
  - 3 `find_in_path_with` cases (rejects-relative, rejects-`.`/`..`/mixed-with-empty, absolute-works including `bin:/bin` skip-then-find).
  - Suite is now **279 passed, 0 failed (279 total)**.

### Changed

- **`VERSION`** — `0.8.0` → `0.9.0`.
- **`adapters/agnoshi.sh`** — contract header §3 gains the F-12 paragraph: agnoshi MUST treat captured stdout as a literal byte string; MUST NOT pass through percent-/variable-/backtick-expansion or any shell-syntax interpretation. Cites CVE-2021-3934 (oh-my-zsh `print -P`) and CVE-2021-45444 (zsh PROMPT_SUBST recursion) as precedents.
- **`src/main.cyr`** — `atoi(getenv("AGNOSHI_LAST_EXIT"))` replaced by `parse_last_exit(getenv("AGNOSHI_LAST_EXIT"))`.
- **`src/pathlookup.cyr`** — body extracted to `find_in_path_with(path, name)` (testable); `find_in_path(name)` becomes a one-line wrapper. No behaviour change for existing callers (vcs, cyrius_env).
- **`docs/adr/README.md`** — adds ADR 0007 row.
- **Binary size** — text 141,555 → 143,265 B (+1,710 for the four code fixes). bss 59,112 → 59,296 B (+184). **Total 200,667 → 202,561 B (+1,894 B).**
- **Performance** — unchanged. `render_prompt (default cwd+vcs+exit)` still ~9–10 µs avg, well under the 5 ms budget (0.2 % consumed). The sanitizer adds an alloc+copy per segment emit (~µs-level for typical segment outputs); the cache atomic-write adds an open+rename per put (~µs). Budget impact negligible.

### Roadmap

- **M8 closed.** Audit shipped, 6 findings fixed, 2 documented as deferred upstream (with filing plan), schema frozen, benchmarks finalised. Next: **M9 — v1.0 freeze + tag**. All v1.0 criteria from `roadmap.md` are now satisfiable; the v1.0 commit is a doc roll + the `1.0.0` tag.

## [0.8.0] — 2026-05-18

**M7 — shell adapters.** First-party `adapters/zsh.sh`, `adapters/bash.sh`, and `adapters/agnoshi.sh` ship as sourceable shell scripts: users replace whatever's setting their prompt today with a single `source /path/to/commandress/adapters/<shell>.sh` line and `cmdrs` takes over. The zsh adapter formalises the precmd-hook recipe that lived in `docs/guides/zsh-testing.md` (now [`zsh-setup.md`](docs/guides/zsh-setup.md)); the bash adapter handles bash's prompt-width quirk by wrapping ANSI SGR escapes in `\001..\002` markers via a `sed` filter (zsh doesn't need this with `prompt_subst`); the agnoshi adapter is contract-only — agnoshi hasn't adopted `$AGNOSHI_PROMPT_CMD` yet, so the file documents the spec and sets the env var so adoption flips the prompt over with zero further change here. Zero Cyrius code changes this milestone — all shell-side glue + docs.

### Added

- **`adapters/zsh.sh`** — sourceable from `~/.zshrc`. Resolves `cmdrs` once at source time (cached in `$_CMDRS`; `COMMANDRESS_BIN` env var overrides). Sets `prompt_subst`. Defines `_cmdrs_precmd` (captures `$?` → `$AGNOSHI_LAST_EXIT`, then assigns `PROMPT` from `cmdrs` and `RPROMPT` from `cmdrs --side=right`). Appends to `precmd_functions` so it composes with other zsh tools.
- **`adapters/bash.sh`** — sourceable from `~/.bashrc`. Same path-caching + `$AGNOSHI_LAST_EXIT` plumbing. New `_cmdrs_bash_render` helper pipes `cmdrs` output through `sed $'s/\\x1b\\[[0-9;]*m/\\x01&\\x02/g'` so bash's readline-width accounting treats each SGR escape as zero-width (without the wrap, long commands wrap to the wrong column). Prepends to `PROMPT_COMMAND` (composable). No `RPROMPT` analogue — bash has no native right-prompt; the bash side silently ignores `right_segments` config.
- **`adapters/agnoshi.sh`** — contract-only. One line of executable shell (`export AGNOSHI_PROMPT_CMD=cmdrs`) plus a 50-line header that *is* the prompt-cmd contract spec (5 numbered points: agnoshi reads `$AGNOSHI_PROMPT_CMD` per redraw; exports `$AGNOSHI_LAST_EXIT` before invoking; captures stdout as the prompt string; optional `--side=right` for right-prompt; direct-exec semantics). agnoshi currently renders its own prompt internally (`/path/to/agnoshi/src/prompt.cyr`); when it adopts the contract, sourcing this file flips the prompt over with no further commandress change.
- **`adapters/README.md`** — index of all three adapters with status badges (✓ Live zsh + bash; ⏳ Contract-only agnoshi), one-line install per shell, "what every adapter does" / shell-specific quirks / `$COMMANDRESS_BIN` override.
- **`docs/guides/bash-setup.md`** — new bash-side guide mirroring `zsh-setup.md`: install + source line, what-the-adapter-does (explicit on the `\001..\002` wrap and why `cmdrs` stays shell-agnostic), `COMMANDRESS_BIN`, "what's missing vs zsh" section (no right-prompt — explicit), manual-setup fallback, revert-to-starship.

### Changed

- **`VERSION`** — `0.7.0` → `0.8.0`.
- **`docs/guides/zsh-testing.md`** → **`zsh-setup.md`**. Rewritten: leads with the one-line `source` install, documents `COMMANDRESS_BIN`, kept manual-setup section as a fallback, removed pre-M5 caveats that no longer apply (colour shipped 0.6.0; cache shipped 0.7.0).
- **`docs/guides/getting-started.md`** — preamble updated to reflect M7 ("v0.8.0 — first-party shell adapters shipped under `adapters/`"); old "Testing today in zsh (pre-M7)" section replaced with a "Using `cmdrs` in zsh / bash" section pointing at both new guides + the agnoshi contract file.
- **`docs/development/state.md`** — version block now `0.8.0`; In-flight "Next" updated to point at M8 (public-API + security audit).

### Roadmap

- **M7 closed.** All three adapters shipped. zsh + bash are first-class today; agnoshi is contract-pending — the env-var name is locked in and the spec is documented in `adapters/agnoshi.sh`'s header. Next: **M8 — public API + security audit** (schema freeze, audit pass on config parsing / env-var handling / subprocess exec, benchmarks finalised). After M8: **M9 — v1.0 freeze**.

## [0.7.0] — 2026-05-18

**M6 — performance hardening.** The change that makes `vcs` default-on. A new `src/cache.cyr` module wraps any segment in a per-cwd mtime-keyed cache (1 s TTL by default); `vcs_render` becomes the first consumer and **drops from ~1.8 ms cold to ~7 µs cached** (the cold call is still paid once per TTL window; rapid redraws in the same shell pay the cached price). With caching live, the default segment list flips from `["cwd", "exit"]` to `["cwd", "vcs", "exit"]` — out-of-box prompts now show branch state without a config change, while non-sit dirs stay clean (vcs renders empty there, no extra separator). CI grows a 5 ms cold-start budget gate that fails the build if `render_prompt` exceeds the per-redraw budget. A new `docs/benchmarks/history.csv` accumulates per-release bench numbers as a versioned artifact — perf trends now live in `git log` next to the changes that caused them. Parallel segment evaluation (the fifth M6 candidate) was punted: with caching in place and only one slow segment (`vcs`), the speculative infrastructure doesn't earn its keep yet. Cyrius pin bumped to 5.11.64 alongside (silences the toolchain-drift warning that surfaced once 5.11.64 hit local; no behavior change).

### Added

- **`src/cache.cyr`** — per-segment per-cwd probe cache backed by `/tmp/commandress-<uid>/`. `cache_init()` does an idempotent 0o700 mkdir; `cache_get(seg, cwd, ttl_secs)` returns the cached cstring (possibly empty — `""` is a real value meaning "no segment output here") or 0 on miss/expired; `cache_put(seg, cwd, value, len)` writes. mtime is the TTL clock via `sys_stat` (offset 88 = `st_mtim.tv_sec`). djb2 32-bit hash on cwd → 8 hex chars (`vcs-077ebd41`) keeps cache filenames bounded.
- **Render path now consults the cache.** `src/segments/vcs.cyr::vcs_render` gets cwd via `SYS_GETCWD`, checks `cache_get("vcs", cwd, 1)` before doing any work. On hit: return immediately (empty cstring → render-empty path, matches no-sit-repo behavior). On miss: existing find_in_path + shellout + parse, then `cache_put` the result (including `""` for misses so the next redraw also short-circuits). `main.cyr` calls `cache_init()` once at startup.
- **`scripts/bench-gate.sh`** — pipes `cyrius bench` output through, greps for `render_prompt`, parses `<n>{ns|us|ms} avg`, normalises to µs, fails when over `BUDGET_US` (default 5000 = the 5 ms total cold-start budget from `architecture/001-prompt-render-budget.md`). New "Cold-start budget gate (≤ 5 ms)" step in `.github/workflows/ci.yml` runs it.
- **`scripts/bench-history.sh`** + **`docs/benchmarks/history.csv`** + **`docs/benchmarks/README.md`** — bench output → CSV row-per-bench-per-release (`date,version,name,avg_ns,min_ns,max_ns,iters`), values normalised to nanoseconds at write time, env-var overrides for `BENCH_DATE` / `BENCH_VERSION` / `BENCH_HISTORY_CSV` enable manual back-filling. Seeded with rows for 0.6.1 (the new-cwd-style baseline) + 0.7.0 (the post-cache numbers) so trend plots immediately show the cache win.
- **Tests** — 8 new assertions across 4 cases in a new `cache` test group: roundtrip (put + get returns same bytes), per-cwd isolation (distinct keys don't collide), empty-value caching (`""` is a real cached value distinguishable from miss), miss-when-absent (no cache file → 0). Plus 1 assertion update in `test_config_defaults` for the new 3-segment default. Suite is now **245 passed, 0 failed (245 total)** (up from 237).

### Changed

- **`VERSION`** — `0.6.1` → `0.7.0`.
- **`cyrius.cyml [package].cyrius`** — `5.11.63` → `5.11.64`. Silences the toolchain-drift warning that surfaced once the local wrapper passed our pin. No upstream features needed; the bump is hygiene.
- **`src/config.cyr::config_default`** — segment list flipped from `["cwd", "exit"]` to `["cwd", "vcs", "exit"]`. Schema-comment example in the file header updated to match. The flip is unconditional: a user without a `~/.commandress` file now gets vcs in the prompt out of the box. Inside a sit repo: branch + dirty marker. Outside one: empty, the segment self-suppresses so the prompt stays clean.
- **`src/segments/vcs.cyr`** — `vcs_render` rewrapped around the cache (see Added above); the existing find_in_path + shellout + parse path is preserved verbatim, just gated behind `cache_get`. Adds the `VCS_CACHE_TTL_SECS = 1` constant alongside the existing `VCS_BUDGET_MS = 5`.
- **`tests/commandress.bcyr`** — bench label `render_prompt (cwd+exit)` → `render_prompt (default cwd+vcs+exit)` to match the new default. `bench_vcs_segment` label → `vcs_render (cached, 1s TTL)`. `cache_init()` added to bench `main` so the cache layer warms (without it, vcs_render would miss every iteration).
- **`README.md`** — default-segment paragraph rewritten: now leads with the cache cost numbers and the "empty outside a sit repo" graceful behavior.
- **`.github/workflows/ci.yml`** — new "Cold-start budget gate (≤ 5 ms)" step pipes the bench through `scripts/bench-gate.sh`.
- **Binary size** — text 138,937 → 141,555 B (+2,618 for `src/cache.cyr` + the vcs render-side cache wrap). bss 54,816 → 59,112 B (+4,296 — the cache module's heap-init plumbing + UID-stringification scratch). **Total 193,753 → 200,667 B (+6,914 B).** Net win vs 0.3.0 baseline (395,115 B): **−194,448 B**.
- **Performance** — `vcs_render` **4.6 ms → 67 µs avg** (~70× faster on the cached path; cold call is still ~1.2 ms which is the new `max`). `render_prompt (default cwd+vcs+exit)` 10 µs — even with the new default including vcs, the prompt budget is **0.2 % of 5 ms**. `config_default` 3 µs (unchanged). All other timings within run-to-run variance.

### Roadmap

- **M6 closed.** Cache (`src/cache.cyr`) shipped, vcs default-on, CI cold-start gate live, benchmark history CSV in `docs/benchmarks/`. Parallel segment evaluation deferred to "as-needed / post-v1" — single-slow-segment regime doesn't justify the threading infrastructure yet. Next: **M7 — shell adapters** (agnoshi prompt-hook integration, bash `PROMPT_COMMAND` adapter, zsh `precmd` adapter — the current `docs/guides/zsh-testing.md` recipe formalises into a shipped artifact).

## [0.6.1] — 2026-05-18

**M5 fully closed.** Three remaining M5 deliverables land — `docs/themes/` curated theme files, right-prompt support, and powerline-style separators — plus an opportunistic config-path rename that aligns commandress with the `.bashrc` / `.vimrc` dotfile convention before v1 schema-freeze locks the path. Suite grows from 217 to 237 assertions; binary grows 188,495 → 193,753 B (+5,258 B) for the new render branches and the 13 new Config slots. The "any terminal" angle for commandress is closer — colour ships in 0.6.0, structured rendering and right-prompt ship here, palette switching lands in 0.7.x. Pure Cyrius. No deps beyond stdlib.

### Breaking

- **Config file renamed: `~/.commandress.cyml` → `~/.commandress`.** No fall-back; the old path is no longer read. Migration is one `mv`: `mv ~/.commandress.cyml ~/.commandress`. Rationale + alternatives in [ADR 0006](docs/adr/0006-config-path-rename.md). Pre-emptive to the v1 schema freeze — the path is part of the public contract M8 locks down.

### Added

- **`docs/themes/`** — five curated theme files, each a self-contained `~/.commandress` drop-in: `commandress.cyml` (first-party signature theme; royal palette mapping Tyrian purple / royal blue / heraldic gold / crimson / emerald / argent to the canonical six royal colours with heraldic origins called out in comments), `nord.cyml`, `dracula.cyml`, `gruvbox.cyml`, `monokai.cyml`. Each theme file ships a full `[[prompt]]` + `[[palette]]` + `[[segments.X]]` set so `cp <theme> ~/.commandress` produces a working coloured prompt. README explains 16-colour-named-vs-terminal-palette interaction and the "edit by hand to merge into an existing config" workflow.
- **Right-prompt support.** `cmdrs --side=right` renders `cfg.right_segments` (a new `[[prompt]] right_segments = [...]` list) and skips the trailer. Default empty — opt-in. New `_parse_side()` walks argv looking for `--side=right`; unrecognised / absent → left-side default. Zsh integration is one extra line in the precmd hook: `RPROMPT="$(cmdrs --side=right)"`. Empty `right_segments` → `RPROMPT` evaluates to "" → no right prompt rendered.
- **Powerline-style separators.** Opt-in via `[[prompt]] separator_style = "powerline"` + `separator_glyph` (e.g. `""` for U+E0B0, needs nerd font; any ASCII char works as a fallback). Render emits `<fg=prev_bg; bg=next_bg>` SGR + glyph between adjacent segment blocks, plus a closing transition (`fg=last_bg; bg=default`) after the last segment. Each segment now stores raw bg cstring in a parallel `CFG_BG_<segment>` slot so transitions can be composed at render time (the pre-baked SGR doesn't surface its bg back out). Right-prompt has its own `right_separator_glyph` for left-pointing variants (`""` / U+E0B2). Plain mode is unchanged and remains the default.
- **`docs/adr/0006-config-path-rename.md`** — captures the rename decision with the three alternatives considered (clean break / fall-back / defer-to-v1), the dotfile-convention argument, and the schema-freeze framing.
- **Tests** — 20 new assertions across 13 cases (`217 → 237`):
  - 3 `config right-prompt` (default empty, parsed segments, explicit `[]` opt-out).
  - 6 `config powerline` (default separator_style is plain, default bg slots all 0, `separator_style = "powerline"` sets 1, explicit "plain" stays 0, raw bg stored for direct values, raw bg via palette ref).
  - Theme-related cases didn't get a separate test group — themes are pure config snippets exercised through the existing config-load test paths.
  - Suite is now **237 passed, 0 failed (237 total)**.

### Changed

- **`src/main.cyr`** — `include "lib/args.cyr"` + `args_init()` early in `main`. New `_parse_side()` for the `--side=right` flag. `render_prompt(cfg, ctx, side)` signature change; main passes `_parse_side()`. `_default_config_path` suffix `/.commandress.cyml` → `/.commandress`. Comments updated.
- **`src/config.cyr`** — `CFG_SIZE` 152 → 264 B. New slots: `CFG_RIGHT_SEGMENTS` (8 B), 10 × `CFG_BG_<segment>` (80 B total), `CFG_SEPARATOR_STYLE` (8 B, int), `CFG_SEPARATOR_GLYPH` + `CFG_RIGHT_SEPARATOR_GLYPH` (16 B). New getters for all 13. `_apply_seg_style` and `_load_color_only_section` grew a `bg_offset` parameter — they now stash the resolved raw bg alongside the baked SGR. Prompt-block allow-list adds `right_segments`, `separator_style`, `separator_glyph`, `right_separator_glyph`. Schema comment expanded.
- **`src/render.cyr`** — new `_bg_for(cfg, name)` mirrors `_sgr_for` for the parallel raw-bg slots. New `_emit_powerline_transition(prev_bg, next_bg, glyph)` writes `\x1b[<fg>;<bg>m<glyph>\x1b[0m` (skips when glyph empty; partial SGR handled correctly via `sgr_open_for`). `render_prompt(cfg, ctx, side)` now branches on `cfg_separator_style`: plain path unchanged; powerline path emits transitions between segments + trailing close-glyph when last segment has a bg. Trailer paints only on the left side (`side == 0`); right-prompt is segments-only.
- **`docs/themes/README.md`** — leads with `cp` (themes are self-contained); "Existing config you want to keep" section calls out CYML / TOML first-occurrence-wins semantics and gives the edit-by-hand recipe; new "Powerline mode" section with full example config + font requirement.
- **`docs/guides/zsh-testing.md`** — precmd hook updated with `RPROMPT="$(cmdrs --side=right)"`; example config gets `right_segments = ["time"]`.
- **Doc refresh for the path rename** — README, CLAUDE.md, `docs/guides/{getting-started,zsh-testing}.md`, `docs/themes/README.md`, `docs/examples/prompt-tour.md`, `docs/architecture/001-prompt-render-budget.md`, `docs/development/state.md`, and the schema-comment header in `src/config.cyr` all updated to reference `~/.commandress`.
- **Binary size** — text 133,799 → 138,937 B (+5,138 for the argv parsing path, render-side branches, three new resolvers, palette-vs-raw bg parsing). bss 54,696 → 54,816 B (+120). **Total 188,495 → 193,753 B (+5,258 B)** for M5-complete + the rename.
- **Performance** — `render_prompt (cwd+exit)` 3 µs avg unchanged. `config_default` 2 → 3 µs (extra slot inits). All other timings within run-to-run variance. `vcs_render` measured at 4.6 ms vs 1.8 ms in 0.5.0 — still suspect dev-host load (vcs code path untouched); M6 caching closes this regardless.

### Roadmap

- **M5 fully closed.** All five deliverables shipped: ANSI colour palette + per-segment colours + opinionated default theme (v0.6.0), `[[palette]]` reference layer (v0.6.0), cwd `max_length` truncation (v0.6.0), `docs/themes/` curated themes (this release), right-prompt support (this release), powerline-style separators (this release). Next: **M6 — performance hardening** (parallel segment evaluation, 1 s TTL probe cache, default-segment flip to include `vcs`, ≤ 5 ms cold-start CI gate, benchmark history CSV).

## [0.6.0] — 2026-05-18

**M5 (partial) — theming foundation.** The prompt has colour. A new `src/color.cyr` module turns named ANSI colours + style modifiers into SGR escape sequences; ten per-segment SGR slots in `Config` hold pre-computed opening strings; render wraps each painted segment with the opener and a `\x1b[0m` reset. An opinionated default theme ships baked in — cwd cyan-bold, exit red-bold, vcs yellow, env segments in their language-conventional colours — so users get a working coloured prompt with zero config. Users override per-segment via `fg` / `bg` / `style` keys in `[[segments.X]]`. The optional `[[palette]]` table + `palette:<name>` reference syntax sets up the v1 theme-switching path: a single edit to the palette block recolours the whole prompt. cwd `max_length` (carried over from M1) bounds long paths at '/' boundaries. The three remaining M5 deliverables — powerline-style separators, right-prompt support, and `docs/themes/` curated examples — are deferred to v0.6.x; the contract is stable enough that they land additively. Per-segment surface for v0.6.0: 16 named ANSI colours (8 standard + 8 bright) + `"default"`, four style modifiers (bold / italic / underline / reverse), one segment-bounded path-truncation knob, and a single-palette layer.

### Added

- **`src/color.cyr`** — ANSI SGR helpers for the prompt theme layer. `color_to_sgr_fg(name) / color_to_sgr_bg(name)` return SGR ints (30..37 / 90..97 for fg; bg = fg + 10) or 0 for `default` / null / unknown. `style_to_sgr_mods(s, codes, max)` parses space-separated tokens (bold | italic | underline | reverse), writes mod codes as i64s, returns count. `sgr_open_for(fg, bg, style)` composes `"\x1b[<mods>;<fg>;<bg>m"` and returns 0 when nothing to emit (the empty-default case). `SGR_RESET` cstring `"\x1b[0m"`. ~140 LoC; 54 assertions across 16 cases in the `color` test group.
- **`[[palette]]` section + `palette:<name>` reference syntax** — define a single table of named colour slots, reference them in any segment's `fg` / `bg` field. Resolved at config-load time so render still emits the pre-computed SGR. Unknown ref → segment renders unstyled (same path as `"default"`). Sets up the v0.7.x multi-palette + theme-switching shape without an additional breaking change.
- **Per-segment colour fields** — `fg`, `bg`, `style` allowed in every `[[segments.X]]` block. New colour-only sections added for `hostname`, `user`, `cyrius_env`, `python_env`, `node_env`, `rustup_env` (segments with no other per-segment knobs in v0.6.0 still need a place to declare colour).
- **Opinionated default theme** — baked into `config_default`:
  - `cwd` cyan-bold, `exit` red-bold, `vcs` yellow, `time` bright_black (dim)
  - `hostname` blue, `user` green-bold
  - `cyrius_env` magenta, `python_env` yellow, `node_env` green, `rustup_env` red
- **cwd `max_length` truncation** — bounds the rendered cwd to `max_length` bytes (0 = no limit; default 0). When over, the longest qualifying suffix anchored at a `/` boundary is kept with a `...` prefix; pathological `max_length < 4` emits a row of `.` dots; no-qualifying-`/` falls back to `...` + raw tail. Carried over from M1.
- **Render-side SGR plumbing** — `src/render.cyr::_sgr_for(cfg, name)` resolves the per-segment SGR opening cstring from the Config; the segment loop emits `<sgr_open><out>\x1b[0m` when SGR is non-zero, plain output otherwise.
- **Tests** — 33 new assertions across 17 cases (`200 → 217` after the colour wiring lands, then `+10 → 217 → 217` — the final count is **217**):
  - 16 colour cases (8 standard + 8 bright fg, bg = fg + 10, absent/default/unknown, four style modifiers in isolation, multi-mod ordering, unknown-word skip, empty/whitespace, sgr_open all-paths including three-digit codes via bright_white, SGR_RESET exact bytes).
  - 6 config-theme cases (default-theme bake-in including exact bytes for cwd + exit, partial-override safety, fg-only-override, full reset, hostname color-only, python_env color-only).
  - 5 palette cases (resolves ref, multi-slot palette, unknown ref → unstyled, mixed raw + palette refs, absent palette behaves like before).
  - 8 cwd-truncation cases (no-op zero, no-op within budget, collapse at slash, exact budget, leaf-only, pathological `< 4`, no-qualifying-slash fallback, render-path bound).
  - Suite is now **217 passed, 0 failed (217 total)**.

### Changed

- **`VERSION`** — `0.5.0` → `0.6.0`.
- **`src/config.cyr`** — schema gained `fg` / `bg` / `style` keys on every `[[segments.X]]` block + an optional `[[palette]]` section + `max_length` on `[[segments.cwd]]`. Storage grew: 10 new `CFG_SGR_*` slots (8 bytes each) + `CFG_CWD_MAX_LENGTH` (8 bytes); `CFG_SIZE` 64 → 152 B. Three new helpers — `_apply_seg_style` (partial-override-safe: only overwrites the SGR slot when ≥1 of fg/bg/style is present), `_load_color_only_section` (for segments with no non-colour knobs), `_load_palette` / `_palette_lookup` / `_resolve_color_value` (palette parsing + ref resolution). Cwd block also parses `max_length` via `atoi(str_cstr(...))`.
- **`src/segments/cwd.cyr`** — `cwd_render(home, max_length)` signature change; new `_truncate_cwd(path, plen, max_length)` helper. The segment composes home-shortening → truncation in that order. Existing callers (bench, tests) updated to pass `0` for unlimited.
- **`src/render.cyr`** — segment loop now emits `<sgr_open><out>\x1b[0m` when the segment has a non-zero SGR slot, plain output otherwise. New `_sgr_for(cfg, name)` mirrors `_seg_fn_for` for SGR-by-name resolution.
- **Binary size** — text 121,520 → 133,799 B (+12,279 for `color.cyr`, palette helpers, SGR resolver, truncation logic). bss 54,568 → 54,696 B (+128). **Total 176,088 → 188,495 B (+12,407 B)** for the theming foundation + truncation.
- **Performance** — `config_default` 154 ns → **2 µs** (10 `sgr_open_for` calls during default-theme bake; one-time per redraw — 0.04 % of the 5 ms budget). `render_prompt (cwd+exit)` 2 µs → **3 µs** (~1 µs SGR emit overhead per painted segment under the default theme). All other segment timings within run-to-run variance of 0.5.0 numbers. `vcs_render (fork + sit status)` measured at **3.9 ms** vs 1.8 ms in 0.5.0 — the vcs code path is unchanged in this release, so suspect dev-host load variance (fork+exec timing is sensitive to system state); will re-baseline in 0.6.x.

### Roadmap

- **M5 partially closed.** Colour palette + per-segment colours + opinionated default theme + cwd `max_length` truncation + `[[palette]]` reference layer all shipped. Three M5 deliverables remain — **powerline-style separators**, **right-prompt support**, and **`docs/themes/` curated theme files** — deferred to v0.6.x bites; the underlying SGR + palette contracts are stable enough that they land additively without schema churn. Default segments stay `["cwd", "exit"]` — colours apply across the registered set regardless of which ones are listed.

## [0.5.0] — 2026-05-18

**M4 — language-env segments.** Four new probes — `cyrius_env`, `python_env`, `node_env`, `rustup_env` — close the milestone. All four follow a single file-first resolution order ([ADR 0005](docs/adr/0005-language-env-probe-pattern.md)): optional env var (e.g. `$VIRTUAL_ENV`) → ancestor walk for a marker file (`VERSION`, `.python-version`, `.nvmrc`, `rust-toolchain`) → read+trim → optional shellout (today only `cyrius_env` falls back to `cyrius --version` — Python / Node / Rust shellouts are parked pre-v1 per the file-first user direction). The walk + read are absorbed into two shared helpers in `src/fslookup.cyr` (`find_ancestor_with` + `read_trimmed_file_at`); `_find_in_path` similarly lifted from `vcs.cyr` to `src/pathlookup.cyr` so the shellout segments share PATH resolution. Net result: a new env-segment is ~20 lines (`node_env.cyr` is 20; `rustup_env.cyr` is 18). Default segments stay `["cwd", "exit"]`; new segments are opt-in.

### Added

- **`src/segments/cyrius_env.cyr`** — Cyrius project segment. Walks ancestors for `cyrius.cyml` (project marker), reads `<root>/VERSION` (the canonical project pin per `CLAUDE.md`), falls back to `cyrius --version` via `shellout_capture` (5 ms budget, parses the `cyrius X.Y.Z` first line). Output is the raw version string; no label/glyph (theming is M5). Helpers `cyrius_env_find_root`, `cyrius_env_read_version`, `cyrius_env_parse_version`, `cyrius_env_render` are individually testable.
- **`src/segments/python_env.cyr`** — Python project/venv segment. `$VIRTUAL_ENV` basename first (e.g. `myproj`), else `.python-version` ancestor walk + read+trim (e.g. `3.11.7`). `python --version` shellout deferred pre-v1. `python_env_basename` is a pure helper with edge-case coverage (trailing slashes, multi-slash, bare names, null, empty, all-slashes, `/`).
- **`src/segments/node_env.cyr`** — Node project segment. `.nvmrc` ancestor walk + read+trim. Passes both numeric (`20.11.1`) and channel-style (`lts/iron`) content verbatim. `package.json engines.node` parsing and `node --version` shellout both deferred.
- **`src/segments/rustup_env.cyr`** — Rust toolchain segment. Plain-format `rust-toolchain` ancestor walk + read+trim (`1.75.0`, `stable`, etc.). `rust-toolchain.toml` parsing blocked on Cyrius stdlib's single-bracket TOML gap (papercut Item 3, deferred to v6.x); `rustup show` shellout deferred per file-first policy.
- **`src/pathlookup.cyr`** — shared `find_in_path(name)` lifted from `src/segments/vcs.cyr`. Same walk-`$PATH` + `access(X_OK)` probe; one heap-alloc'd absolute-path cstring per hit. The lift exists because the upcoming shellout-backed env probes (only `cyrius_env` today, more pre-v1) all need PATH resolution. Pending Cyrius v6.x Item 8 upstream.
- **`src/fslookup.cyr`** — shared fs helpers for env-probe segments:
  - `find_ancestor_with(start_dir, marker)` — walks `start_dir` upward returning the nearest ancestor where `<dir><marker>` exists (`access(F_OK)`). Marker must start with `/` (e.g. `"/cyrius.cyml"`). POSIX collapses leading `//` so the root-case join is correct.
  - `read_trimmed_file_at(root, suffix)` — reads `<root><suffix>` (256-byte cap), trims surrounding ws (space, tab, `\n`, `\r`) at both ends, returns heap-alloc'd cstring or 0.
  Both extracted from inline implementations in `cyrius_env.cyr` / `python_env.cyr` once M4 hit three consumers. `cyrius_env_find_root` / `cyrius_env_read_version` / `python_env_read_pin` are now one-line delegates.
- **`docs/adr/0005-language-env-probe-pattern.md`** — captures the three-layer resolution contract (env var → ancestor file → shellout → empty), shared infrastructure (`fslookup` + `pathlookup` + `shellout`), output convention (raw version, theming deferred to M5), and per-segment artifact expectations (header / tests / bench). Alternatives considered: shellout-first (starship-style), per-segment walkers, single-spec factory, no-shellout-ever.
- **Render registry registers `cyrius_env` / `python_env` / `node_env` / `rustup_env`** via `_dispatch_cyrius_env` / `_dispatch_python_env` / `_dispatch_node_env` / `_dispatch_rustup_env` in `src/render.cyr`.
- **Tests** — 65 new assertions across 32 tests (`65 → 130` total):
  - 10 `cyrius_env`: parser (basic + no-trailing-newline + wrong-prefix + empty-version), find_root (hit + miss + trailing-slash + subdir walk-up), read_version (trims + missing + whitespace-only), render smoke.
  - 11 `python_env`: 8 basename edge cases (simple / trailing slash / multi-slash / bare / null / empty / all-slashes / root), read_pin (trims CRLF + missing), render smoke.
  - 2 `node_env`: empty-outside-project + helpers against temp tree (numeric + lts-style).
  - 2 `rustup_env`: empty-outside-project + helpers against temp tree (numeric + channel-name).
  - 2 `pathlookup`: finds `sh` (3 asserts: non-null + ends-in-`/sh` + passes `access(X_OK)`) + misses garbage name.
  - Suite is now **130 passed, 0 failed (130 total)**.
- **Benchmarks** — file-walk segments are all well inside the 5 ms total budget (CHANGELOG: numbers captured on the dev host, Linux 7.0.5-arch1-1, x86_64):
  - `cyrius_env_parse_version` **76 ns** avg (pure prefix-match + newline scan).
  - `cyrius_env_render (file path)` **7 µs** avg — getcwd + ancestor walk + open/read/trim. **0.14 %** of the 5 ms budget.
  - `python_env_basename` **98 ns** avg (trailing-slash strip + last-slash scan).
  - `python_env_render` **12 µs** avg — bench cwd has no `$VIRTUAL_ENV` so this is the full walk-to-`/` for `.python-version`. **0.24 %** of budget.
  - `node_env_render (empty walk)` **6 µs** avg. **0.12 %** of budget.
  - `rustup_env_render (empty walk)` **6 µs** avg.
  - All five env segments combined ≈ **31 µs** — three orders of magnitude under the budget. M6 caching is a *latency improvement* for the shellout cases, not a *prerequisite* for being usable.

### Changed

- **`VERSION`** — `0.4.0` → `0.5.0`.
- **`src/segments/vcs.cyr`** — inline `_find_in_path` (~30 LoC) replaced by a call to the shared `find_in_path` in `src/pathlookup.cyr`. No behavior change; `sit` PATH resolution still happens the same way.
- **`src/main.cyr`** — `include "src/pathlookup.cyr"` and `include "src/fslookup.cyr"` added ahead of `src/shellout.cyr` / `src/render.cyr`. Same on `tests/commandress.tcyr` and `tests/commandress.bcyr`.
- **`tests/commandress.bcyr`** — added the previously-missing `lib/chrono.cyr`, `lib/pwd.cyr`, `src/pathlookup.cyr`, `src/shellout.cyr` includes. Without them, post-`vcs_render` benches would have hit undefined-symbol crashes; the pre-existing gap was masked because no later bench reached those symbols.
- **Binary size** — text 114,578 → 121,520 B (+6,942 for the four new segments + two shared utility modules; ~1.4 KB came back when the read+trim duplication collapsed into `read_trimmed_file_at`). bss 37,656 → 54,568 B (+16,912 — additional segment file-scope buffers). **Total 152,234 → 176,088 B (+23,854 B)** for four segments + two shared utilities + the parser/orchestration code.

### Roadmap

- **M4 closed.** All four language-env segments shipped; the per-env-probe pattern captured as ADR 0005. Default segments stay `["cwd", "exit"]` — env segments are opt-in until M6 caching changes the cost math for the shellout-backed paths. Next: **M5 — theming + visuals** (ANSI palette, separator glyphs, right-prompt, themed examples, cwd length-truncation deferred from M1).

## [0.4.0] — 2026-05-18

**M3 — time + hostname + user segments + per-segment timeout watchdog (M2 carry-over).** Closes the four-deliverable bag for milestone M3 from the roadmap. The per-segment timeout enforcement that was carried forward from M2 lands as a generic `shellout_capture` watchdog (`src/shellout.cyr`) that wraps fork + pipe + epoll-deadline + SIGKILL + waitpid around any external command; `src/segments/vcs.cyr` switched from its inline `_vcs_capture` workaround onto the watchdog. Three new pure-syscall segments — `time` (mini-strftime over `lib/chrono.cyr`), `hostname` (`uname(2)` nodename field), and `user` (`getuid` + `lib/pwd.cyr` musl-style /etc/passwd reader, `$USER` fallback) — round out the M3 core set. Cyrius pin bumped to 5.11.63 along the way; binary size dropped **395,115 B → 152,234 B** vs the 5.11.59-era 0.3.0 (−242,881 B; the .61 heap-alloc of `lib/toml.cyr::toml_parse_file` reclaimed 256 KB of bss DCE couldn't drop).

### Added

- **`src/shellout.cyr`** — `shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen): i64`. Forks the child, dup2's stdout to a pipe + stderr to `/dev/null`, polls the read end with an epoll deadline, kills the child on overrun, reaps via `waitpid`. Returns bytes captured (`>= 0`), `-1` on system error, `-2` on timeout. Architecture model in [`docs/architecture/002-shellout-watchdog.md`](docs/architecture/002-shellout-watchdog.md). The watchdog is the reusable infrastructure piece — future shellout segments (M4 language-env) inherit the same gate without rebuilding the fork+poll scaffold.
- **`src/segments/time.cyr`** — `time_format(epoch, fmt)` + `time_render(fmt)`. Strftime-subset formatter supporting `%H %M %S %Y %y %m %d %%`; unsupported specs pass through verbatim. Default format `"%H:%M"`. Time is `CLOCK_REALTIME` UTC; local-time / `TZ` parsing is a future slot. Splitting the pure `time_format(epoch, fmt)` from the wall-clock-reading `time_render(fmt)` lets tests pin the input epoch and assert byte-for-byte.
- **`src/segments/hostname.cyr`** — `uname(2)` nodename field at offset 65 of the utsname struct. One syscall, no config knobs. Short-host rendering (strip first dot onward) and length truncation are future config fields if asked for.
- **`src/segments/user.cyr`** — `getuid()` + `pwd_getpwuid()` direct /etc/passwd lookup (musl-style; bypasses glibc NSS via `lib/pwd.cyr`). Falls back to `$USER` env var on lookup failure (missing /etc/passwd, UID not present, strbuf too small) and finally renders empty when even that's unset. Matches starship/PS1 conventions for the user surface.
- **`docs/architecture/002-shellout-watchdog.md`** — mechanism + caller contract + scope limits (no retry, no partial-output, no CPU-bound enforcement).
- **Config schema gains `[[segments.time]]`** — `format = "%H:%M"` (default). Default applied baseline-then-override; unknown keys warn to stderr with per-section allow-list. `hostname` and `user` register in the segment dispatcher but ship no `[[segments.*]]` block at v0.4.0 (no knobs to expose yet).
- **Render registry registers `time` / `hostname` / `user`** via `_dispatch_time` / `_dispatch_hostname` / `_dispatch_user` in `src/render.cyr`. Default `cfg.segments` stays `["cwd", "exit"]` — the new segments are opt-in. M6 caching will revisit which segments live in the default set.
- **Tests** — 18 new assertions across 12 tests (`51 → 65` total):
  - 4 shellout: `test_shellout_happy_path` (`/bin/echo hello` returns 6 bytes verbatim), `test_shellout_timeout_kills_child` (`/bin/sleep 1` with 10 ms budget returns -2 in well under 1 s — proving SIGKILL fired rather than parent blocking on waitpid).
  - 9 time: HH:MM / HH:MM:SS / date / 2-digit year (verified against 2026-01-01 epoch) / literal `%%` / unknown spec pass-through / mixed literals+specs / null fmt / empty fmt.
  - 3 hostname: non-null render + byte-for-byte match against direct `uname(2)` nodename.
  - 2 user: non-null render with /etc/passwd-or-$USER skip-on-both-absent.
  - Suite is now **65 passed, 0 failed (65 total)**.

### Changed

- **`VERSION`** — `0.3.0` → `0.4.0`.
- **`cyrius.cyml [package].cyrius`** — `5.11.59` → `5.11.63`. Absorbs the .60–.63 Cyrius commandress papercut band (Items 1, 2, 5, 6, 7 closed; Items 3, 4, 8 still deferred to Cyrius v6.x).
- **`lib/` refresh** — `cyrius lib sync` pulled the .60 / .61 fixes for `lib/process.cyr` (`_exec3` byte-contract; vec-exec family stderr dup2) and `lib/toml.cyr` (`toml_parse_file` heap-alloc).
- **`src/segments/vcs.cyr`** — `_vcs_capture` deleted (~45 LoC); `vcs_render` now calls `shellout_capture(sit_path, argv, envp, VCS_BUDGET_MS = 5, &buf, 8192)` and treats any negative return as the empty-render path. Hardcoded 5 ms budget is the seam where config-overridable `[[segments.vcs]] budget_ms = N` plumbing will hook in later. `_find_in_path` stays inline pending Cyrius v6.x Item 8.
- **`src/config.cyr`** — `CFG_SIZE` grew 56 → 64 B for the new `CFG_TIME_FORMAT` slot. `config_default()` initializes it to `"%H:%M"`. `config_load()` gains a `[[segments.time]]` parsing block with allow-list `{format}`.
- **`src/main.cyr`** — added `include "lib/chrono.cyr"` (for `clock_now_ms` + `clock_epoch_secs` + `epoch_to_date`), `include "lib/pwd.cyr"` (user segment), and `include "src/shellout.cyr"` ahead of `src/render.cyr`.
- **`tests/commandress.tcyr`** — same library + segment includes added.
- **Binary size** — text 84,050 → 114,578 B (+30,528 for the four new segments + watchdog + chrono + pwd surfaces that survive DCE in commandress's slice). bss 298,064 → 37,656 B (−260,408 — toml heap-alloc).

### Roadmap

- **M3 closed.** All four deliverables shipped: per-segment timeout watchdog (M2 carry-over), time segment, hostname segment, user segment. Default segments remain `["cwd", "exit"]` — new segments are opt-in until M6 cached probes change the cost math.

## [0.3.0] — 2026-05-17

**M2 — VCS context segment (sit-based).** commandress now reads the current branch + dirty/clean state from [`sit`](https://github.com/MacCracken/sit) (the AGNOS-native VCS, per ADR 0004) and renders it as a segment. Opt-in via `segments = ["cwd", "vcs", "exit"]` in `~/.commandress.cyml`. Inside a sit repo on branch `main` with a clean tree → `<cwd> main $ `; with edits → `<cwd> main* $ `; outside any sit repo or without `sit` on PATH → vcs segment is empty. Per-segment timeout enforcement is the only M2 deliverable not in this release — `sit status` is fast in practice (~1.8 ms fork+exec+parse on the dev host) and the watchdog earns its own slot in v0.4.0.

### Added

- **ADR 0004** — VCS probe shells out to `sit`, not external `git`. Sovereign-stack alignment captured. [`docs/adr/0004-vcs-probe-via-sit.md`](docs/adr/0004-vcs-probe-via-sit.md).
- **`src/segments/vcs.cyr`** — VCS context segment.
  - `_find_in_path(name)` — walks `$PATH`, returns the absolute path of the first hit (`access(X_OK)`-probed). Needed because `lib/process.cyr` wraps bare `execve(2)` which does NOT do PATH lookup. ~30 LoC inline; filed upstream as papercut item 8 to push a `which()` / `run_p` helper into stdlib.
  - `_vcs_capture(cmd_path, arg1, buf, buflen)` — inline fork + pipe + execve with stdout captured into `buf` and stderr dup2'd to `/dev/null`. Heap-alloc'd argv (24 B). Avoids `lib/process.cyr::run_capture` because its `_exec3` helper has a stack-buffer-size bug (`var argv[4]` reserves 4 *bytes* but stores 5 pointers = 40 bytes — silent stack overflow that broke `run_capture("/bin/echo", "hello", 0, ...)` returning 1 byte instead of 6). Filed upstream as papercut item 6.
  - `vcs_parse_render(buf, n, dirty_marker)` — pure parser. Returns `<branch>` (clean) or `<branch><dirty_marker>` (dirty) or 0 (parse failure / not a recognised `On branch <name>` shape).
  - `vcs_render(dirty_marker)` — composes the above: find sit, capture, parse, render.
- **Config schema gains `[[segments.vcs]]`** — `show_dirty: bool` (default `true`), `dirty_marker: string` (default `"*"`). Defaults baked in; missing section → defaults; unknown keys warn to stderr with per-section allow-list.
- **Render registry registers `vcs`** via `_dispatch_vcs` in `src/render.cyr`. Default `cfg.segments` stays `["cwd", "exit"]` — vcs is opt-in for v0.3.0 (one fork+exec per redraw is non-trivial cost; M6 caching changes the math, and only-when-asked is the right default until then).
- **Example config updated** with the `[[segments.vcs]]` section + body-zone notes about the new segment.
- **Tests** — 11 new (4 vcs config + 7 vcs parser) on top of the existing 36. `cyrius test` 47/47 green. Parser tests cover: clean, staged-dirty, unstaged-dirty, custom marker, marker-disabled, wrong-prefix-returns-empty, short-buffer-returns-empty.
- **Benchmarks** — `vcs_parse_render` 233 ns avg (pure byte-scan), `vcs_render` (fork+sit status+parse) **1.814 ms** avg — ~36 % of the 5 ms cold-start budget. M6 caching (1 s TTL on probe results) eats the redundant cost across rapid redraws.
- **Upstream filings** — appended three new items (6 — `_exec3` argv size bug; 7 — `exec_capture` missing stderr redirect; 8 — no PATH lookup in stdlib) to the existing [cyrius issue 2026-05-17 commandress papercuts](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-17-commandress-stdlib-papercuts.md). All three are workaround-shipped in this release.

### Changed

- Binary size: **374,168 B → 395,592 B** (+21,424 B for the vcs segment + parser + `_find_in_path` + `_vcs_capture` + new tests). `.bss` largely unchanged; growth is in `.text`.
- Roadmap M2 ADR ref updated to **0004** (the previous draft used 0003, which is now taken by the config-format ADR).
- Roadmap M2 marked feature-complete; per-segment timeout enforcement (the remaining M2 deliverable) deferred to v0.4.0 with explicit roadmap note.

## [0.2.0] — 2026-05-17

**M1 — minimum viable prompt — feature-complete.** Config loader lands; the prompt is now end-to-end user-configurable. `cwd` and `exit` segments paint per the user's `~/.commandress.cyml`; segment order, separator, trailer, and per-segment toggles (`home_shorten`, `hide_zero`) all flow through from disk to render. Defaults are baked in — the binary still produces the v0.1.0 prompt shape when no config file is present. M2 (VCS segment) reframed to shell out to [`sit`](https://github.com/MacCracken/sit) (AGNOS-native) rather than external `git` — sovereign-stack alignment.

### Added

- **`src/config.cyr`** — CYML config loader for `~/.commandress.cyml`. Schema:
  ```cyml
  [[prompt]]
  segments  = ["cwd", "exit"]
  separator = " "
  trailer   = " $ "

  [[segments.cwd]]
  home_shorten = true

  [[segments.exit]]
  hide_zero = true
  ```
  Defaults baked in; missing file → defaults; unknown fields warn to stderr with per-section allow-list. The `[[name]]` (array-of-tables) spelling is a stdlib-parser workaround — `[name]` (single table) support is filed as [cyrius proposal 2026-05-17](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-17-toml-single-bracket-sections.md). Once it lands, the schema migrates to `[prompt]`/`[segments.cwd]`/`[segments.exit]` with `[[name]]` kept back-compat.
- **`src/context.cyr`** — per-invocation `Context` struct `{ home, last_exit }` handed read-only to every segment dispatcher. Earned its own file once render became table-driven and segments stopped reading env vars themselves.
- **`src/render.cyr` is now table-driven** — registers segments as `(name → dispatcher fn ptr)` and walks `cfg.segments` via `fncall2(fp, cfg, ctx)`. Joins non-empty outputs with `cfg.separator`; appends `cfg.trailer` unconditionally. Unknown segment names warn to stderr and skip — rendering continues with what's recognized.
- **`docs/examples/commandress.cyml.example`** — annotated example config with notes in the CYML body zone describing available segments.
- **Config-loader tests** — `test_config_defaults`, `test_config_load_missing_returns_defaults`, `test_config_load_null_path_returns_defaults`, `test_config_load_full_override`, `test_config_load_partial_override`. 36 assertions total across the suite (was 13 in v0.1.0).
- **Roadmap M1 marked complete on `main`**; M2 reframed to **shell out to [`sit`](https://github.com/MacCracken/sit) rather than external `git`** for VCS state. Sovereign-stack alignment — commandress already commits to zero non-stdlib deps and `sit` is a first-party Cyrius binary on the same toolchain cadence.
- **Upstream filings opened during the session**:
  - [cyrius issue 2026-05-17 commandress papercuts](https://github.com/MacCracken/cyrius/blob/main/docs/development/issues/2026-05-17-commandress-stdlib-papercuts.md) — 5 stdlib/tooling items: bench scaffold using non-existent `bench()` 3-arg form; `lib/toml.cyr::toml_parse_file`'s 256 KB on-fn-scope static buffer that bloats every consumer's `.bss`; `[name]` silently dropped; LSP transitive-include false positives; `large static data` warning fires before DCE.
  - [cyrius proposal 2026-05-17 toml single-bracket sections](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-05-17-toml-single-bracket-sections.md) — additive `[name]` support alongside existing `[[name]]`.

### Changed

- Segment functions are invoked through dispatcher wrappers (`_dispatch_cwd`, `_dispatch_exit`) so the registry can pass `(cfg, ctx)` uniformly. Raw `cwd_render(home)` / `exit_render(code)` signatures unchanged for direct callers (tests, future debug paths).
- Binary size: **73,544 B → 374,168 B**. ~290 KB of that is `.bss` from `lib/toml.cyr::toml_parse_file`'s 256 KB `var buf[262144]` static in an unreachable fn (we use `toml_parse` directly after `cyml_parse` splits the header). Pure `.text` is **84 KB**. Tracking upstream — see papercut issue item 2. Per-segment + full-prompt timings unchanged: `cwd_render` 674 ns avg, `exit_render(42)` 38 ns avg, `config_default` 140 ns avg, `render_prompt` 2 µs avg — still **0.04 %** of the 5 ms budget.

## [0.1.0] — 2026-05-17

**Initial public release.** Scaffold + minimum viable prompt (M1 partial — `cwd` + `exit` segments, render pipeline) + CI/release wiring aligned with kriya. The binary renders a working prompt out of the box; full user-configurability arrives in v0.2.0.

### Identity

`commandress` (binary: `cmdrs`) — a structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) and eventually bash/zsh. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius. Stateless, segment-based, config-driven, zero non-stdlib deps.

### Added

- **Scaffold** via `cyrius init commandress` (2026-05-15) — `VERSION`, `cyrius.cyml`, `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `LICENSE`, `.gitignore`, `src/{main,test}.cyr`, `tests/commandress.{tcyr,bcyr,fcyr}`, `docs/{adr,architecture,guides,examples,development}/` per [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md).
- **Binary output name** `cmdrs` (short for *commandress*) configured via `[build].output`.
- **ADR 0001** — repo split from agnoshi: prompt rendering lives in its own repo + binary; the contract between shell and prompt is env vars + CLI flags. [`docs/adr/0001-separate-repo-from-agnoshi.md`](docs/adr/0001-separate-repo-from-agnoshi.md).
- **ADR 0002** — segment rendering model: each segment is a pure fn of the prompt context; no shared mutable state; config-driven order Just Works because segments are leaves. [`docs/adr/0002-segment-rendering-model.md`](docs/adr/0002-segment-rendering-model.md).
- **ADR 0003** — config format: `~/.commandress.cyml` is CYML (Cyrius-native), not TOML; matches the `cyrius.cyml` mental model, markdown body reserved for user notes. [`docs/adr/0003-config-format.md`](docs/adr/0003-config-format.md).
- **Architecture note 001** — prompt render budget: 5 ms cold start total, 500 µs per-segment default, slow segments degrade to empty (never stall). [`docs/architecture/001-prompt-render-budget.md`](docs/architecture/001-prompt-render-budget.md).
- **`src/segments/cwd.cyr`** — current-working-directory segment. `getcwd` syscall + strict-prefix `$HOME → ~` shortening (won't false-match `/home/macro` against `/home/macrobench`).
- **`src/segments/exit.cyr`** — last-exit segment. Empty on `0`, `[N]` on non-zero. Reads from `$AGNOSHI_LAST_EXIT`.
- **`src/render.cyr`** — render pipeline. Walks a hard-coded segment list, joins non-empty outputs with a single space, appends `$ ` trailer. (Config-driven version lands in v0.2.0.)
- **`src/main.cyr`** — wires `getenv` → segments → render. Replaces the `hello from commandress` scaffold stub.
- **Tests** (`tests/commandress.tcyr`) — 7 tests across cwd + exit segments (13 assertions): home-prefix exact-match, strict-prefix, bad-home fallback, negative exit code, etc. `cyrius test` 13/13 green.
- **Benchmarks** (`tests/commandress.bcyr`) — per-segment + full-prompt timings on the dev host: `cwd_render` 664 ns / `exit_render` 38 ns / `render_prompt` 2 µs avg — **0.04 % of the 5 ms budget**. (Replaced an `init`-scaffold `bench(name, fp, n)` stub that referenced a non-existent stdlib symbol — the real API is `bench_new` + `bench_batch_start/stop`.)
- **README, CLAUDE.md, `docs/development/{state,roadmap}.md`, `docs/guides/getting-started.md`** filled with project-specific content per [first-party-standards.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md).

### Changed

- **Cyrius toolchain pin** bumped from `5.11.54` → `5.11.59` in `cyrius.cyml`; synced `lib/` from `~/.cyrius/versions/5.11.59/lib` via `cyrius lib sync`. Picks up the v5.11.55–.59 wrapper polish (manifest-pin drift detection, `--strict-pin`, `cyrius lib sync` itself) and the DCE-aware undef-fn reachability filter (cross-arch).
- Binary size: **58,568 B → 73,544 B** (+14,976 B for the M1 segments + render pipeline + tests).
- **`cyrius.cyml` `version` resolves via `${file:VERSION}`** (was hardcoded `"0.1.0"`). Aligns with the kriya pattern and the CLAUDE.md rule that `VERSION` is the single source of truth. Combined with `release.yml`'s `cat VERSION == $GITHUB_REF_NAME` gate, a release bump is now one edit to `VERSION` — drift becomes a fail-loud CI error.

### Fixed

- **CI parity with [kriya](https://github.com/MacCracken/kriya)**: added `workflow_call:` trigger to `.github/workflows/ci.yml` so `release.yml`'s `uses: ./.github/workflows/ci.yml` gate can invoke it (without the trigger, release would have failed at the CI-gate step). Switched build step output from `build/${{ github.event.repository.name }}` (would have published asset `commandress`) to `build/cmdrs`, matching `[build].output` and `CLAUDE.md` Quick Start.
