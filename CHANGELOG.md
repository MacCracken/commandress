# Changelog

All notable changes to commandress will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.5.0] - 2026-11-06

A repo can no longer reach a file it does not contain through a symlinked pin. Pin files are read the way the
tools read them, and every segment takes `max_length`, on by default at 128 bytes wherever a repo or the
environment chooses the text. The toolchain and dependencies are unchanged. Decision and measurements:
[ADR 0015](docs/adr/0015-pins-keep-their-name-and-shape.md).

**The roadmap's fix was not enough.** It proposed one shape rule for the symlinks and the length. A pin can
legally be any bare word, such as a pyenv virtualenv name, so no shape rule can tell one from a one-word token
file, and 1.4.1 showed such a file in full. It also showed the start of the environment through
`/proc/self/environ`, which the audit had not listed.

### Breaking

No config stops working. These change what renders, and only for unusual values:

| What | Before | Now | To change it |
|---|---|---|---|
| Branch, `VIRTUAL_ENV` name or range over 128 bytes | Shown whole | Cut, ending in `...` | `max_length = 0` on that segment |
| Pin symlinked to a file of another name | Followed | Empty | Rename the target, or use a real file |
| Pin over 64 bytes, or with characters outside the version alphabet, such as non-ASCII | Shown | Empty | Use a shorter or ASCII name |
| `VERSION` that is not a pin, in a Cyrius project | The toolchain's version | Empty | Fix the file, or remove it to fall back |
| `engines.node` that does not read as a semver range | Shown | Empty | Fix the value |
| `[[segments.cwd]] max_length = "10x"` | Acted as 10, silently | A warning, and no limit | Use a whole number |

### Security

- **A symlinked pin must end at a file of the same name.** This covers `.python-version`, `.nvmrc`, `VERSION`,
  `package.json`, `rust-toolchain` and `rust-toolchain.toml`, and closes T-05 from the
  [2026-11-06 audit](docs/audit/2026-11-06-audit.md).
  - `.nvmrc -> ../.nvmrc`, `~/.nvmrc -> ~/dotfiles/nvmrc` and `rust-toolchain -> rust-toolchain.toml` still
    work, and `.nvmrc` may end at `.node-version`.
  - A token file, a key, a `.env`, `/proc/self/environ` and any chain of links ending in one all render empty.
  - `~/.commandress` is the user's own file, so a dotfile manager can still link it from anywhere.
- **Text a hostile repo can put in a default prompt drops from 8,182 bytes to 128.** A pin is at most 64.
- **A pin is ASCII**, so it cannot carry a bidi override or other Unicode lookalike.
- **`engines.node` must read as a semver range**, so it can no longer spell a sentence.
- **Not fixed here:** `sit` follows a symlinked `.git` or `.sit/HEAD`, so a repo can show the branch name of
  another repo it can name a path to. That fix belongs in `sit`, and it is on the roadmap.

### Added

- **`max_length` on every segment**, in bytes, `0` for no limit. It defaults to 128 on `vcs`, `cyrius_env`,
  `python_env`, `node_env` and `rustup_env`, and to no limit on `exit`, `time`, `hostname` and `user`. A cut keeps
  the head, ends in `...`, stays on a character boundary, and keeps the dirty marker.
- **Benchmarks:** `pin_word`, `cap_output`.

### Fixed

- **A pin is the first word of its first meaningful line**, as pyenv and nvm read it. Two versions on two
  lines rendered `3.12.13.11.4`, and a comment above a version rendered `# pinned3.12.1`.
- `#` ends a word and `key=value` lines are skipped, so `.nvmrc` files with `20#pinned` or `foo=bar` read as
  nvm reads them.

### Changed

- `[[segments.cwd]] max_length` warns on a bad value, as its siblings do. Good values read as before.
- A file over the 256-byte pin read cap counts only up to its last whole line, because a cut word is a wrong
  version.

### Performance

| | 1.4.1 | 1.5.0 | Delta |
|---|---|---|---|
| Cold start, no config | 300 µs | 302 µs | flat |
| Cold start, largest theme | 530 µs | 533 µs | flat |
| Cold start, three plain pins | 352 µs | 354 µs | flat |
| Cold start, two pins symlinked under their own name | 361 µs | 386 µs | +25 µs, in those directories only |
| `pin_word` | — | 544 ns | new |
| `cap_output`, 8 KB to 128 | — | 2.44 µs | new, only when it cuts |
| `render_prompt` | 10.77 µs | 11.35 µs | +0.58 µs, not visible in a cold start |
| `config_load`, largest theme | 60.3 µs | 62.2 µs | +1.9 µs |
| Binary, x86_64 | 186,424 B | 198,872 B | +12,448 B (+6.7 %) |
| Binary, `--agnos` | 186,752 B | 195,088 B | +8,336 B (+4.5 %) |

Medians of 2,500 interleaved pairs, and lowest mins of 5 alternating bench runs at equal path depth, because
other work was running on the host. Absolute figures are not comparable with earlier entries.

### Tests

- 951 assertions across 284 tests, from 719 across 254.
- 264 mutations, all caught. That includes each segment reading another's `max_length`, each reader skipping
  the symlink rule, and a write in front of the output buffer that still returned the right string. The whole
  alphabet is checked byte by byte.
- An independent review found what the first pass missed: `engines.node` could spell a sentence, a comment that
  filled the read cap turned `3.11.4` into `3`, legal `uv` and `nvm` forms rendered wrongly, `cyrius_env`
  presented the toolchain's version as the project's, and six tests could not fail. Each got a failing test
  first.
- 30,000 hostile repos with canary files and every symlink route to them: no canary on stdout, and every word
  shaped like a pin. The same fuzz leaks the canary in 794 of 2,000 runs on 1.4.1.
- 15,000 hostile branch names through random `max_length` values: never over the limit, no control byte. 6,877 of
  them were cut.
- 20,000 hostile repo files, 10,000 hostile tool outputs and 40,000 mutated configs: no violation, no crash.
- All 2,114 real `engines.node` values render unchanged through the binary.
- Differential 1.4.1 → 1.5.0: of 6,163 cases, 352 are `--version`, and the other 264 are the three hostile
  fixtures, each losing its hostile text. No output grew.

## [1.4.1] - 2026-11-06

`python_env`, `node_env` and `rustup_env` can ask the tool for its version when no pin file answers. Off by
default, and nothing changes with it off. The toolchain and dependencies are unchanged. Decision and
measurements: [ADR 0014](docs/adr/0014-version-probes-never-see-the-repo.md).

**The roadmap's plan was not built.** It asked for the tool to run in the cwd behind the 1 s cache. In a
hostile directory `rustup show active-toolchain` tried to download a toolchain the repo named, and
`rustc --version` ran a binary from the repo. `python` and `node` are often shims that read the repo too.
And at 5 to 15 ms against a 5 ms budget, a cache that expires between prompts would not have helped.

**A probe reports the machine's version, not the project's.** A project pinned some way this repo does not
read, such as `.tool-versions`, `.node-version` or a Volta pin, shows the machine's version.

### Added

- **`shellout = true` on `[[segments.python_env]]`, `[[segments.node_env]]` and `[[segments.rustup_env]]`**,
  with `budget_ms` (1 to 1000, default 50). They run `python3 --version` (then `python`), `node --version`
  and `rustup show active-toolchain`.
  - **Runs from `/`, with a fixed environment.** No `HOME`, no `PATH`, and `RUSTUP_AUTO_INSTALL=0`, plus
    `RUSTUP_HOME` when it is an absolute path, so a moved rustup home is still found. The tool has nothing
    of the repo's to act on, and a shim has nothing to read.
  - **Cached per tool for 60 s**, failures included, so one prompt a minute pays and a stalling tool costs
    one budget a minute. The entry is claimed before the tool runs, so a cache that cannot be written
    stops the probe rather than running the tool on every redraw.
  - **Only with no pin file and a project marker**: `pyproject.toml` or `requirements.txt`, `package.json`,
    `Cargo.toml`. A pin file stops the probe even if it names nothing, such as an empty `.nvmrc` or a
    `path` toolchain, because the machine's default may be wrong there.
  - **Output must look like a version**: at most 64 characters of `[0-9A-Za-z.+_-]`, starting with a digit
    for Python and Node, and followed by rustup's bracketed reason for rustup. Anything else renders empty,
    before it reaches the sanitizer.
  - `rustc --version` is never used.
- **`src/probe.cyr`**, and `shellout_capture_in`, which runs a child in a given directory and refuses to run
  it if it cannot get there.
- **Benchmark:** `probe_run (cached)`.

### Changed

- **`cyrius_env` keeps running `cyrius --version` in the cwd.** That tool refuses a pin that is not a plain
  version, and showing the pinned toolchain is what the segment is for.
- **A shellout child's stdin is now `/dev/null`**, for `sit` and `cyrius` too, so a tool cannot read what the
  user is typing ahead.
- **`cache_put` reports whether the entry landed.**

### Performance

| | 1.4.0 | 1.4.1 | Delta |
|---|---|---|---|
| Cold start, no config | 280 µs | 280 µs | flat |
| Cold start, largest theme | 477 µs | 482 µs | flat |
| Cold start, three language segments, probes off | 372 µs | 372 µs | flat |
| Cold start, three probes on, all cached | — | 448 µs | +109 µs against the same render with them off |
| First prompt of a minute, one probe | — | 2 ms `python3`, 9 ms `node`, 5 ms `rustup` | new, opt-in |
| Stalling tool, default budget | — | 51 ms once a minute, then 1 ms | new, opt-in |
| Cache unwritable, stalling tool | — | 1 ms, and the tool does not run | new |
| `probe_run`, cached | — | 5.13 µs | new |
| `render_prompt` | 11.59 µs | 11.38 µs | flat |
| `config_load`, largest theme | 63.7 µs | 63.3 µs | flat |
| Binary, x86_64 | 182,120 B | 186,424 B | +4,304 B (+2.4 %) |
| Binary, `--agnos` | 174,248 B | 186,752 B | +12,504 B (+7.2 %) |

Medians of 2,500 interleaved pairs, and lowest mins of 5 alternating bench runs at equal path depth, because
other work was running on the host. Absolute figures are not comparable with earlier entries.

### Tests

- 719 assertions across 254 tests, from 601 across 234.
- 145 mutations, all caught. That includes running `rustc`, adding `PATH` to the environment, a probe beating a
  pin file, and each segment taking another's budget.
- An independent review found what the first pass of those tests missed: a cache that could not be written
  repeated the stall on every prompt, words such as `not` rendered as versions, and a moved `RUSTUP_HOME` was
  lost. Each got a failing test first, and all of it is fixed above.
- 20,000 hostile tool outputs, each rendered twice. Every word on stdout was a well-formed version and the
  cached render matched. 2,143 of them rendered something, so the check was exercised.
- 40,000 mutated configs seeded with probe sections: no crash, no abort.
- Replayed through the shipped binary: a `path` toolchain, an uninstalled channel, a planted `python3` with `.`
  on `PATH`, a hanging tool, a flood, escape sequences and a background child. All failed, and `~/.rustup` was
  unchanged. Real `python3`, `node` and `rustup` still answer.
- `scripts/smoke.sh` now checks what each probe runs, where, with what, that a pin file stops it, and that each
  segment gets its own budget.
- Differential 1.4.0 → 1.4.1: 6,163 cases, and only `--version` differs. No fixture turns a probe on, so this
  shows nothing changes with them off.

## [1.4.0] - 2026-11-06

`node_env` reads `package.json`. With no `.nvmrc` anywhere above, it shows the nearest `package.json`'s
`engines.node`. The toolchain is unchanged, and bayan stays at 1.11.1 with one more sublib. Decision and
measurements: [ADR 0013](docs/adr/0013-package-json-via-flat-bayan-json.md).

**You may see a new segment.** `node_env` used to be empty without an `.nvmrc`, and it now appears for any
Node project with `engines.node`. It shows a **range** such as `>=18`: what the project asks for, not
what is installed.

### Added

- **`package.json` → `engines.node`.**
  - `.nvmrc` wins from any level above the cwd, however near a `package.json` is.
  - **Only the nearest `package.json` is read.** One with no `engines` stops the search, so a workspace
    package does not show its monorepo root's range. Climbing further would let a hostile tree cost a
    parse per level on every redraw.
  - **This is the second repo-controlled input to reach a parser**, so it is bounded the same way: a 16 KB
    read, FIFO and device files refused, values over 255 bytes rendered empty, and control bytes stripped
    at the existing chokepoint. The worst hostile file measured costs about 1 ms, and only in its own repo.
  - A value containing a backslash renders empty, because values come back as written. None of the 3,955
    real files surveyed has one.
- **Benchmark:** `node_env_parse_package`.

### Changed

- **`bayan-json` joins `[deps.bayan]`**, with the `atomic`, `math` and `slice` stdlib leaves its sidecar
  names. This repo calls only the flat parser, `bayan_json_parse`, which has no number parsing and no
  recursion. The tree parser was measured and rejected at twice the size and nearly twice the worst
  case, and it would have been the first recursion in the binary.

### Performance

| | 1.3.1 | 1.4.0 | Delta |
|---|---|---|---|
| Cold start, default config, no `node_env` | 308 µs | 311 µs | flat |
| Cold start, `node_env`, no Node files | 330 µs | 353 µs | +23 µs, the second walk |
| Cold start, typical `package.json`, 1.2 KB | 328 µs | 359 µs | +31 µs |
| Cold start, large `package.json`, 6.3 KB | 330 µs | 403 µs | +73 µs |
| Cold start, worst hostile file, 16 KB | 355 µs | 1,359 µs | +1.0 ms, in that repo only |
| Cold start, largest theme, no Node files | 507 µs | 528 µs | +20 µs |
| `node_env_render`, no file found | 13.6 µs | 26.7 µs | doubled, the second walk |
| `node_env_parse_package` | — | 7.7 µs | new |
| `render_prompt` | 11.33 µs | 11.22 µs | flat |
| `config_load`, largest theme | 61.8 µs | 60.4 µs | flat |
| Binary, x86_64 | 162,168 B | 182,120 B | +19,952 B (+12.3 %) |
| Binary, `--agnos` | 154,288 B | 174,248 B | +19,960 B (+12.9 %) |

Medians of 2,500 interleaved pairs, and lowest mins of 5 alternating bench runs, because other work was
running on the host. Absolute figures are not comparable with earlier entries.

### Tests

- 601 assertions across 234 tests, from 551 across 221.
- 90 mutations, all caught, including ones that climb past a `package.json` or let it beat `.nvmrc`.
- Every one of 3,955 real `package.json` files reads the same as Python's `json`.
- 100,000 mutated `package.json` files: no crash, no abort, nothing on stderr.
- 60,000 hostile values, with stdout checked by Python's decoder: no control byte reached it. 55 % of those
  values render, and with the sanitizer removed the same fuzz reported over 1,300 violations in 1,500 runs,
  so the zero means something.
- `scripts/smoke.sh` now puts a hostile `package.json` through the shipped binary.
- Differential 1.3.1 → 1.4.0: 6,163 cases, 0 differences. No corpus fixture has a `package.json`, so this
  shows nothing else moved.

## [1.3.1] - 2026-11-06

Multi-palette, the last of the colour work [ADR 0007](docs/adr/0007-schema-freeze.md) reserved at the v1.0
freeze. Additive: with no selector in a config, nothing changes. The toolchain and deps are unchanged.

### Added

- **`[[palettes.<name>]]` tables and a top-level `palette = "<name>"` selector**, so one file can hold
  several colour schemes and switch with a line.
  - **The selected palette overrides `[[palette]]` slot by slot.** A variant only names what it changes,
    and a slot it leaves out keeps its colour. The ADR left this open. Overlaying means a palette that
    forgets a slot cannot lose that colour.
  - **An unknown name warns on stderr and leaves `[[palette]]` in force**, so a typo cannot blank a theme.
    The name is filtered before it is echoed.
  - `palette = ""` selects nothing, and an empty table is a palette that changes nothing.
  - **The selector must sit above the first table.** Below one, TOML makes it that table's key. Under
    `[[prompt]]` or a segment the allow-list warns about it. Under a palette table it is silently a slot
    named `palette`, with no warning, because a slot can have any name.
  - Hex, 256-colour and dotted slots all work in a selected palette, and palette names can hold dots.
  - See [switching between palettes](docs/themes/README.md#switching-between-palettes).

### Performance

| | 1.3.0 | 1.3.1 | Delta |
|---|---|---|---|
| Cold start, no config | 285 µs | 287 µs | flat |
| Cold start, largest theme | 504 µs | 506 µs | flat |
| `config_load`, largest theme | 60.7 µs | 61.5 µs | +1 %: one lookup for the selector |
| `render_prompt` | 11.37 µs | 11.37 µs | flat |
| Text, x86_64 | 152,983 B | 154,153 B | +1,170 B |
| Binary, x86_64 | 158,016 B | 162,168 B | +4,152 B, mostly page rounding as the text crossed a boundary |

### Tests

- 551 assertions across 221 tests, from 513 across 207.
- 79 mutations, all caught. One survived the first run and showed a test claiming more than it covered.
- **Differential 1.3.0 → 1.3.1: 6,163 cases, 0 differences.** No corpus config has a selector, so this shows
  the existing behaviour did not move.
- The example in `docs/themes/README.md` was extracted and run as a config, including its claim about
  which slot falls through.

## [1.3.0] - 2026-11-06

Hex and 256-colour values, the two forms [ADR 0007](docs/adr/0007-schema-freeze.md) reserved at the v1.0
freeze, and right-prompt powerline transitions that point the right way. Additive: no existing config
changes meaning, and the left prompt is byte-identical. The toolchain and deps are unchanged.

### Added

- **Hex and 256-colour values.** `fg = "#8be9fd"` and `fg = "33"` work anywhere a color does: `fg`, `bg`,
  `[[palette]]` slots, and powerline transitions.
  - Hex is `#` and six hex digits, in either case. An index is 1 to 3 digits, 0 to 255.
  - Anything else in those shapes, such as `#abc`, `256` or `33;1`, keeps the behaviour ADR 0007 froze:
    no code, no error.
  - **The value is parsed to integers and formatted again**, so nothing from it is copied into the
    escape, and `33;1` cannot add a parameter.
  - `cmdrs` emits the form you wrote. It does not read `$COLORTERM` or downgrade, so a hex value on a
    terminal without truecolor shows however that terminal chooses.
- **`right_segments = ["time"]` in the powerline theme**, which waited on the fix below.

### Fixed

- **Right-prompt powerline glyphs pointed the wrong way.** With `--side=right` the closing glyph trailed
  the last block, so a left-pointing arrow sat after the text: `01:13<`. A left-pointing glyph is filled
  by the block on its right, so it now opens the first block and joins each pair with those colours
  swapped, and nothing trails: `<01:13`. The left prompt is unchanged.

### Performance

| | 1.2.3 | 1.3.0 | Delta |
|---|---|---|---|
| Cold start, no config | 421 µs | 423 µs | flat |
| Cold start, largest theme | 546 µs | 546 µs | flat |
| `render_prompt` | 12.09 µs | 12.20 µs | +0.9 %, flat |
| `config_load`, largest theme | 66.95 µs | 66.44 µs | flat |
| `sgr_open_for`, named color | 420 ns | 435 ns | about +20 ns a call, for one length check |
| `config_default` | 3.11 µs | 3.36 µs | +0.25 µs: 10 of those calls |
| Binary, x86_64 | 158,000 B | 158,016 B | +16 B |
| Binary, `--agnos` | 150,128 B | 150,144 B | +16 B |

These are p10 cold starts of 3,000 interleaved pairs, and lowest mins of 5 alternating bench runs, because
other work was running on the host. Absolute figures are not comparable with the 1.2.3 entry.

### Tests

- 513 assertions across 207 tests, from 472 across 194.
- **The suite now runs `render_prompt`.** It did not include `render.cyr`, so no test pinned a transition, a
  trailer or the call to the sanitizer. A capture helper asserts its output byte for byte, and the expected
  right-prompt bytes were worked out by hand from how the glyphs draw. Only `smoke.sh` could see that
  chokepoint before.
- 69 mutations, all caught.
- Every byte value in every hex position, and every number from 0 to 999, is checked against the rule.
- Verified on a real parser and a real shell: kitty stored `rgb(139,233,253)` on `palette 200` for those
  values, and zsh's `RPROMPT` went from `01:13<` to `<01:13`.
- Differential 1.2.3 → 1.3.0: 6,163 cases, 0 hangs, 44 differences, all `--side=right` under the powerline
  theme. Config fuzz: 30,000 runs, no crashes.

## [1.2.3] - 2026-11-06

A P(-1) audit, hardening, optimization and security sweep, and its repairs. Five independent reviewers
read 1.2.2, the binary was attacked through real shells and a real VTE, and `--agnos` booted on a real
kernel for the first time. The report is [`docs/audit/2026-11-06-audit.md`](docs/audit/2026-11-06-audit.md).
No config field, flag or output format changed. The toolchain and deps are unchanged.

**If you use a shipped adapter, update it.** Two of these are command execution from a directory name.

### Security

- **The zsh adapter ran commands whenever anything set `prompt_subst` (T-01, HIGH).** 1.1.6 stopped
  setting the option itself, but left the rendered bytes in `PROMPT`, and zsh's own `promptinit` themes
  set it. With stock `prompt adam2`, a directory named `$(touch PWNED)` ran that command on every redraw,
  on the default config.
- **The bash adapter did the same in POSIX mode (T-02, MEDIUM).** POSIX mode ignores `promptvars`, so
  `set -o posix`, or just `POSIXLY_CORRECT=1`, undid 1.1.6's fix.
  - Across 8 payloads in 12 option states on real shells, 31 of 96 cases ran a command on 1.2.2.
  - **The fix**: the bytes no longer go in the prompt variable. They sit in another variable, and
    `PROMPT` / `PS1` hold a fixed reference to it, which the shell expands once and does not re-parse.
    In zsh, everything that touches the bytes runs under `emulate -L zsh`. See
    [ADR 0011](docs/adr/0011-prompt-holds-a-reference-not-the-bytes.md). On 1.2.3, 0 of 120 cases.
- **The C1 filter could be bypassed, and a repo could drive the terminal (T-03, HIGH).** Deleting a byte
  could join its neighbours, so `C2 01 9B` came out as `C2 9B`, which is U+009B, CSI. A directory name
  was enough. On real VTE, which is GNOME Terminal and others, one cleared the screen, set the title and
  made the terminal type replies back into the shell. The filter now makes a promise about its
  **output**, and an exhaustive test holds it to that over 813,615 strings. Two segments can no longer
  form the pair between them either (T-07).
- **A repo could hide its own dirty marker (T-11).** A file named `nothing to commit, working tree clean`
  satisfied a substring scan of real `sit` output. It must now be a whole line.
- **`bash.sh` ran `sed` through `$PATH` on every redraw (T-04).** With `.` ahead of `/usr/bin`, that was
  a `sed` from the repo just entered. The wrap is now pure bash.
- **The lock guard could be walked around (SC-01, SC-02).** One commit could drop a module from the
  manifest, edit it and fix its lock line, and tampered code shipped from a green CI. A deleted lock
  passed too. `scripts/lock-check.sh` now regenerates `lib/` and the lock from the pins in a throwaway
  worktree and compares them. It caught all 37 bad states tried, where the old CI missed 14.
- **The release token sat in `.git/config` while the job ran an installer (SC-04).** Both checkouts now use
  `persist-credentials: false` and are pinned by SHA.
- **Smaller CI hardening.** The toolchain pin must look like a version (SC-07), the installer is saved
  before it runs (SC-06), `ci.yml` has a `permissions:` block (SC-10), and a comment that claimed signature
  verification now says what happens (SC-05).

### Fixed

- **Long lines overwrote the prompt in zsh (T-08).** Colour was not marked zero-width, so zsh counted it
  as columns, and typing past the true margin erased the prompt. It now wraps exactly as bash does.
- **A wedged child could hang the prompt past its budget (R-01).** `waitpid` after `SIGKILL` had no
  deadline, and a child stuck on a dead FUSE mount never finishes dying. One held `cmdrs` for 6 s against
  a 5 ms budget. The reap now gives up after about half a millisecond.
- **A very deep directory stalled every redraw (R-06).** 2,043 levels took four env segments 472 ms. Past
  128 levels the walk no longer starts, and those segments render empty. Now 0.5 ms.
- **`ulimit -f 0` killed `cmdrs` (R-04)**, cutting the prompt short and leaving a temp file per redraw.
- **Starting with stderr or stdout closed broke the child (R-02).** `sit` ran with fd 2 closed, or lost all
  its output.
- **A stop and continue lost the branch (R-03)**, and the empty result was cached for the TTL.
- **The cache could serve a clipped value (R-05)**, and a FIFO at an entry hung.
- **A commented `rust-toolchain` printed itself as the channel (D-01).** This was a 1.2.2 bug. The format
  now follows rustup's own rule: one line is legacy, anything else is TOML. A non-string `channel` renders
  empty (D-02).
- **Exhausting the heap crashed the render (M-01, M-02).** 1.1.6's guard moved the fault to `strlen(0)` on
  the next line.
- Sourcing an adapter twice no longer hooks it twice. In bash that lost the exit status.

### Changed

- **Sourcing an adapter now leaves prompt expansion on**: `prompt_subst` in zsh, `promptvars` in bash. This
  reverses 1.1.6. If your own `PS2` or similar contains `$`, it will expand. If you copied a manual hook
  from the guides, **replace it with the new paste**, because the old ones are vulnerable.
- **A config over 64 KB now warns and uses the defaults (D-03).** It used to be cut at 64 KB and parsed, so
  the keys past the cut vanished silently. The cap itself is unchanged.
- **The cache holds 256 slots per segment, with the key inside the entry**, so it cannot grow without bound
  ([ADR 0012](docs/adr/0012-cache-bounded-by-construction.md)). This replaces the planned eviction. Files
  from older versions stay until reboot or `systemd-tmpfiles`.
- **Bare bytes in `0x80..0x9F` are stripped from segment output**, since they are controls on an 8-bit
  terminal and invalid in UTF-8. Valid UTF-8 and Latin-1 names render as before.
- **`scripts/lock-check.sh` works on HEAD**, so it ignores uncommitted changes. `--no-resolve` is gone.
- **Releases now carry `SHA256SUMS`** (SC-09).

### Added

- **CI runs the shipped binary at last (SC-03).** `scripts/smoke.sh` runs `build/cmdrs` on hostile input and
  takes a real cold start. Until now the suite never ran `src/main.cyr`, so a binary that crashed on its
  first line passed every gate.
- **`scripts/adapter-check.sh`** proves the adapters on real zsh and bash, across 111 checks. They had no
  regression test, which is how T-01 survived. It fails on the 1.2.2 adapters.
- **`scripts/install-toolchain.sh`** replaces two duplicated workflow blocks.
- CI compiles `--agnos`. The step misnamed "Cold-start budget gate" is now "Render budget gate".

### Performance

Cold start on this host, interleaved medians, 3,000 pairs. **The first two rows need THP set to `always`**,
as on Arch and Fedora. On a host set to `madvise`, the 1.2.2 and 1.2.3 figures match.

| | 1.2.2 | 1.2.3 | Delta |
|---|---|---|---|
| Cold start, no config | 402 µs | **295 µs** | −107 µs (−27 %) |
| Cold start, largest theme | 611 µs | **485 µs** | −126 µs (−21 %) |
| Memory at exit | 4,272 KB | **204 KB** | −95 % |
| Cold start, `rust-toolchain` found deep in a tree, THP off | 505 µs | **446 µs** | −59 µs (−12 %) |
| Bash adapter, per redraw | 1,430 µs | **615 µs** | −57 % |
| `rustup_env_render`, no file found | 33.1 µs | 29.7 µs | −10 %, at equal path depth |
| `node_env_render`, no file found | 16.9 µs | 15.6 µs | −8 %, at equal path depth |
| `render_prompt` | 12.41 µs | 12.25 µs | −1 %, with the stricter filter |
| `config_load`, largest theme | 66.3 µs | 66.5 µs | flat |
| Binary, x86_64 | 153,808 B | 158,000 B | +4,192 B (+2.7 %) |
| Binary, `--agnos` | 145,928 B | 150,128 B | +4,200 B (+2.9 %) |

- **Most of the cold-start gain was not in this program's code.** The allocator's 256 MB chunk is aligned to a
  huge page, so the first heap touch made the kernel zero 2 MB, and `args_init`'s 2 MB buffer then moved
  into a second page. One `prctl` before the first allocation removes both.
- The roadmap's suspects in `config_load` were measured and left alone: the 64 KB buffer costs nothing
  measurable, and the eleven sweeps cost 4.4 µs. The audit has the breakdown.

### Tests

- 472 assertions across 194 tests, from 387 across 165.
- **Every fix was proved by undoing it: 48 mutations, all caught**, by the suite, `smoke.sh` or
  `adapter-check.sh`. Three survived the first run and exposed weak tests. One was A-12's guard, which had
  been verified by hand and never pinned.
- Differential 1.2.2 → 1.2.3: 6,163 cases, 0 hangs, 242 differences, all accounted for. 154 are the new
  over-cap warning, and 88 are one fixture, a `rust-toolchain` symlink to `/etc/passwd`, which used to print
  that file into the prompt and now renders empty.
- Fuzz: 40,000 configs, 20,000 argv, and 60,000 hostile repos checked with Python's decoder, with no crashes
  and no violations.

## [1.2.2] - 2026-11-06

The quick roadmap items: a real cache bug fixed, `rust-toolchain.toml` support, a vcs `budget_ms`,
a powerline theme, and dead-code elimination on every build, which halves the binary. The toolchain
and deps are unchanged. The rest of the roadmap is reorganized, with **1.2.3 scheduled as a P(-1)
audit, hardening, optimization and security sweep**.

### Fixed

- **The vcs cache could show another directory's branch.** The key was a 32-bit djb2, whose structure
  makes some collisions certain: `33 * 'a' + 'z' == 33 * 'b' + 'Y'`, so sibling directories `az` and
  `bY` shared an entry. Reproduced on the 1.2.1 binary: 8 redraws of 8 showed the wrong branch. The
  2026-08-26 audit recorded that two directories could share an entry "in principle"; for names of this
  shape it is certain. The key is now a 64-bit FNV-1a,
  pinned to published test vectors, with the same pair at 0 of 8. Pre-1.2.2 entries stay in
  `/tmp/commandress-<uid>/` as orphans until cache eviction lands.

### Added

- **`rust-toolchain.toml`.** `rustup_env` now reads `[toolchain] channel`, following rustup's search:
  the nearest directory wins, and in one directory `rust-toolchain` beats `rust-toolchain.toml`. It
  also reads TOML under the extensionless name, which rustup accepts. A file with no `channel`, such
  as a `path` toolchain, renders empty.
  - **This is the first repo-controlled input to reach the TOML parser**, so it is bounded: a 4 KB
    read cap, FIFO and device files refused, and channels over 255 bytes rendered empty, which matches
    the plain format's limit. The worst hostile file measured costs about 0.5 ms. Control bytes are
    stripped at the existing chokepoint, including ones spelled as escapes.
- **`[[segments.vcs]] budget_ms`.** A whole number of milliseconds from 1 to 1000 for the `sit status`
  watchdog, defaulting to 5. With a 40 ms `sit`, the default renders empty and `budget_ms = 200`
  renders the branch. Anything else warns and keeps the default, so a typo cannot stall every prompt.
- **`docs/themes/powerline.cyml`.** A sixth theme, with a `bg` on every segment. It needs a nerd-patched
  font, and spells its glyphs as escapes so the file stays readable without one.
- **Benchmark:** `rustup_env_parse_toml`.

### Changed

- **Dead-code elimination on every build** ([ADR 0010](docs/adr/0010-dead-code-elimination-on-every-build.md)):
  `[build] dce = true`. CI now runs the suite with `CYRIUS_DCE=1`, because `cyrius test` does not apply
  the manifest's setting and would otherwise exercise different code from the binary that ships.
- **A `rust-toolchain` file whose first non-blank byte is `[` is read as TOML.** No real channel starts
  that way. Junk in that shape printed before and renders empty now.

### Performance

| | 1.2.1 | 1.2.2 | Delta |
|---|---|---|---|
| Binary, x86_64 | 313,392 B | **153,808 B** | −159,584 B (−50.9 %) |
| Binary, `--agnos` | 317,808 B | **145,928 B** | −171,880 B (−54.1 %) |
| Live code, x86_64 | 149,552 B | 153,808 B | +4,256 B (+2.8 %) |
| `rustup_env_render`, no file found | 4.90 µs | 9.53 µs | +4.6 µs, it now walks once per file name |
| `rustup_env_parse_toml` | — | 1.95 µs | new |
| `config_load`, largest theme | 66.61 µs | 66.54 µs | flat |
| Cold start, no config | 450 µs | 443 µs | −7.7 µs |
| Cold start, largest theme | 625 µs | 630 µs | +4.4 µs |

Bench figures are medians of three runs, and cold start is three rounds of 3,000 interleaved spawns.
The largest theme includes `rustup_env`, so it pays for the second walk.

### Verified

- **Suite 387/387 across 165 tests**, also with `CYRIUS_DCE=1`, and `--agnos` clean. The CI job was
  rehearsed end to end in a throwaway clone.
- **Differential, 1.2.1 vs 1.2.2.** 6,163 cases with no differences. The 111-config corpus and all 43
  argv cases also matched.
- **Fuzz.** 80,000 mutated `rust-toolchain` files: no crash, no hang, and no control byte in stdout.
  40,000 mutated configs and 20,000 argv sets: no crash and no hang.
- **The new tests can fail.** Undoing each of the 14 new behaviours and safeguards turns the suite red.
  That run first found a weak test, since `"5ms"` was refused by arithmetic overflow rather than by
  the digit check it was meant to prove, so `"1a"` was added.
- **Found by running it, not by the suite:** the first `rust-toolchain.toml` draft let a hostile repo
  put 3,900 characters in the prompt. That is the channel cap above.

**Not tested on agnos itself.** The `--agnos` build was not booted, and that is on the 1.2.3 list.

### Known issues

- **On `--side=right`, the powerline closing glyph trails the last block**, so a left-pointing arrow
  sits after the text. It is not new, and the theme leaves `right_segments` unset until it is fixed.
  Pinned on the roadmap for 1.3.0.
- **Neither lock guard fails on a stale pin**, and `scripts/lock-check.sh` passes an altered vendored
  file. Both are on the 1.2.3 list.

### Documentation

- **`docs/development/roadmap.md` reorganized.** 1.2.3 is the P(-1) sweep. The remaining feature work
  moves to 1.3.x (colour), 1.4.x (language env) and 1.5.x (per-segment control), with cache eviction
  and `alloc` guards folded into 1.2.3. Items gated outside this repo stay unscheduled under 1.x.x, and
  both gates were re-checked against 6.7.18.
- The roadmap's 256-colour example said `"38;5;117"`; it now says `"33"`, which is what ADR 0007 froze.
- New: [ADR 0010](docs/adr/0010-dead-code-elimination-on-every-build.md). ADR 0005, 0007 and 0009 are
  annotated. The themes README, guides and example config cover the new features.

## [1.2.1] - 2026-11-06

`cyrius` 6.7.9 -> **6.7.18**, cmdit 1.4.0 -> **1.5.0**, bayan 1.5.14 -> **1.11.1**, and the vendored
stdlib re-synced: the newest release of each. Two known limits close, a CRLF `---` divider and the
slow dotted-key case. Loading a theme is about 19 % faster, and every shipped theme and example
renders byte-identically.

### Breaking

| If your config has | 1.2.0 | 1.2.1 | To migrate |
|---|---|---|---|
| A blank first line, then `---`, then settings | Settings read, `---` ignored | `---` is the divider, so everything below it is notes and the defaults apply | Delete the blank line and the `---` |

This is bayan 1.7.0's rule that a `---` is a whole line wherever it falls.

### Fixed

- **A CRLF `---` divider is recognised** (bayan 1.8.0). Notes below it were read as config, so a
  `[[segments.exit]]` block in the notes could change the prompt.
- **Thousands of unique dotted keys no longer stall the prompt** (bayan 1.11.1). About 8,000 of them
  took 465 ms and now take 15.5 ms. The same keys under `[[palette]]` went from 316 ms to 15.7 ms.
- **`--side=right` works past 2 MiB of arguments** (cyrius 6.7.12, cmdit 1.4.2). The whole command
  line is now read, where 1.2.0 reported an error and rendered the left prompt.

### Changed

- **Toolchain `6.7.9` → `6.7.18`.** No source change was needed for the toolchain itself.
- **bayan `1.5.14` → `1.11.1`**, the newest tag and the one the 6.7.18 snapshot bundles. Its own pin
  is 6.7.16. `bayan_toml_get` and `bayan_toml_get_sections` are deprecated there, so the 17 calls in
  `src/config.cyr` moved to the `_by_cstr` names, which give the same answers. `hashseed` joins
  `[deps].stdlib` because `dist/bayan-toml.deps` now names it.
- **cmdit `1.4.0` → `1.5.0`**, the newest tag, pinned to 6.7.18. Its changes reach this build only
  through the long command line above; the 1.5.0 fix is to completion scripts, which `cmdrs` does not
  generate.
- **Vendored `lib/` re-synced** with `cyrius lib sync --full`: 113 files byte-identical to
  `6.7.18/lib`. 66 changed, none added or removed.

### Performance

| | 1.2.0 (6.7.9) | 1.2.1 (6.7.18) | Delta |
|---|---|---|---|
| Binary, x86_64 | 309,200 B | 313,392 B | +4,192 B (+1.4 %) |
| Binary, `--agnos` | 309,384 B | 317,808 B | +8,424 B (+2.7 %) |
| Live code, x86_64 (`CYRIUS_DCE=1`) | 145,360 B | 149,552 B | +4,192 B (+2.9 %) |
| Unreachable code, x86_64 | 651 fns, 163,500 B | 676 fns, 165,267 B | +1,767 B |
| `config_load`, largest theme | 78.77 µs | **63.56 µs** | −15.2 µs (−19.3 %) |
| `cli_parse` | 0.98 µs | 0.99 µs | flat |
| `render_prompt` | 12.07 µs | 11.13 µs | flat, see below |
| Cold start, no config | 413 µs | 409 µs | −4.2 µs |
| Cold start, largest theme | 620 µs | 600 µs | −20.4 µs |

Bench figures are medians of three runs alternating with 1.2.0. Cold start is three rounds of 3,000
interleaved spawns. `render_prompt` is **flat, not faster**: it does not parse a config, and its
1.2.0 runs measured as low as 10.51 µs.

### Verified

- **Suite 331/331 across 158 tests, and `--agnos` clean**, with zero compiler warnings. The CI job
  was rehearsed end to end in a throwaway clone with this lock committed and produced byte-identical
  binaries. The toolchain install step ran in a throwaway home, and its snapshot matches the local one.
- **Differential, 1.2.0 vs 1.2.1.** 5,943 cases with no hangs, and only one difference: a vcs case
  through a stub, missing the 5 ms budget on a cold exec. 150 alternating trials then rendered the
  branch 150/150 on both. All 43 argv cases and all 34 doc config runs matched.
- **Config corpus.** 111 configs, 109 identical. The other two are the CRLF fix and the **Breaking**
  entry. Four more bayan 1.7.0 shapes (adjacent `[[entries]]` lines, `---` right after a marker, a
  marker on the last line, and `---` inside a multi-line string) render as before.
- **The dotted-key index.** bayan switches to a hash index past 8 tables, so 22 configs straddle that
  threshold under `[[prompt]]`, `[[palette]]`, the root table and repeated headers. All 22 match
  1.2.0's linear path, including `palette:` lookups and unknown-field warnings.
- **Stdlib delta on the call surface.** On the Linux path `src/` reaches, the changes are behaviour
  neutral rewrites (`file_read_all`, `getenv`, `file_open`, the `vec` abort path) or match the notes
  above (`args_init`). One tightens: `_pwd_parse_line` now skips a passwd line whose uid or gid is not
  one number.
- **Fuzz.** 80,000 mutated configs, seeded with the threshold cases, and 40,000 mutated argv sets: no
  crash, no hang, and no raw ESC on stderr.
- **The new test can fail.** It fails against bayan 1.5.14. Its first draft did not, so it was rewritten.
- **Watchdog.** With `sit` stubbed to hang for 30 s, both binaries return in a median of about 5.8 ms.

**Not tested on agnos itself.** The `--agnos` build compiles but was not booted.

### Known issues

- **Neither lock guard fails on a stale pin.** Against a lock holding an extra old `commit` line,
  `cyrius deps --locked` now prints a `note:` naming it, but still exits 0 and says the lock is exact.
  `scripts/lock-check.sh` passes it too. This release's lock was regenerated from empty and holds
  exactly two pins.
- **`scripts/lock-check.sh` also passes an altered vendored file**, which `cyrius deps --locked`
  fails, naming the file.

### Documentation

- ADR 0009 is annotated, and the guide's CRLF warning is gone.
- `state.md`, the README and `roadmap.md` describe this release. The colour work under the roadmap's
  1.2.0 heading has still not shipped, and its slot is unchanged.
- Architecture 003 and `cyrius.cyml` now quote guard and `path` behaviour measured on 6.7.18.

## [1.2.0] - 2026-11-06

`cyrius` 6.6.20 -> **6.7.9**, cmdit 1.2.6 -> **1.4.0**, bayan 1.5.12 -> **1.5.14**, and the
vendored stdlib re-synced. The prompt on stdout is byte-identical for every config tested, and
nothing in the config schema changes. CLI error messages do change, and `--side` parsing is about
11× faster.

### Changed

- **Toolchain `6.6.20` → `6.7.9`**, the v6.7.x language minor. No source change was needed. This
  repo has none of the sites the cyrius migration guide flags, including a lone `!` (the lexer
  dropped it before 6.7.3, so `if (!ok)` meant `if (ok)`), typed `*T` pointers, structs, or unary
  `-` / `~` on constants.
- **cmdit `1.2.6` → `1.4.0`**, the newest tag pinned to 6.7.9. `src/` calls nothing new.
  - Error lines name what was typed: `cmdrs: unknown flag: --nope`, and
    `cmdrs: --side: invalid value 'bogus' (expected left|right)`. Control bytes print as `?`, so a
    token cannot reach the terminal as an escape sequence.
  - `--help=x` and `--version=1` are now errors. `cmdrs` reports them and renders the left prompt,
    like any other bad flag, where it used to print the help or the version.
  - A command line past 2 MiB now reports `could not read the full command line` and renders the
    left prompt. It used to drop the trailing arguments silently.
- **bayan `1.5.12` → `1.5.14`**, the tag pinned to 6.7.9. The 6.7.9 snapshot bundles 1.5.13, whose
  TOML and CYML sublibs match 1.5.14 byte for byte apart from the version stamp. Upstream's changes
  since 1.5.12 are refused-allocation handling, and all 79 corpus configs render the same.
- **Vendored `lib/` re-synced** with `cyrius lib sync --full`: 113 files byte-identical to
  `6.7.9/lib`. 67 changed, none added or removed.

### Performance

| | 1.1.9 (6.6.20) | 1.2.0 (6.7.9) | Delta |
|---|---|---|---|
| Binary, x86_64 | 287,672 B | 309,200 B | +21,528 B (+7.5 %) |
| Binary, `--agnos` | 287,848 B | 309,384 B | +21,536 B (+7.5 %) |
| Live code, x86_64 (`CYRIUS_DCE=1`) | 132,024 B | 145,360 B | +13,336 B (+10.1 %) |
| Unreachable code, x86_64 | 605 fns, 153,181 B | 651 fns, 163,500 B | +10,319 B |
| `cli_parse` | 11.20 µs | **0.99 µs** | about 11× faster |
| `config_load`, largest theme | 78.37 µs | 78.44 µs | flat |
| `render_prompt` | 11.31 µs | 10.66 µs | flat, see below |
| Cold start, no config | 422 µs | 412 µs | −10.4 µs |
| Cold start, largest theme | 619 µs | 608 µs | −10.8 µs |

Bench figures are medians of three runs alternating with 1.1.9. Cold start is three rounds of 3,000
interleaved spawns. `render_prompt` is **flat, not faster**: 1.2.0 runs measured 10.51 to 11.91 µs.

The `cli_parse` gain comes from cmdit 1.3.0, and it undoes the cost
[ADR 0008](docs/adr/0008-cli-parsing-via-cmdit.md) accepted at 1.1.5. Most of the size growth is
cmdit too: its bundle went from 72,919 B to 129,116 B of source.

### Verified

- **Suite 329/329 and `--agnos` clean**, with zero compiler warnings. The CI job was rehearsed end
  to end in a throwaway clone with this lock committed, and produced the same binary sizes. The
  toolchain install step ran in a throwaway home, and its snapshot matches the local one.
- **Differential, 1.1.9 vs 1.2.0.** 5,943 cases: no hangs, and stdout and exit code matched in every
  one. All 990 differences are the new error text on stderr. The 79-config corpus and all 34 doc
  config runs matched completely.
- **argv.** 43 hand-written cases, including control bytes and 5,000-byte flags: `--help=x`,
  `--help=` and `--version=1` are the only stdout or exit differences. No raw ESC reached stderr.
- **Stdlib delta on the call surface.** No function reachable from `src/` changed on the Linux path,
  apart from cmdit and bayan. The deltas in that set are arms for other targets, such as `fncall2`
  for cx, or sit in `run` and `run_capture`, which `src/` does not call: `src/shellout.cyr` forks
  and execs directly.
- **Fuzz.** 80,000 mutated configs and 40,000 mutated argv sets: no crash, no hang, and no raw ESC
  on stderr.
- **Watchdog.** With `sit` stubbed to hang for 30 s, both binaries return in a median of about 6 ms.
- **Manifest behaviour.** Measured, not taken from the docs: see
  [architecture 003 § 4](docs/architecture/003-cyrius-lock-shape.md).

**Not tested on agnos itself.** cmdit's new command-line check was read for that target, not run: it
rejects only `argc() <= 0`, and its 2 MiB test is Linux-only. The `--agnos` build was not booted.

### Known issues

- **Neither lock guard sees a stale pin.** `scripts/lock-check.sh` and `cyrius deps --locked` both
  pass a lock holding an extra old `commit` line. This release's lock was regenerated from empty and
  holds exactly two pins.
- **`scripts/lock-check.sh` also passes an altered vendored file**, which `cyrius deps --locked`
  fails, naming the file.
- **A CRLF `---` divider is not recognised**, as before. bayan fixed this at 1.8.0, which needs
  cyrius 6.7.12.
- **Thousands of unique dotted keys are still slow**: 465 ms for about 8,000 of them, unchanged. A
  real theme takes 1.28 ms.

### Documentation

- **`path` overrides.** Since cyrius 6.7.6 a `path` beside a tag cannot win by accident, so
  `cyrius.cyml`, `scripts/lock-check.sh`, `ci.yml`, `state.md` and architecture 003 no longer say it
  does. Only comments and one error message changed; the guard's logic did not.
- `src/main.cyr`: the comment saying cmdit does not guard a 0 handle is corrected. It has since 1.3.2.
- `roadmap.md`: this release used the number the colour work was slotted under, and the colour work
  has not shipped. The status note says so; the slots themselves are unchanged.

## [1.1.9] - 2026-11-06

`cyrius` 6.6.3 -> **6.6.20**, cmdit 1.2.4 -> **1.2.6**, the vendored stdlib re-synced, and
`~/.commandress` now parsed by **bayan 1.5.12** instead of two frozen forks
([ADR 0009](docs/adr/0009-config-parsing-via-bayan.md)). Every shipped theme and example
renders byte-identically, and no frozen field changes. Some other configs do change: see
**Breaking**.

### Breaking

The old parser returned raw bytes and read some malformed input as data. bayan follows TOML.
The changes below can affect a config that loaded before.

| If your config has | 1.1.8 | 1.1.9 | To migrate |
|---|---|---|---|
| A backslash escape in `"..."`, such as `\n`, `\t`, `\"`, `\\` or `▶` | Printed as typed | Decoded | Use `'...'` to keep the literal text |
| A repeated key, including in `[[palette]]` | First value wins | Last value wins | Delete the line you don't want |
| A `'''...'''` value closing on its own line | Final newline trimmed | Final newline kept | Put the closing `'''` on the last line |
| An unquoted string containing `#`, `,` or `}` | Read to end of line | Ends at that character | Quote the value |
| A non-string in `segments`, such as `[cwd, 1]` | Ignored | Treated as a segment name, with a warning if unknown | Quote the names, or remove the element |
| A nested array in `segments`, such as `[["cwd"]]` | Inner strings used | One unknown segment, with a warning | Flatten the array |
| An array missing its `]`, such as `["cwd"` | Strings picked out of the rest of the file | One unknown segment, with a warning | Add the `]` |
| A line starting with `=` | Warned about a field named `''` | Skipped silently | Delete the line |

ADR 0007 froze fields rather than string spelling, so these did not go through its deprecation
path. ADR 0009 has the reasoning.

### Fixed

Each of these was reproduced against the 1.1.8 binary first.

- **Comments and line endings no longer defeat a bare value.** `hide_zero = false # note` and a
  CRLF or trailing-tab `hide_zero = false` were silently ignored, so the zero exit stayed hidden.
- **Literal strings work.** `trailer = '> '` printed its quotes, `fg = 'red'` lost its colour,
  and `segments = ['cwd']` was ignored.
- **An unterminated string no longer deletes what follows.** `separator = "oops` swallowed the
  next line, and an unterminated array element swallowed the rest of the file.
- **Comments inside arrays stay comments.** A `"` in one added a segment, and a `]` in one closed
  the array early.
- **`"""..."""` strings work.** The whole value used to be dropped.

### Added

These follow from reading the file as TOML, and all of them are additive:

- Escapes in `"..."`, so `trailer = "\n$ "` gives a two-line prompt and `\u` gives Unicode glyphs.
- Quoted keys, `[[ spaced ]]` headers, and dotted keys that name a real field, such as
  `segments.cwd.fg = "red"`.
- A `config_load` benchmark against the largest shipped theme.

### Changed

- **Toolchain `6.6.3` → `6.6.20`**, the closing release of the 6.6.x line.
- **Config parsing moved to bayan's TOML and CYML sublibs**, tag 1.5.12: the bayan that 6.6.20
  bundles, and the newest tag that does not need cyrius 6.7.x. Two sublibs instead of the bundle
  saves 319,928 B. `bayan_toml_array_parse` replaces the hand-rolled `_parse_str_array`.
- **cmdit `1.2.4` → `1.2.6`.** 1.2.6 is the only cmdit tag pinned to 6.6.20: 1.3.0 and up need
  6.7.9 or later, so `cyrius update`, which takes the latest tag (1.5.0), is the wrong tool for
  this bump. Across the two tags `src/cmdit.cyr` changes by one reflowed doc comment.
  `dist/cmdit.deps` shrinks to `alloc`, `string`, `args`, `io`; `args` and `bench` stay declared
  because this repo includes both directly.
- **Vendored `lib/` re-synced** with `cyrius lib sync --full`: 113 files byte-identical to
  `6.6.20/lib` (97 modified, 3 new: `alloc_cx`, `poison`, `tls_hostid`). `cyrius.lock` gains a
  `cyrius 6.6.20` row. `result` is now declared in `[deps].stdlib`.

### Removed

- `lib/toml.cyr` and `lib/cyml.cyr`, the frozen parser forks.
- Eight unreferenced leftovers no snapshot ships: `lib/agnosys.cyr`, `base64`, `bigint`, `csv`,
  `json`, `linalg`, `matrix`, `u128`.

### Performance

| | 1.1.8 (6.6.3) | 1.1.9 (6.6.20, bayan) | Delta |
|---|---|---|---|
| Binary, x86_64 | 211,784 B | 287,672 B | +75,888 B (+35.8 %) |
| Binary, `--agnos` | 207,608 B | 287,848 B | +80,240 B (+38.6 %) |
| Live code, x86_64 (`CYRIUS_DCE=1`) | 105,288 B | 132,024 B | +26,736 B (+25.4 %) |
| Unreachable code, x86_64 | 468 fns, 107,314 B | 605 fns, 153,181 B | +45,867 B |
| `render_prompt` | 11.339 µs | 10.894 µs | flat, see below |
| Cold start, no config | 423 µs | 413 µs | −10.4 µs |
| Cold start, largest theme | 593 µs | 598 µs | +4.8 µs |

Of the x86_64 growth, +43,056 B is the toolchain and stdlib (+39,202 B of that unreachable) and
+32,832 B is bayan (+20,544 B live). `render_prompt` is **flat, not faster**: 1.1.9 runs measured
10.87 to 11.67 µs against 11.339 µs. Cold start is three rounds of 3,000 interleaved spawns.

The parser swap alone, measured on 6.6.20 with three alternating runs, takes `config_load` on the
largest theme from **70.0 µs to 82.2 µs**. The 6.6.x bench harness prints the mean as `min` and
`max` when a row cannot resolve them, which is why `vcs_render` now reads `min=max`.

### Verified

- **Suite 329/329 across 157 tests, and `--agnos` clean.** The CI job was rehearsed end to end in
  a throwaway clone with this lock committed and produced the same binary sizes.
- **Toolchain differential, 1.1.8 vs 6.6.20.** 5,943 cases across fixtures, all five themes, flags
  and env, including directories and FIFOs at pin-file paths, hostile bytes, and a garbage, huge,
  directory or FIFO `~/.commandress`. No hangs, and 5,942 matched in stdout, stderr and exit code.
  The other was the old binary missing the 5 ms vcs budget on a cold first exec of a shell stub.
- **Stdlib delta on the call surface.** The lib functions reachable from `src/` were diffed between
  the snapshots. `file_read_all` returns an errno on a read error instead of a partial count, and
  fixtures with a directory at a pin-file path render identically. `getenv`, `str_cstr`,
  `epoll_event_new` and `epoch_to_date` return 0 when `alloc` refuses. `src/segments/time.cyr` still
  loads through its result unchecked, so that path still faults under OOM as it did before.
  `fmt_int_buf` formats in a private buffer and still NUL-terminates. `alloc` maps its first chunk
  `MAP_NORESERVE`. The rest are macOS and agnos arms a Linux build does not compile.
- **Parser differential, forks vs bayan.** The same 5,943 cases: all themes and the garbage, huge,
  FIFO and directory configs matched. 110 differed, all from one deliberately malformed config (an
  array missing its `]`, listed under **Breaking**), and one was a vcs timing miss. A separate
  79-config corpus has 48 identical; each of the other 31 is covered above.
- **Fuzz.** 80,000 mutated configs against the new parser: no crash, no hang.
- **The new tests can fail.** 13 of their assertions fail against the old forks, and undoing each
  of the four safeguards in `src/config.cyr` turns a test red.
- **Watchdog.** With `sit` stubbed to hang for 30 s, both binaries return in a median 6.00 ms and
  leave no child behind.

### Known issues

- **`scripts/lock-check.sh` cannot see a stale pin.** Moving a dep tag through `lib sync` then
  `deps` leaves the old `commit` line beside the new one, and the guard reports `OK`. This release's
  lock was regenerated from empty and holds exactly two pins. See
  [architecture 003 § 3](docs/architecture/003-cyrius-lock-shape.md).
- **A CRLF `---` divider is not recognised**, so notes below it are read as config, as before.
  bayan fixed this at 1.8.0, which needs cyrius 6.7.x.
- **Thousands of unique dotted keys are slow.** bayan's table lookup is linear, so about 8,000 of
  them take 464 ms, against 3 ms before. A real theme is unaffected (1.26 ms). Only the user's own
  file can reach this. ADR 0009 records why it is accepted.

### Documentation

- New: [ADR 0009](docs/adr/0009-config-parsing-via-bayan.md). `docs/guides/getting-started.md` now
  explains how to write values, and ADR 0003 is annotated with the new parser.
- `state.md` and the README were still on 1.1.6; both now describe this release.
- `roadmap.md`: the "Moving the cyrius pin to 6.6.6" note is discharged by this release and removed
  under that file's shipped-work rule. Its pre-bump findings stay in git history (`350ed66`).

## [1.1.8] - cyrius 6.6.3

`cyrius` 6.6.2 -> **6.6.3**. No source change; re-vendored and rebuilt.

6.6.3 makes `cyrius.lock` deterministic. `_deps_lock_dir` wrote its hash lines in
`dir_list` (readdir) order, so a fresh checkout on another machine produced the same
hashes in a different SEQUENCE — the defect `scripts/lock-check.sh` was written to
tolerate, and the reason its comparison is order-insensitive. The `lib/` names in the
lock are now emitted sorted; verified here.

⚠ **`scripts/lock-check.sh` STAYS.** It guards two things, and 6.6.3 fixes only one.
The other — a `path = "../<dep>"` override silently winning over that dep's `tag`, so a
locally-produced lock describes a sibling worktree CI will never see — is untouched by
any toolchain release and is the more dangerous half. Retiring the script because the
ordering half got fixed would drop that guard.

## [1.1.7] - 2026-09-11

### Changed

- **Toolchain `6.5.35` → `6.6.2`.** No source change; the value form needed none.
  Build, tests, and any bench/fuzz/distlib target the repo ships re-verified at the new pin.


### Documentation

**Full doc sweep (2026-08-26).** The `doc-health.md` ledger had itself gone stale — last
refreshed at **v0.3.0**, five releases back, inventorying 17 docs when there are 36 and
4 ADRs when there are 8. Rebuilt from the real tree, and every stale claim it should have
caught is now fixed.

**Two findings were security-relevant, and both are the same shape: 1.1.6 fixed the
adapters, and nothing swept the docs that taught the old configuration.**

- **`docs/guides/zsh-setup.md` documented `setopt prompt_subst`** — in prose *and* in a
  copy-paste "manual setup" block. That is precisely the arbitrary-command-execution
  vector the 1.1.6 audit removed from `adapters/zsh.sh` (P-01): a user following the guide
  re-created the vulnerability by hand. Removed, replaced with a `%`-doubling recipe and
  a security section explaining why the option is never needed here.
- **`docs/examples/prompt-tour.md` recommended `PROMPT='$(_cmdrs_prompt)'`** — single-quoted,
  which only works *with* `prompt_subst`. Same vector, presented as the zsh idiom. Replaced
  with a pointer to the shipped adapters plus an explicit warning.
- **`docs/guides/bash-setup.md`'s manual recipe** was missing both bash-side fixes
  (`shopt -u promptvars`, backslash-doubling). Both added and marked REQUIRED, with the
  shell-global trade-off stated.

Every replacement recipe was **executed against the live attack** before being written
down — `$(touch /tmp/x)` in a `.python-version`, confirmed not to fire — rather than
reasoned about. The self-test is now printed in the guides so a reader can repeat it.

**Two stale upstream blockers, one of which was gating real work:**

- **Cyrius papercut Item 3 (single-bracket TOML) has closed.** `src/config.cyr` and
  `src/segments/rustup_env.cyr` both deferred work to it. Verified against the 6.5.35
  stdlib — with a double-bracket control case proving the harness — that
  `toml_get_sections` finds a single-bracket `[toolchain]`. Two consequences: the
  `rust-toolchain.toml` work is **scheduled, not blocked** (roadmap 1.3.0), and
  single-bracket `[section]` config **already works today**, which nothing documented.
  Now documented, and pinned by `test_config_accepts_single_bracket_sections` so it
  cannot silently regress. `[[section]]` stays canonical — every theme uses it and
  churning user configs buys nothing.
- **Item 8 (no stdlib `which()`) genuinely still holds** — re-checked, `src/pathlookup.cyr`
  stays. Both gates now carry the date they were last verified, because a gate is a claim
  about the world and it expires.

**`docs/guides/getting-started.md` had been flagged stale in the May ledger and never
fixed.** It still documented a `[prompt] order =` schema that never shipped, a
`[segments.git]` section (it is `vcs`), and `--config` / `--debug` flags that do not
exist. Rewritten against the real schema and CLI; the replacement config was run through
`cmdrs` to confirm it renders with zero warnings.

### Changed

- **`docs/development/roadmap.md` reorganised** from v1.0 milestone framing into release
  slots — **1.2.0** (multi-palette, hex/256-colour, powerline theme), **1.3.0**
  (`rust-toolchain.toml`, `package.json engines.node`, opt-in version shellouts),
  **1.4.0** (per-segment `budget_ms`, output length cap, local time/`TZ`), **1.5.0**
  (cache eviction, wider cache key, the `CYRIUS_DCE` decision, remaining `alloc` guards),
  plus an **unscheduled** section for the two items gated outside this repo. Every entry
  links to the source line, audit finding, or ADR that defers it — the codebase was swept
  for `deferred` / `TODO` / `follow-up` / `parked` language and all of it is now pinned.
  Version slots are stated as planned sequencing, not commitments.
- **`docs/development/state.md`** no longer duplicates the roadmap; it keeps only state
  (upstream gates with check-dates, size drift, the undocumented-but-supported config
  spelling) and defers planning to `roadmap.md`. The two had drifted, which is how the
  stale Item 3 claim survived in three places at once.
- **`README.md`** — status line `v1.0.0` → `v1.1.6`, test counts (2×), `--version` sample
  output, segment-table header, `vcs` timing (`~68 µs` → `~7.6 µs`), and the layout tree
  (added `src/cli.cyr`, `cyrius.lock`, `scripts/lock-check`, ADR range 0001–0008, both
  audits).
- **`docs/benchmarks.md`** re-measured at 1.1.6; the "v1.0 finalised" framing dropped, a
  `cli_parse` row added, the end-to-end warm figure corrected to ~0.96 ms with a note that
  it is dominated by process exec, and the 0.9.0→1.1.4 gap in `history.csv` called out.
- **`docs/adr/0005`** annotated (not revised) where it cites the now-closed Item 3.
- Source comments in `src/config.cyr` and `src/segments/rustup_env.cyr` corrected where
  they described the closed gap as current.

## [1.1.6] — 2026-08-26 (P-1 audit — arbitrary command execution in both shell adapters)

**Security release. Update if you use the shell adapters or work in untrusted
repositories.** A P-1 sweep of the v1.1.5 codebase found **four HIGH-severity defects**,
two of which are reachable by doing nothing more than `cd`-ing into a hostile repository:

1. **Both shipped shell adapters executed attacker-chosen commands on every redraw**
   (P-01, and a second independent channel in bash, A-04).
2. **A FIFO in a project directory hangs the prompt forever** (A-01) — no adapter
   involved, no shell feature, no timeout anywhere on the path.
3. The watchdog **abandoned its time budget** whenever a child closed stdout and kept
   running (A-02).
4. The CI lock guard added earlier the same day was **inert** (A-03).

Full report: **[docs/audit/2026-08-26-audit.md](docs/audit/2026-08-26-audit.md)** —
4 HIGH, 3 MEDIUM, 12 LOW, 2 INFO confirmed, all fixed here except the accepted gaps the
report records with reasons. Suite **295 → 304**; `render_prompt` unchanged at
**10.86 µs**; `--agnos` clean, and its largest stack frame drops 12,416 → 8,320 bytes.

The sweep ran two independent tracks — a five-dimension parallel read of the code, and
live attack testing against the built binary — and **each caught HIGHs the other missed**,
which is the argument for running both. The manual track found the adapter execution by
reading the glue and trying the attack; no amount of reading `src/` would have surfaced
it, because `cmdrs` is correct. The parallel read found the FIFO hang, which the manual
track walked past: it fuzzed the *contents* of those probe files and never questioned
their *file type*.

The bug was not in `cmdrs`. `cmdrs` renders bytes it does not choose — a branch name,
`.python-version` / `.nvmrc` / `rust-toolchain` / `VERSION` contents, `$VIRTUAL_ENV` —
and strips control bytes at the render chokepoint (audit F-1), correctly. But `$`, `(`,
`)` and `%` are ordinary printable characters and pass through as text, because they are
legal in a branch name. **The adapters then handed that string to the shell as a
script.** The project already had the rule written down — `adapters/agnoshi.sh` states
it in its 5-point contract, citing CVE-2021-45444, and the 2026-05-18 audit recorded it
as F-12 — but it was written for the adapter that does not exist yet and violated by the
two that ship.

### Security

- **P-01 · HIGH — `adapters/zsh.sh` and `adapters/bash.sh` executed prompt content.**
  zsh ran `setopt prompt_subst` (command substitution on the prompt, every redraw); bash
  inherited `promptvars`, on by default (parameter expansion **and** command substitution
  on `PS1`). A repository shipping `.python-version` containing `$(touch /tmp/x)` created
  that file on every keystroke-triggered redraw — confirmed by execution under both
  shells, not by inspection. Same class as CVE-2021-3934 (oh-my-zsh, branch name via
  `print -P`) and CVE-2021-45444 (zsh `PROMPT_SUBST`).

  Fixed by removing `setopt prompt_subst`, which was **never needed for this design**:
  `PROMPT` is assigned from `$( )` inside the `precmd` hook, so by render time it holds
  finished bytes — there is no `$(cmdrs)` left to expand. The option bought nothing and
  opened the hole. bash gets `shopt -u promptvars`. zsh additionally doubles `%` →
  `%%`, because `%` prompt escapes expand whether or not `prompt_subst` is set — a
  separate channel that the same input reaches. All three fixes verified against the
  live attack.

  **Stated trade-off**: `shopt` is shell-global, so sourcing `bash.sh` disables
  `promptvars` for the session. A user whose own `PS1` relies on `$(...)` expanding at
  render time loses that. Documented in `adapters/README.md` rather than left to be
  discovered.

- **A-01 · HIGH — a FIFO in a hostile project directory hung the prompt forever.**
  `read_trimmed_file_at` and `config_load` opened external files with a plain
  `open(O_RDONLY)`, and `open(2)` on a FIFO with no writer blocks indefinitely. Nothing
  covered it: the only watchdog wraps fork+exec, not file reads, and `main()` sets no
  alarm. The candidate is chosen by `access(F_OK)`, which succeeds on a FIFO. Reproduced
  on all five reachable paths — `VERSION`, `.python-version`, `.nvmrc`, `rust-toolchain`,
  and `~/.commandress` — with `timeout 6` returning 124 and `/proc/<pid>/wchan` reading
  `wait_for_partner`. **tar preserves FIFOs**, so extracting an archive is enough.
  Fixed with `read_regular_file`: `O_NONBLOCK` on the open, then `fstat` on the
  already-open fd requiring `S_IFREG` (which also rejects device nodes whose *reads*
  stall), reading from that fd — closing the `access`→`open` TOCTOU as well. Guarded off
  on agnos, deliberately: `O_NONBLOCK` is Linux/macOS-only and would fail the `--agnos`
  build, and agnos's `sys_fstat` is a hard stub returning -1, so an unconditional gate
  would reject every file and silently revert agnos users to defaults. Verified: 2–7 ms
  instead of forever; regular files unaffected.
- **A-02 · HIGH — the watchdog abandoned its budget on a live child.** The read loop has
  three exits and only the deadline killed the child. On the **EOF** exit a child that
  closes stdout and keeps running left the parent in `waitpid` with no deadline covering
  it — the budget is enforced by `epoll_wait`, already exited. Measured: a fake `cyrius`
  on `PATH` doing `exec 1>&-; sleep 30` parked the prompt for 30 s against a **5 ms**
  budget. Fixed by killing unconditionally before waiting; once we stop reading, the
  child's status is irrelevant. 12,000 ms → 3 ms.
- **A-03 · HIGH — the CI lock guard was inert.** It snapshotted the working-tree lock,
  but `ci.yml` runs `cyrius deps` in an earlier step, which overwrites that file — so it
  compared a fresh resolution against another fresh resolution and always passed. A lock
  committed with a `path` override (zero `commit` lines, the exact case it exists to
  catch) was reported OK. Fixed by taking the baseline from `git show HEAD:cyrius.lock`,
  making it immune to step ordering. Also fixes `--no-resolve` comparing the file to
  itself.
- **A-04 · HIGH — bash reconstructed ESC from bytes the sanitizer let through.** Not
  covered by the `promptvars` fix: PS1 backslash decoding is unconditional. `\` and `e`
  are printable, so `\e[31m` in a `.python-version` passes F-1 untouched and bash's
  decoder turns it into a real ESC inside the shell. Verified: no `033` in `cmdrs`
  output, `033 [ 3 1 m` after `${PS1@P}`. Fixed by doubling `\` → `\\`.
- **A-05 · MEDIUM — the sanitizer passed UTF-8-encoded C1 controls.** It let every byte
  `>= 0x80` through as "UTF-8, not controls" — true of the bytes, false of the
  codepoints: U+0080–U+009F *is* the C1 set, and a terminal honouring C1 reads U+009B as
  CSI. Verified reaching stdout byte-for-byte. Now drops `0xC2` + `0x80–0x9F`, while `é`
  and NO-BREAK SPACE survive.
- **A-06 · MEDIUM — the config-warning path echoed raw config bytes** — the sibling site
  P-02 could not reach, because config keys are `(ptr, len)` pairs rather than cstrings.
  Added a length-aware `eprint_sanitized`.
- **A-07 · MEDIUM — a right-prompt parse error rendered the LEFT prompt.** A defect from
  the 1.1.5 adoption: the degrade returned 0 for any non-OK result, degrading the **side**
  as well as the exit code. `cmdrs --side=right --bogus` rendered the left prompt, which
  the zsh adapter pastes into `RPROMPT`. cmdit retains a value parsed before a later flag
  failed, so the side is now honoured. The 1.1.5 tests covered each flag *alone*, where
  left is simply the default — they passed for the wrong reason; the combination is now
  pinned.
- **A-08 · MEDIUM — `vcs_render`'s frame exceeded the agnos init stack.** 4 KB + 8 KB
  buffers made a 12,416-byte frame (confirmed by disassembly: `sub $0x3080,%rsp`, the
  largest in the agnos binary) against ~12 KB of ring-3 init stack. An early return would
  not help — a `var[]` in a dead region still reserves at the prologue — so the
  declarations are now preprocessed away on agnos, the same guard `lib/io.cyr::getenv`
  carries. Nothing lost: every input is already stubbed there. Largest frame
  12,416 → 8,320 B.
- **A-11 · MEDIUM — a symlinked cache directory defeated the F-3 gate.** F-3 used `stat`,
  which follows symlinks, so a co-tenant pre-creating `/tmp/commandress-<uid>` as a
  symlink to another `0700` directory we own passed both the uid and mode checks — and
  `cmdrs` then wrote into a directory of their choosing. Now `lstat` (via an agnos-safe
  bridge; agnos has no `sys_lstat`, and naming it unguarded broke the `--agnos` build even
  on an unreachable line) plus an explicit `S_IFDIR` gate. Verified: 0 files written to
  the symlink target.
- **A-12 · LOW — the cache TTL check was one-sided**, so a future mtime never expired.
  Needs no attacker: any backwards clock step pins entries. Future mtime is now a miss.
- **A-09 / A-10 / A-13 · LOW — CI least privilege and pipeline hygiene.** `contents:
  write` moved from the workflow level (where the CI-gate job inherited it) to the release
  job alone; `softprops/action-gh-release` pinned from the mutable `v2` tag to its commit
  SHA; `set -o pipefail` added so a bench that emits a valid line and then dies cannot
  read green.
- **P-07 · MEDIUM — CI piped an installer from a moving branch into `sh`.** The toolchain
  *version* was pinned from `cyrius.cyml`, but the installer was fetched from
  `raw.githubusercontent.com/.../cyrius/main/scripts/install.sh` — so every CI run
  executed whatever that branch said at that moment, on a runner holding the workflow
  token (`release.yml` runs with `contents: write`). Now fetched from the pinned version
  tag, so the installer matches the toolchain it installs. Residual risk stated in the
  report: tags are mutable; a SHA would be immutable.

- **P-02 · LOW — the unknown-segment warning re-emitted unsanitized bytes.** Segment
  *output* is sanitized; the segment *name* echoed by `warning: unknown segment '<name>'`
  was not. Verified: a config naming a segment `\x1b[31mBADSEG\x1b[0m` put raw `033`
  bytes on the terminal. Inside the documented config-is-trusted boundary, hence LOW, but
  it fires once per redraw for as long as the typo stands and stderr bypasses
  `PROMPT="$(cmdrs)"` capture. Now routed through `sanitize_segment_output`.

### Fixed

- **P-04 · MEDIUM — `cache_put` published short writes as complete entries.** F-5 made
  cache writes atomic, and that holds — but atomicity is not integrity: the `file_write`
  result was discarded, so a short write was `rename`d into place as though complete and
  `cache_get` could not tell. The next redraw then served a clipped branch name for the
  whole TTL. Now verifies the byte count and unlinks the temp on a short write, degrading
  to a cache **miss** rather than a wrong hit.
- **P-03 · LOW — all 8 stdout writes discarded their result**, so an `-EINTR` mid-write
  would truncate the prompt and still report success. Added `_emit`, which loops on
  partial writes and retries EINTR (treating a 0 return on non-zero length as failure so
  it cannot spin). Rated LOW deliberately: the tempting "pipe writes above `PIPE_BUF`
  short-write" framing does not hold for a blocking fd, and testing agreed — a
  60,000-byte prompt delivered all 60,015 bytes through a pipe and a slow reader both
  before and after. Hardening, not a live defect. No measurable cost.
- **P-06 · LOW — the sanitization chokepoint could wild-write on allocation failure.**
  stdlib `alloc` returns 0 rather than aborting; unguarded, the copy loop would `store8`
  from address 0. Reachable only under heap exhaustion, but this is the one function every
  segment's output crosses, and a prompt renderer that segfaults takes the shell prompt
  with it. Same defence cmdit added for `cmdit_new` in its own 1.2.4 security release.
- **P-08 · LOW — commandress depended on a private cmdit symbol.** `_print_help` called
  `_cmdit_eprint`, an underscore-prefixed internal, not one of the 54 public `cmdit_*`
  entry points — outside the frozen-1.0.0 API that [ADR 0008](docs/adr/0008-cli-parsing-via-cmdit.md)'s
  tag pin is predicated on, so a routine pin bump could have broken the build. Replaced
  with a local `_eprint`; `src/` now references only public `cmdit_*` names.

### Added

- **`test_shellout_oversized_child_does_not_hang`** (P-05 · INFO). Opened as a suspected
  deadlock in the watchdog's buffer-full path — the child is not SIGKILLed there and may
  still be writing, so a `waitpid` while holding the read end open would hang the prompt
  with no deadline covering it. **Refuted**: it is safe because `sys_close(rfd)` runs
  *before* `sys_waitpid`, so the blocked child takes `EPIPE`/`SIGPIPE` and dies. As
  shipped, a child flooding 200 KB through a 256-byte buffer returns in 5 ms; with the
  two lines swapped in a scratch copy, the suite **hangs and is killed at 45 s**. The
  invariant is now stated at the call site and pinned by this test, which has teeth.
- **`docs/audit/2026-08-26-audit.md`** — the full report, including a *Verified clean*
  section (F-1 and F-7 re-confirmed by live attack, config parser fuzzed, `bench-gate.sh`
  checked for false-pass, cache TOCTOU analysed as benign) and a *Known gaps* section
  recording what was deliberately not fixed and why.

### Changed

- **`VERSION`** — `1.1.5` → `1.1.6`; `src/cli.cyr`'s compiled-in literal follows (the
  1.1.5 drift guard asserts they match).
- **`adapters/README.md`** — new *"the prompt string is DATA, not a script"* section with
  a per-shell rule table and a two-line reproduction, so a future adapter author can
  self-test. Corrected the two places that told readers zsh *needs* `prompt_subst`.

## [1.1.5] — 2026-08-26 (cmdit adoption — CLI parsing, `--help`, `--version`)

**The hand-rolled CLI parser is gone.** commandress's whole command-line surface is one
flag — `--side=left|right` — and through 1.1.4 it was a single-pass walk over argv
byte-comparing each entry against the one string `--side=right`. That shape meant the
choice set was never validated (`--side=bogus` silently rendered the *left* prompt),
`--help`/`--version` did not exist despite [ADR 0007](docs/adr/0007-schema-freeze.md)
reserving both, and none of it was testable — `_parse_side` read the real process argv
from inside `src/main.cyr`, a file no test can include because it ends in a bare
`_agnos_entry();`. It is now a [cmdit](https://github.com/MacCracken/cmdit) flag table.

**This is commandress's first non-stdlib dependency**, so the "zero non-stdlib deps"
rule is narrowed rather than dropped: first-party AGNOS *source* deps are permitted
(vendored into `lib/` by `cyrius deps`, tag-pinned in `cyrius.lock`, compiled in),
*runtime* deps remain forbidden. The binary is still static and self-contained, and
config + context-from-env is still the only input surface — cmdit parses the same argv
that was always parsed. Rationale, costs, and the five rejected alternatives are in
**[ADR 0008](docs/adr/0008-cli-parsing-via-cmdit.md)**.

Suite **279 → 295 passed, 0 failed** (+16 assertions across 10 tests, on a CLI that
previously had none). `--agnos` cross-build clean.

**Costs, measured before they were accepted.** The parse is **~212× slower in
isolation** — the hand-rolled walk benched **56 ns**, cmdit benches **11.914 µs**, of
which ~98 % is `cmdit_new` zeroing a 64-entry × 112-byte flag table for a program that
registers one flag. The binary grows **168,264 B → 211,768 B** (+43,504 B, +25.9 %;
agnos 203,464 B). Neither is felt where it matters: the parse is **not** inside
`render_prompt` (which takes `side` as a parameter), so the 5 ms cold-start gate is
untouched and `render_prompt (default cwd+vcs+exit)` still benches **10.769 µs**. Against
the ~940 µs the binary actually spends per invocation — process exec and the vcs probe
dominate — an interleaved A/B of the 1.1.4 and 1.1.5 binaries measured deltas of
**−15 µs, +1 µs, +11 µs**, straddling zero and below the measurement's noise floor.
Public API per ADR 0007 unaffected; `cmdrs` and `cmdrs --side=right` are unchanged.

### Added

- **`--help` / `-h` and `--version` / `-V`** — reserved by ADR 0007 and never built until
  now. Both are registered by `cmdit_new`, so the flag list in `--help` is generated from
  the parse table and cannot drift from it. `--help` prints to **stderr** and `--version`
  to **stdout** (`cmdrs 1.1.5`), which is what makes them safe here: a shell doing
  `PROMPT="$(cmdrs --help)"` captures an empty string rather than pasting a help wall into
  the prompt.
- **`--side` value validation.** `--side=bogus` is now reported on stderr as
  `cmdrs: --side: invalid value (expected left|right)`. In 1.1.4 it rendered the left
  prompt silently, indistinguishable from success.
- **getopt-long forms for free** — `--side right` (space-separated) now works alongside
  `--side=right`; `--` terminates flags. The old walk matched only the exact attached form.
- **`src/cli.cyr`** — the CLI policy as its own module, so it is includable by the test
  harness and drivable through cmdit's pure `cmdit_parse_argv` core with synthetic argv.
- **10 CLI tests / 16 assertions**, including a **version-drift guard**: the suite reads
  the `VERSION` file and asserts it equals the compiled-in `cmdrs_version()`, so a
  forgotten bump fails the build instead of shipping a `--version` that lies.
- **`cli_parse (cmdit --side)` benchmark** — the regression above is now tracked per
  release rather than rediscovered.

### Changed

- **`VERSION`** — `1.1.4` → `1.1.5`.
- **`cyrius.cyml`** — new `[deps.cmdit]` (git, `tag = "1.2.4"`, `modules = ["dist/cmdit.cyr"]`).
  `path = "../cmdit"` is present but **commented out**, per the ecosystem discipline: a path
  override silently wins over its tag and `cyrius.lock` records no dep name or version, so
  nothing detects the substitution. Resolving from the tag keeps CI's build and the lock in
  agreement.
- **`[deps].stdlib`** — `args` and `bench` are now declared. Both were always compiled in
  via includes (`src/main.cyr` includes `lib/args.cyr`; the bench harness includes
  `lib/bench.cyr`); cmdit's `dist/cmdit.deps` sidecar requires them in scope, so the
  declaration caught up with what the build already did.
- **`cyrius.lock`** — new, committed (119 entries, 1 commit-pinned at cmdit `e69bcaa`), with
  **`scripts/lock-check.sh`** wired into CI to verify it still describes a clean tag-only
  resolution. Two findings behind it, both measured rather than assumed
  ([architecture/003](docs/architecture/003-cyrius-lock-shape.md)):
  - **The lock's line order is not stable across machines** — it tracks `lib/`'s directory
    read order. The first version of this guard was an inline
    `git diff --exit-code -- cyrius.lock`; it passed every local check (consecutive local
    resolves *are* byte-stable) and failed on its first real CI run with ~100 lines of
    reordered-but-identical entries. The check is now order-insensitive: `commit` lines and
    hash lines compared as two independently sorted sets.
  - **A `path = "../cmdit"` override omits the dep's `commit` pin line entirely**, which
    corrects the ecosystem comment quoted into `cyrius.cyml` when the dep landed ("records
    no dep name or version, so nothing detects the substitution"). On 6.5.35 the lock *does*
    carry `commit <sha> cmdit <url> 1.2.4`, and a path-override lock has none — so the
    substitution is detectable, and this is the case the script exists to catch. Verified
    across five states: clean, shuffled, altered hash, altered sha, and a lock genuinely
    generated with the override active.
- **`main` no longer calls `args_init()`.** `cmdit_argv` calls it, and it is **not
  idempotent** — each call allocates `ARG_MAX` (2 MB) and re-reads `/proc/self/cmdline`, so
  leaving both in place would have allocated 4 MB per prompt. `getenv` is unaffected either
  way: it reads `/proc/self/environ` directly, and the parked init rsp on agnos, never
  `args_init`'s buffer.
- **CLAUDE.md / README** — the dependency rule updated to the runtime-vs-source distinction
  above, rather than left contradicting the shipped state.

### Fixed

- **A parse error no longer risks blanking the prompt.** `cmdrs` runs as
  `PROMPT="$(cmdrs)"` once per redraw, so the conventional "print usage, exit 2" path that
  kii and stiva take would leave the user with an empty prompt over a typo. Unknown flags
  and bad `--side` values are diagnosed on stderr and then **degrade to the left prompt**,
  preserving 1.1.4's forgiving behaviour; ADR 0007 declines to promise behaviour on unknown
  flags, so the choice is ours to make. `$( )` does not capture stderr, so the human sees
  the error and the prompt still renders.
- **Guarded `cmdit_new`'s OOM return.** It returns 0 on heap exhaustion, and
  `cmdit_argv`/`cmdit_parse`/`cmdit_enum` do not check for a 0 handle — they would wild-read
  at a small absolute address. Unreachable in practice (the three allocations are
  compile-time constants well inside `ALLOC_MAX`), but a prompt renderer that segfaults takes
  the shell prompt with it, so the one comparison is worth its cost. That path renders the
  default left prompt.

## [1.1.4] — 2026-08-26 (toolchain refresh + stdlib resync)

**Toolchain refresh + dependency resync**, carrying the agnos cache fix that had been sitting unreleased. Patch release lifting the Cyrius pin from `6.4.66` to `6.5.35` (clearing the `manifest-pin: 6.4.66 (drift — wrapper is 6.5.35)` drift) and re-vendoring the bundled stdlib snapshot to match. Suite remains **279 passed, 0 failed**; `--agnos` cross-build is clean (**164,056 B**), which is what the `cache.cyr` fix below bought.

Binary grows **147,600 B → 168,264 B** (+20,664 B, +14.0 %). That growth is the **vendored snapshot, not codegen**: the local wrapper was already `cycc 6.5.35` before this release — that *was* the drift — so the pre-bump baseline compiled the same `src/` with the *same compiler* against the old `lib/` and produced 147,600 B (text 143,049 B, bss 2,464 B). After the resync the same `src/` produces 168,264 B (text 162,839 B, bss 2,544 B): text **+19,790 B**, bss **+80 B**. Roughly half of it is code the linker never reaches — the build's dead-code note goes from `318 unreachable fns (58,189 bytes)` to `384 unreachable fns (69,382 bytes)`, all of which `CYRIUS_DCE=1` eliminates. This partially gives back 1.1.3's −29.8 % drop; the net against the 0.3.0 baseline (395,115 B) is still **−226,851 B**.

Render time is unmoved, which is the metric that actually has a budget: `render_prompt (default cwd+vcs+exit)` benches **10.851 µs avg** (min 10.702 µs, max 11.092 µs) against **10.553 µs** pre-bump — noise, and ~0.2 % of the 5 ms cold-start budget ([architecture/001-prompt-render-budget.md](docs/architecture/001-prompt-render-budget.md)). Public API per [ADR 0007](docs/adr/0007-schema-freeze.md) unaffected.

### Changed

- **`VERSION`** — `1.1.3` → `1.1.4`.
- **`cyrius.cyml`** — `[package].cyrius` pin `6.4.66` → `6.5.35`.
- **Vendored stdlib snapshot resynced to the 6.5.35 pin** (`cyrius lib sync --full` — 108 files copied): **60 bundled libs updated, 2 added, 0 removed**. Added: `async_macos.cyr`, `thread_macos.cyr`. Version bumps: `bayan` 1.2.0 → 1.5.2, `sankoch` 2.5.1 → 2.7.8, `yukti` 2.2.9 → 2.3.8, `patra` 1.12.12 → 1.13.10, `vani` 1.1.1 → 1.2.2, `ganita` 1.0.3 → 1.1.4, `sandhi` 1.9.0 → 1.9.10, `sigil` 3.12.1 → 3.12.9, `sakshi` 2.4.6 → 2.4.11, `mabda` 4.0.7 → 4.1.0, `yantra` 1.0.1 → 1.0.3, `niyama` 1.0.6 → 1.0.7. (`agnosys` 1.2.6 is not part of the stdlib snapshot and is untouched.) Clears the `./lib/ shadows version-pinned …/6.4.66/lib — 2 bundled lib(s) differ` build warning. `[deps]` in `cyrius.cyml` is unchanged — the declared stdlib surface is the same; only the vendored implementations advanced.
- **`docs/benchmarks/history.csv`** — first per-release rows since `0.9.0`, now that `bench-history.sh` records them (see below). 12 rows for 1.1.4.

### Fixed

- **`--agnos` builds failed on `cache.cyr`'s `sys_stat` arity — and the cache was never
  going to work there anyway.** The raw `sys_*` wrappers are per-target by design and
  agnos's are length-carrying: `sys_stat(path, pathlen, statbuf)` against Linux's
  `sys_stat(path, statbuf)`. `cache_init` and `cache_get` used the Linux shape
  unconditionally. Cyrius only *warned* about a wrong argument count until **v6.5.1**
  escalated it to a hard error, so this compiled clean for as long as it existed and
  would have passed a garbage pathlen at runtime.

  Fixed by disabling the cache outright on agnos rather than by bridging the call.
  Routing through the stdlib's portable `xstat` would have moved the bug rather than
  removed it: `xstat` bridges the CALL but not the STRUCT, and every offset this file
  reads (`st_mode` @24, `st_uid` @28, `st_size` @48, `st_mtim.tv_sec` @88) is Linux
  x86_64 `struct stat`, while agnos's is a 48-byte all-u64 record with a different
  field order and **no `st_uid` at all** (AGNOS userland ABI §4.1). The F-3 ownership
  audit that gates the cache therefore cannot be satisfied on agnos — `getuid` is a
  stub returning 0 for every process and `sys_mkdir(path, pathlen)` takes no mode, so
  0o700 cannot even be requested. An audit that always passes is worse than no cache.

  Nothing is lost: `shellout_capture` already returns -1 on agnos, so the only
  cacheable value — `vcs_render`'s `sit status` output — is never produced there. The
  new `_cache_stat` bridge fails closed on agnos and `cache_init` sets
  `_cache_disabled` before any of this file's remaining Linux-shaped raw syscalls
  (`SYS_MKDIR`, `SYS_UNLINK`, rename #82) can run. Host behaviour is unchanged —
  suite stays **279 passed, 0 failed**.

- **CI installed the toolchain with a pre-6.5 layout that 6.5.x rejects.** Both workflows
  hand-rolled the install: untar the release asset, `mkdir -p $HOME/.cyrius/{bin,lib}`,
  copy the files in. That produces *real* flat directories and no `versions/<v>/` tree at
  all, where the upstream installer lays out `versions/<v>/{bin,lib}` and makes
  `~/.cyrius/bin` and `~/.cyrius/lib` **symlinks** into it. From 6.5.x the toolchain
  resolves the pinned stdlib snapshot at `~/.cyrius/versions/$CYRIUS_VERSION/lib` and
  hard-fails without it:

  ```
  error: cyrius.cyml pins version 6.5.35 but it is not installed at ~/.cyrius/versions/6.5.35/lib
    run: cyrius install 6.5.35
  ```

  This is a latent break that the pin bump in this release detonated — verified by
  reproducing all three cases against the real toolchains: **6.4.66 + flat layout**
  `deps`/`build` both rc=0; **6.5.35 + flat layout** both hard-fail with the error above;
  **6.5.35 + installer layout** both rc=0. So the hand-rolled block was fine through
  1.1.3 and could not survive 6.5.x, independent of anything in `src/`.

  Both workflows now read the `cyrius.cyml` pin (still the single source of truth — no
  hardcoded version in YAML) and hand it to the upstream `scripts/install.sh`, which also
  does the SHA256 + signature verification the hand-rolled block skipped. A new **Verify
  toolchain layout** step asserts `versions/$CYRIUS_VERSION/lib` exists and runs `cyrius
  version`, so a bad install fails at the install step with a clear `::error::` instead of
  surfacing later as a confusing dep-resolution failure. Pattern taken from darshana /
  patra / libro. Also refreshed the `Test` step's rationale comment, which justified the
  explicit `cyrius test <file.tcyr>` form by reference to a `6.0.56` pin this repo left
  behind three releases ago; the command is unchanged and still correct.

- **`scripts/bench-history.sh` silently dropped every decimal-average row** — including
  `render_prompt`, the one metric with a budget. This is the same 6.4.x decimal-output
  breakage that 1.1.3 fixed in `bench-gate.sh`, in the sibling script it missed. The
  skip-filter guarding the parse loop used an integer-only `[0-9]+(ns|us|ms)`: against
  `config_default: 2.835us avg` it matches the `2`, then needs a unit and finds `.`, so
  the row was treated as a non-bench line and skipped. Only the integer-average rows
  (`cwd_render: 715ns`) survived — 5 of 12. Because the script counts what it appended
  and exits 0, it reported success every time, which is why `history.csv` has no rows
  between **0.9.0 and 1.1.4** despite the releases in between. The guard now accepts an
  optional fraction, matching the `[0-9.]+` the value-extraction seds already used.
  Verified: 12 of 12 rows recorded, the 6.5.x harness's new `[timer floor 1.256us per
  clock read …]` line still correctly skipped, and the comma in `vcs_render (cached, 1s
  TTL)` still escaped to `;`. No change to `bench-gate.sh`, which parses 6.5.x output
  correctly as shipped.

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
