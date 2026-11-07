# commandress — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.3.0** — 2026-11-06. **Hex and 256-colour values**, the two forms ADR 0007 reserved, and right-prompt powerline transitions that point the right way. Additive, with the left prompt byte-identical. The suite now runs `render_prompt`.

**1.2.3** — 2026-11-06. Prior: **P(-1) audit, hardening, optimization and security sweep.** [The report](../audit/2026-11-06-audit.md) records 2 HIGH, 6 MEDIUM, 20 LOW and 5 INFO fixed. Both shell adapters could run commands from a directory name under option states stock software sets (T-01, T-02), now closed by keeping the bytes out of the prompt variable ([ADR 0011](../adr/0011-prompt-holds-a-reference-not-the-bytes.md)). The C1 filter could be bypassed and a repo could drive a real VTE (T-03), and it now holds an invariant on its output. The lock guard is replaced (SC-01, SC-02), CI runs the shipped binary (SC-03) and proves the adapters on real shells. The cache is bounded by construction ([ADR 0012](../adr/0012-cache-bounded-by-construction.md)). `--agnos` booted on a real kernel for the first time, and works. Cold start falls from 402 to **295 µs** on a THP `always` host. Toolchain, deps, schema and output format are unchanged.

**1.2.2** — 2026-11-06. Prior: quick roadmap items: the djb2 cache collision fixed, `rust-toolchain.toml`, `budget_ms`, a powerline theme, dead-code elimination on every build.

## Role

Structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) (and eventually bash/zsh). Binary name: `cmdrs`. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius.

## Toolchain

- **Cyrius pin**: `6.7.18` (in `cyrius.cyml [package].cyrius`)

## Source

| Module | Status |
|---|---|
| `src/main.cyr` | **M1 + cmdit (1.1.5)** — builds the cmdit handle, handles `--help` / `--version`, loads config, builds Context, dispatches to `render_prompt(cfg, ctx, side)`. No longer calls `args_init()` (cmdit_argv does, and it is not idempotent — 2 MB per call) |
| `src/cli.cyr` | **1.1.5** — the CLI surface, extracted from `main.cyr` so it is testable (`main.cyr` ends in a bare `_agnos_entry();` and cannot be included). `cmdrs_version()` (the compiled-in version literal, asserted against the `VERSION` file by the suite), `cli_register(cli)` (registers `--side` as a `cmdit_enum` over `left\|right`), `cli_side_for(cli, f, pr)` (the degrade policy: any non-clean parse → left prompt, never a non-zero exit). Per [ADR 0008](../adr/0008-cli-parsing-via-cmdit.md) |
| `src/config.cyr` | **M1 + M3 (0.4.0) + M5 (0.6.0–0.6.1) + bayan (1.1.9)** — CYML loader for `~/.commandress` (renamed from `~/.commandress.cyml` per ADR 0006). Schema: `[[prompt]]` (segments, right_segments, separator, trailer, separator_style, separator_glyph, right_separator_glyph) + `[[segments.cwd]]` (home_shorten, max_length, fg/bg/style) + `[[segments.exit]]` (hide_zero, fg/bg/style) + `[[segments.vcs]]` (show_dirty, dirty_marker, fg/bg/style) + `[[segments.time]]` (format, fg/bg/style) + `[[segments.{hostname,user,cyrius_env,python_env,node_env,rustup_env}]]` (fg/bg/style only) + optional `[[palette]]` (named-slot table referenced via `fg = "palette:<name>"`). Per-segment storage: pre-baked SGR cstring + raw bg cstring (the latter only used by powerline transitions). Defaults baked in (including opinionated default theme); partial-override-safe; missing file → defaults; unknown fields warn to stderr. `CFG_SIZE` 272 B. **1.1.9**: parsed by bayan's sublibs per [ADR 0009](../adr/0009-config-parsing-via-bayan.md). `_section_pairs` keeps "first populated section wins", `_load_palette` keeps dotted palette names resolvable, and `_warn_nested_keys` keeps unknown dotted fields warning |
| `src/context.cyr` | **M1 (0.2.0)** — `{ home, last_exit }` per-invocation context handed to every segment dispatcher. `thp_opt_out()` (1.2.3) runs first in `main` |
| `src/render.cyr` | **M1 + M3 (0.4.0) + M4 (0.5.0) + M5 (0.6.0–0.6.1)** — table-driven registry (name → dispatcher fn ptr). `render_prompt(cfg, ctx, side)` paints either `cfg.segments` (side=0) or `cfg.right_segments` (side=1); left side appends `cfg.trailer`, right side skips it. Each painted segment wraps in its pre-computed SGR opener + `\x1b[0m` reset; emits raw when SGR is 0. **Plain mode** (default): segments joined by `cfg.separator`. **Powerline mode** (`cfg.separator_style == 1`): adjacent segments separated by `<fg=prev_bg; bg=next_bg>` SGR + glyph + reset; trailing transition (`fg=last_bg; bg=default`) closes the chain when last segment has a bg. `_sgr_for(cfg, name)` and `_bg_for(cfg, name)` mirror `_seg_fn_for` for SGR / raw-bg resolution. Unknown segments warn to stderr (name sanitized since 1.1.6 — audit P-02). **1.1.6**: every stdout write goes through `_emit`, which loops on partial writes and retries EINTR (audit P-03) |
| `src/shellout.cyr` | **M3 (0.4.0) + hardened (1.1.6, 1.2.3)** — generic per-call timeout watchdog. `shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen)` returns bytes / `-1` / `-2`. Epoll deadline, `EINTR` retried, `SIGKILL` on every exit, and `_shellout_reap` never blocks. See [architecture 002](../architecture/002-shellout-watchdog.md) |
| `src/cache.cyr` | **M6 (0.7.0) + agnos degrade (1.1.4) + slots (1.2.3)** — per-segment probe cache in `/tmp/commandress-<uid>/`. 256 slots per segment, with the 64-bit FNV-1a key inside the entry, so it cannot grow without bound ([ADR 0012](../adr/0012-cache-bounded-by-construction.md)). `cache_init()` verifies the directory is ours and 0700 (F-3, A-11). `cache_get` reads everything through one `O_NOFOLLOW` fd. `cache_put` is temp+rename. Disabled on agnos |
| `src/pathlookup.cyr` | **M4 (0.5.0)** — `find_in_path(name)` walks `$PATH`, returns the first heap-alloc'd absolute-path cstring that passes `access(X_OK)` (or 0). Lifted from `src/segments/vcs.cyr` once `cyrius_env` became a second shellout consumer. Still pending Cyrius v6.x Item 8 upstream |
| `src/fslookup.cyr` | **M4 (0.5.0) + one walk (1.2.3)** — shared fs helpers used by every language-env segment. `find_ancestor_with_either(start_dir, marker, marker2, which)` walks upward with one buffer, absolute paths only, up to `ANCESTOR_DEPTH_MAX` (128) levels. `read_regular_file` refuses FIFOs and devices (A-01). `read_trimmed_file_at` and `trimmed_copy` read and trim pin files |
| `src/color.cyr` | **M5 (0.6.0)** — ANSI SGR helpers. `color_to_sgr_fg(name)` / `color_to_sgr_bg(name)` map the 16 named colours (8 standard + 8 bright) + `"default"` to SGR ints (30..37 / 90..97 fg; bg = fg + 10; 0 for absent/default/unknown). `style_to_sgr_mods(s, codes, max)` parses space-separated tokens (bold / italic / underline / reverse) writing mod codes as i64s. `sgr_open_for(fg, bg, style)` composes the `"\x1b[<mods>;<fg>;<bg>m"` opener, returns 0 when nothing to emit. `SGR_RESET` is `"\x1b[0m"`. Render closes every styled segment with `SGR_RESET` so terminal-defaults aren't leaked between segments. `_sanitize_bytes` (1.2.3) is the one output filter: no C0, no DEL, and a byte in `0x80..0x9F` only inside a well-formed sequence for a code point at or above U+00A0. `_color_spec` (1.3.0) parses a color in any form, and `_emit_color` formats it from integers |
| `src/segments/cwd.cyr` | **M1 + M5 (0.6.0)** — `getcwd` + optional `$HOME` → `~` shortening (strict-prefix only) + optional `max_length` truncation at `/` boundaries (`_truncate_cwd` helper: walks left→right for earliest `/` whose suffix fits `max_length - 3`; pathological `< 4` emits a row of `.` dots; no-qualifying-`/` falls back to `...` + raw tail) |
| `src/segments/exit.cyr` | M1 — empty on 0, `[N]` otherwise; `hide_zero = false` paints `[0]` too |
| `src/segments/vcs.cyr` | **M2 (0.3.0) + watchdog (0.4.0) + pathlookup lift (0.5.0) + cache (0.7.0)** — getcwd → `cache_get("vcs", cwd, 1)` short-circuit. On miss: shells out to `sit status` via `shellout_capture` (5 ms budget), parses `On branch <name>` + dirty/clean substring, caches the result (including `""` for no-output cases so the next redraw also skips the fork). 1 s TTL means rapid redraws within a single keystroke burst share one fork+exec. `[[segments.vcs]] budget_ms` overrides the 5 ms budget, whole ms from 1 to 1000 (1.2.2) |
| `src/segments/time.cyr` | **M3 (0.4.0)** — strftime-subset formatter (`%H %M %S %Y %y %m %d %%`; unsupported specs pass through literal). UTC via `CLOCK_REALTIME`; local-time / `TZ` is a future slot. Default format `"%H:%M"`; config-overridable via `[[segments.time]] format = ...` |
| `src/segments/hostname.cyr` | **M3 (0.4.0)** — `uname(2)` nodename. One syscall, no config knobs |
| `src/segments/user.cyr` | **M3 (0.4.0)** — `getuid()` + `lib/pwd.cyr` direct /etc/passwd reader (musl-style; no glibc NSS). Falls back to `$USER`, then empty. No config knobs |
| `src/segments/cyrius_env.cyr` | **M4 (0.5.0)** — Cyrius project segment. Walks ancestors for `cyrius.cyml`, reads `<root>/VERSION`, falls back to `cyrius --version` shellout (5 ms budget). Emits raw version string. Per [ADR 0005](../adr/0005-language-env-probe-pattern.md) |
| `src/segments/python_env.cyr` | **M4 (0.5.0)** — Python project/venv segment. `$VIRTUAL_ENV` basename first, else `.python-version` ancestor walk + read+trim. `python --version` shellout deferred pre-v1. Per ADR 0005 |
| `src/segments/node_env.cyr` | **M4 (0.5.0)** — Node project segment. `.nvmrc` ancestor walk + read+trim. Passes numeric (`20.11.1`) and channel-style (`lts/iron`) content verbatim. `package.json engines.node` + `node --version` shellout deferred. Per ADR 0005 |
| `src/segments/rustup_env.cyr` | **M4 (0.5.0) + TOML (1.2.2)** — Rust toolchain segment. Follows rustup's search: the nearest directory holding `rust-toolchain` or `rust-toolchain.toml` wins, and `rust-toolchain` wins a tie. Reads `[toolchain] channel`, or the legacy one-line format, deciding by content under the extensionless name. **Repo-controlled parser input**, so bounded by `RUSTUP_FILE_CAP` (4 KB) and `RUSTUP_CHANNEL_MAX` (255 B), through `read_regular_file`. `rustup show` shellout deferred per file-first policy, opt-in on the roadmap's 1.4.x line. Per ADR 0005 |

## Binary

- `cmdrs` (output in `build/cmdrs` after `cyrius build`)
- Size: **158,016 B** on Cyrius 6.7.18, x86_64, up from 158,000 B at 1.2.3 by **+16 B**: the colour parser, with `color_to_sgr_bg` now dead code.
- Prior: **158,000 B** on Cyrius 6.7.18, x86_64 (text 150,599 B; bss 4,184 B), up from 153,808 B at 1.2.2 by **+4,192 B (+2.7 %)**: the UTF-8 filter, the cache slots and the shellout and walk repairs.
- Prior: **153,808 B** on Cyrius 6.7.18 at 1.2.2, x86_64 (text 145,987 B; bss 4,136 B), down from 313,392 B at 1.2.1 by **−159,584 B (−50.9 %)**: dead-code elimination is on for every build ([ADR 0010](../adr/0010-dead-code-elimination-on-every-build.md)). Live code grew +4,256 B for 1.2.2's features. `--agnos`: **145,928 B** (text 139,488 B; bss 4,560 B), down from 317,808 B.
- Prior: **313,392 B** on Cyrius 6.7.18 at 1.2.1, before DCE, x86_64 (text 308,614 B; bss 4,104 B), up from 309,200 B at 1.2.0 by **+4,192 B (+1.4 %)**. Live code under `CYRIUS_DCE=1`: 149,552 B. Unreachable: 676 fns, 165,267 B. `--agnos`: **317,808 B** (text 311,395 B; bss 4,528 B), up from 309,384 B.
- Prior: **309,200 B** on Cyrius 6.7.9 at 1.2.0, x86_64 (text 301,382 B; bss 4,144 B), up from 287,672 B at 1.1.9 by **+21,528 B (+7.5 %)**, of which +13,336 B is live code. Live code under `CYRIUS_DCE=1`: 145,360 B. Unreachable: 651 fns, 163,500 B. `--agnos`: **309,384 B** (text 301,475 B; bss 4,432 B), up from 287,848 B.
- Prior: **287,672 B** on Cyrius 6.6.20 at 1.1.9, x86_64 (text 279,896 B; bss 3,600 B), up from 211,784 B at 1.1.8 by **+75,888 B (+35.8 %)**. Of that, +43,056 B is the toolchain and stdlib (+39,202 B unreachable) and +32,832 B is bayan (+20,544 B live). Live code under `CYRIUS_DCE=1`: 132,024 B, up from 105,288 B. `--agnos`: **287,848 B** (text 280,125 B; bss 3,880 B), up from 207,608 B.
- Prior: **211,768 B** on Cyrius 6.5.35 at 1.1.5, x86_64 (text 205,540 B; bss 2,848 B). Up from 168,264 B by **+43,504 B (+25.9 %)** at the 1.1.5 cmdit adoption — the cost of the dependency, accepted with the cost measured ([ADR 0008](../adr/0008-cli-parsing-via-cmdit.md)). `--agnos`: **203,464 B** (text 199,939 B; bss 2,800 B).
- Prior: **168,264 B** (text 162,839 B; bss 2,544 B) at 1.1.4, up from 147,600 B by **+20,664 B (+14.0 %)** — attributable to the **vendored stdlib snapshot, not codegen**: the local wrapper was already `cycc 6.5.35` before the bump (that was the drift), so the pre-bump baseline built the same `src/` with the same compiler against the old `lib/` and measured 147,600 B (text 143,049 B; bss 2,464 B). Roughly half the growth is unreached code — the build's dead-code note moves from `318 unreachable fns (58,189 B)` to `384 unreachable fns (69,382 B)`, all eliminable with `CYRIUS_DCE=1`. Net win vs the 0.3.0 baseline (395,115 B) is still **−226,851 B**.
- `--agnos` cross-build stays clean, and **boots**: verified on kernel 1.57.17 with agnsh 2.2.0 (**150,144 B** at 1.3.0; 150,128 B at 1.2.3; 145,928 B at 1.2.2 with DCE; 317,808 B at 1.2.1; 309,384 B at 1.2.0; 287,848 B at 1.1.9; 203,464 B at 1.1.5; 164,056 B at 1.1.4). Clean since the 1.1.4 `cache.cyr` fix; Cyrius 6.5.1 made the `sys_stat` arity mismatch a hard error.
- Historical: **147,600 B** on 6.4.66 was the 1.1.3 figure (text 141,329 B; bss 2,464 B), itself down from 210,144 B on 6.2.24. **202,561 B** on Cyrius 5.11.64 (text 143,265 B; bss 59,296 B) was the v1.0.x figure — 200,667 B at the 0.7.0 baseline + **1,894 B** for the M8 audit fixes (F-1 sanitization helper, F-3 cache-dir mode-verify, F-4 O_NOFOLLOW, F-5 atomic temp+rename, F-7 parse_last_exit, F-8 absolute-only PATH walker).

## Benchmarks

Captured 2026-11-06 at 1.3.0 on the dev host (Linux 7.2.14-arch1-1, x86_64). The bench harness subtracts a measured timer floor (~1.408 µs per clock read) from every sample. Since 6.6.x it prints the mean as `min` and `max` when a row cannot resolve them, which is why `vcs_render` reads `min=max` below:

| Operation | Avg | Min | Max |
|---|---|---|---|
| **`cli_parse` (cmdit `--side`)** | **1.094 µs** | **995 ns** | **1.409 µs** |
| `cwd_render` | 757 ns | 718 ns | 848 ns |
| `exit_render(nonzero)` | 39 ns | 37 ns | 48 ns |
| `config_default` | 3.479 µs | 3.326 µs | 3.853 µs |
| **`config_load` (largest theme)** | **68.720 µs** | **66.324 µs** | **72.607 µs** |
| `vcs_parse_render` (pure parser) | 207 ns | 200 ns | 218 ns |
| **`vcs_render` (cached, 1s TTL)** | **8.381 µs** | **8.381 µs** | **8.381 µs** |
| `cyrius_env_parse_version` (pure parser) | 80 ns | 78 ns | 87 ns |
| `cyrius_env_render` (file path, no shellout) | 7.198 µs | 6.877 µs | 7.629 µs |
| `python_env_basename` (pure parser) | 115 ns | 108 ns | 124 ns |
| `python_env_render` (empty walk) | 10.404 µs | 10.097 µs | 11.746 µs |
| `node_env_render` (empty walk) | 4.990 µs | 4.909 µs | 5.393 µs |
| `rustup_env_render` (empty walk) | 9.177 µs | 8.981 µs | 9.549 µs |
| `rustup_env_parse_toml` (pure parser) | 2.150 µs | 2.001 µs | 3.186 µs |
| `render_prompt (default cwd+vcs+exit)` | 11.682 µs | 11.489 µs | 12.044 µs |

**Real cold start** on this host, THP `always`: **295 µs** with no config, **485 µs** with the largest theme, against the 5 ms budget, which `scripts/smoke.sh` enforces. Budget: 5 ms cold start total ([`architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)). **M6 headline**: `vcs_render` **4.6 ms → ~9 µs avg** with the 1 s TTL cache (on harnesses that resolve it, the `max` is the one cold call that warms the entry; the remaining reads in the bench are the average). `render_prompt (default cwd+vcs+exit)` is **11.092 µs** at 1.2.2, with repeat runs from 11.07 to 12.04 µs — even with vcs in the default set, the cold-start budget is **0.2 % consumed**, and the 1.1.4 stdlib refresh moved it by ~0.3 µs (10.553 µs → 10.851 µs), i.e. noise. **1.1.5 note**: `cli_parse` is the cmdit adoption's measured cost — the hand-rolled walk it replaced benched **56 ns**, so this is a ~212× regression in isolation, ~98 % of it `cmdit_new` zeroing a 64-entry flag table for one flag. It sits **outside `render_prompt`** (which takes `side` as a parameter), so the gate below is unaffected, and against the ~940 µs the binary really spends per invocation an interleaved A/B of the 1.1.4 and 1.1.5 binaries measured **−15 / +1 / +11 µs** — below the noise floor. Accepted knowingly; see [ADR 0008](../adr/0008-cli-parsing-via-cmdit.md). **Resolved at 1.2.0**: cmdit 1.3.0 zeroes that table a word at a time, taking `cli_parse` from 11.20 µs to 0.99 µs. The bench-gate CI step is wired to fail above 5 ms; comfortable headroom. Per-release numbers append to [`benchmarks/history.csv`](../benchmarks/history.csv) for trend visibility — note that `bench-history.sh` silently recorded nothing between 0.9.0 and 1.1.4 (decimal-average rows failed its skip-filter; fixed in 1.1.4), so the CSV has no rows for the releases in that span.

## Tests

- `tests/commandress.tcyr` — **513 assertions across 207 tests**, including `render_prompt` byte for byte since 1.3.0: full M1–M7 coverage + the 1.1.9 config-parsing group (12 tests / 23 assertions: the forks' defects, plus the rules `src/config.cyr` keeps across the bayan swap) + the 1.1.5 CLI group (10 tests / 16 assertions over `src/cli.cyr`, driven through cmdit's pure `cmdit_parse_argv` core with synthetic argv — side mapping, the space-separated form, both degrade paths, help/version short-circuits, and a version-drift guard asserting `cmdrs_version()` equals the `VERSION` file) + M8 audit-fix additions for `sanitize_segment_output` (8 cases — F-1), cache hardening (2 cases — F-3/F-4/F-5: mode-0o600 stat-verify, symlink-swap refuses), `parse_last_exit` (6 cases — F-7), and `find_in_path_with` (3 cases — F-8 relative-rejected / dot-rejected / absolute-resolves-including-mixed). `cyrius test` green.
- `tests/commandress.bcyr` — per-segment + config + parser + full-prompt timings (above).
- `tests/commandress.fcyr` — fuzz stub (no harness yet).
- `scripts/smoke.sh` — runs the shipped binary on hostile input and takes a real cold start (1.2.3).
- `scripts/adapter-check.sh` — proves both adapters on real zsh and bash, 111 checks (1.2.3).
- `scripts/lock-check.sh` — regenerates `lib/` and the lock from the pins in a throwaway worktree of HEAD (1.2.3).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `args`, `bench`, `chrono`, `fnptr`, `process`, `pwd`, `tagged`, `result`, `hashseed`. `args` + `bench` were declared at 1.1.5, the next five at 1.1.7, `result` at 1.1.9 and `hashseed` at 1.2.1: all were already compiled in via includes, and an undeclared module is one `cyrius deps` never refreshes.
- **cmdit** `1.5.0` — first-party AGNOS CLI / argument-parsing distlib, `[deps.cmdit] modules = ["dist/cmdit.cyr"]`, pinned by git tag (`path = "../cmdit"` stays commented out; since cyrius 6.7.6 only `CYRIUS_LOCAL=1` uses it). commandress's **first non-stdlib dependency**, adopted at 1.1.5 per [ADR 0008](../adr/0008-cli-parsing-via-cmdit.md). Compiled in; the binary stays static, and no runtime dependency is added.
- **bayan** `1.11.1` — first-party AGNOS data-format library, `[deps.bayan] modules = ["dist/bayan-toml.cyr", "dist/bayan-cyml.cyr"]`, pinned by git tag per [ADR 0009](../adr/0009-config-parsing-via-bayan.md). The sublibs, not the bundle in the snapshot. 1.11.1 is the newest tag and the one the 6.7.18 snapshot bundles; its own pin is 6.7.16. The tag moves with the toolchain.

The declared `[deps]` surface is stable across releases; the **vendored `lib/` snapshot** is re-synced to the pinned toolchain per refresh (`cyrius lib sync --full`). Last resync: **1.2.1 → the 6.7.18 pin** (66 stdlib files updated, none added or removed). `lib/` is now exactly the snapshot plus `cmdit.cyr`, `bayan-toml.cyr` and `bayan-cyml.cyr`; the ten leftovers no snapshot shipped were removed at 1.1.9. A stale snapshot surfaces at build time as a `./lib/ shadows version-pinned …/lib — N bundled lib(s) differ` warning — the signal to re-sync. Note `cyrius deps` alone does **not** refresh the snapshot; it resolves declared `[deps]` and writes `cyrius.lock`. The order on a pin move matters: see [architecture 003](../architecture/003-cyrius-lock-shape.md).

External (non-AGNOS, third-party): none, and none planned. The 1.1.5 cmdit adoption is a *first-party AGNOS source* dep — vendored, tag-pinned, compiled in — which ADR 0008 admits as a distinct category from the runtime deps that stay forbidden. `cyrius.lock` (119 entries, 1 commit-pinned) is committed as of 1.1.5.

## Consumers

- [agnoshi](https://github.com/MacCracken/agnoshi) — planned (prompt-hook integration via `AGNOSHI_PROMPT_CMD=cmdrs` once M1 lands)

## In-flight work

> **Planned work lives in [`roadmap.md`](roadmap.md)**, sequenced into 1.3.1 → 1.5.x with
> each item pinned to the source line that defers it. This section is *state* — what is
> true right now — not a second copy of the plan. It was both until the 2026-08-26 doc
> sweep, and the two copies had drifted.

- **agnoshi adoption pending, and it needs one change here**: agnos has no `getcwd`, so every cwd-based segment is empty there until `cmdrs_getcwd` reads `$PWD`. `/home/macro/Repos/agnoshi/src/prompt.cyr` still renders its own prompt. When agnoshi reads `$AGNOSHI_PROMPT_CMD` per redraw (5-point contract in `adapters/agnoshi.sh`, including the F-12 no-re-expand rule), sourcing the adapter yields a commandress-rendered prompt with **no commandress change required**.
- **Upstream gates, with the date each was last checked** — a gate is a claim about the world and it expires:
  - **Cyrius Item 3 (single-bracket TOML) — CLOSED.** Re-tested 2026-08-26 against the 6.5.35 stdlib: `toml_get_sections` finds a single-bracket `[toolchain]`, and the config loader reads `[prompt]` end to end (pinned by `test_config_accepts_single_bracket_sections`). This had been carried as a blocker in two source files and the roadmap; `rust-toolchain.toml` is now scheduled work, not blocked work.
  - **Cyrius Item 8 (no stdlib `which()`) — still open.** Re-checked 2026-11-06 against 6.7.18: no public stdlib fn resolves a bare name against `$PATH`. `src/pathlookup.cyr` remains correct and shipping.
  - **Cyrius Item 4 (LSP transitive-include false positives on `src/render.cyr`) — still open.** The editor reports undefined `SGR_RESET` / `sgr_open_for` / `bayan_toml_*` when analysing the file standalone; the build is clean. Noise, not a defect.
- **`cyrius deps --locked` still exits 0 on a stale pin**, printing a `note:`. `scripts/lock-check.sh` catches it by regenerating, so this repo does not depend on it. Pinned upstream on the roadmap.
- **Single-bracket `[section]` config** is supported and documented in the getting-started guide. `[[section]]` stays canonical, because every theme and example uses it. The suite pins both.
- **Real GitHub CI has not run the 1.2.3 workflows.** They were rehearsed in a fresh clone. `smoke.sh`'s 5 ms threshold is unvalidated on a runner.

## Next

See [`roadmap.md`](roadmap.md).
