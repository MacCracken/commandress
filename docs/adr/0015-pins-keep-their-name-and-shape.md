# 0015 — A symlinked pin must keep its name, a pin has a shape, and repo text has a length

**Status**: Accepted
**Date**: 2026-11-06

## Context

The [2026-11-06 audit](../audit/2026-11-06-audit.md) left two gaps for this release. T-05: pin files follow symlinks, so `ln -s ~/.ssh/id_ed25519 .python-version` shows the start of that file. And a hostile repo could still push text into every redraw: 255 bytes from a pin file, 8,182 from a `sit` branch, and more through `VIRTUAL_ENV`. The audit proposed one fix for both, a shape rule for a version string.

**The shape rule cannot do the first job.** What a pin may legally be, from each tool's own source or docs:

| Tool | Accepts |
|---|---|
| pyenv | Any word on a line, including a virtualenv name such as `my-venv`. Reads the first word of each line, skips blank and `#` lines |
| uv | `3.12`, `cpython@3.12`, `>=3.12,<3.13`, `~=3.14`, `!=3.9`, `3.13+freethreaded`, `cpython-3.12.3-linux-x86_64-gnu`, an interpreter path |
| nvm | `v18.16.0`, `lts/iron`, `lts/*`, `lts/-1`, any alias. A `#` starts a comment anywhere, and `key=value` lines are ignored |
| rustup | `<channel>[-<date>][-<host>]`, and any name for a custom toolchain |

A bare word has to pass, so a one-word token file passes too. Replayed with fake files through 1.4.1:

| `.python-version` is a symlink to | The prompt shows |
|---|---|
| a one-word token file | **The whole token.** It looks like a virtualenv name |
| a private key | The header and the start of the key body |
| a one-line `.env` | The whole line |
| `/proc/self/environ` | **The start of the environment.** A regular file as far as `fstat` can tell, and not in the audit |
| `/proc/self/cmdline`, `/proc/version` | Their contents |

A shape rule tight enough to refuse a token would refuse `my-venv`. `O_NOFOLLOW` alone would blank `.nvmrc -> ../.nvmrc` in a monorepo.

**The reader was also wrong on valid files.** It showed the whole trimmed file, and the sanitizer then removed the newlines:

| File | Rendered |
|---|---|
| Two versions, as pyenv writes them | `3.12.13.11.4` |
| A comment, then a version | `# pinned3.12.1` |
| `20#pinned`, which nvm reads as `20` | `20#pinned` |

## Decision

**A symlinked pin must end at a file of the same name. A pin is the first word of its first meaningful line, shaped like a version. Every segment takes `max_length`, on by default at 128 bytes wherever a repo or the environment chooses the text.**

### The name rule, for secrets

- **Repo files go through `read_pin_file`**: pins, `VERSION`, `package.json` and both toolchain files. `~/.commandress` stays on `read_regular_file`, since it is the user's own and a dotfile manager may link it from anywhere.
- **`O_NOFOLLOW` first**, so a plain file pays nothing. On `ELOOP` the link is opened and the kernel is asked what `fd` is through `/proc/self/fd/<n>`, so a chain counts by where it ends and a swap of the link cannot get around it. With no `/proc` there is no answer, and that refuses.
- **What counts as the same name**: a leading dot is ignored on either side, and an extension is allowed on the target. So `.nvmrc -> ../.nvmrc`, `~/.nvmrc -> ~/dotfiles/nvmrc` and `rust-toolchain -> rust-toolchain.toml` all work. `.nvmrc` may also end at `.node-version`, because repos link those two.
- **A regular file in the repo is not affected.** It is the repo's own content, so it has no secret of the user's to show.

### The shape, for what a repo can put on the screen

- **`pin_word`** reads the way the tools do: skip blank lines, `#` comments and `key=value` lines, take the first word, ignore the rest. A `#` ends a word. A word that fails renders nothing, rather than falling through to the next line.
- **Only whole lines count.** The read stops at 256 bytes, and a cut word is a wrong version: a comment that fills the cap would turn `3.11.14` into `3.11.1`. A file over the cap is read up to its last whole line.
- **At most 64 ASCII characters** of `[0-9A-Za-z.+_@*/=<>,~!-]`. ASCII only, so a pin cannot carry a bidi override.
- **A `rust-toolchain` value** gets the same check, as a whole value.
- **`engines.node`** is a range, so it also allows space, `^` and `|`, and keeps its 255-byte limit. Each word must be an operator or a version, which after any operator and a `v` starts with a digit or is an x-range. Letters only ever follow a number, so a range cannot spell `run curl evil.example to fix your shell`. All 2,114 real values surveyed render unchanged through the binary, and the longest is 51 bytes.
- **A `VERSION` that fails stops `cyrius_env`**, as any pin stops its segment. It used to fall through to `cyrius --version`, which would present the toolchain's version as the project's. With no `VERSION` at all, the fallback still runs.

This does not protect a secret, and is not meant to. `=` is legal because uv needs it, so `TOKEN=abc` has the shape of a pin. The name rule is what keeps it out.

### `max_length`, for what has no shape

- **On every segment**, in bytes, `0` for no limit. Additive under [ADR 0007](0007-schema-freeze.md). A refused value warns and keeps the default, as `budget_ms` does. `cwd` now does too: its good values read as they always did, and `10x`, which used to act as `10`, warns.
- **Default 128 on `vcs`, `python_env`, `node_env`, `rustup_env` and `cyrius_env`.** A repo chooses a branch name, and the environment chooses `VIRTUAL_ENV`. An opt-in cap would leave the gap open for everyone who has not set it. The longest of 539 real branch names across 141 repos is 38 bytes, so this is a limit on a flood and not on a name.
- **Default no limit on `exit`, `time`, `hostname` and `user`.** No repo sets those.
- **`cwd` is unchanged.** Its `max_length` is frozen at `0`, and it keeps cutting at a `/` and keeping the tail, because the tail is where you are.
- **A cut keeps the head, ends in `...`, and counts the dots**, so the result is at most N bytes. Under 4 it is dots alone, as `cwd` does. It stays on a character boundary, and `vcs` carries the dirty marker past the cut.
- **It runs in the dispatchers, before the sanitizer**, which only ever removes bytes. So the limit holds on what reaches the terminal, and the sanitizer stays the one place that decides what is safe.

## Consequences

- **Positive** — T-05 is closed for every repo-chosen file, including paths the audit did not list. Replayed through the shipped binary: a token, a key, a `.env`, `/proc/self/environ`, `/proc/self/cmdline`, `/proc/version` and a chain of links all render nothing, and a fuzz of hostile repos with canary files found none on stdout. The same fuzz finds them at once on 1.4.1.
- **Positive** — Multi-line and commented pins now read correctly, and a pin cannot carry escapes or Unicode lookalikes.
- **Positive** — Text a hostile repo can put in a default prompt drops from 8,182 bytes to 128.
- **Negative** — A pin symlinked to a differently named file renders empty, such as `.nvmrc -> shared-node.txt`. Renaming the target or using a real file fixes it. Empty is the safe direction.
- **Negative** — With no `/proc`, a pin that is a symlink renders empty, even if the name is right.
- **Negative** — A pin below a comment that reaches past 256 bytes renders empty. Better than a cut version.
- **Negative** — uv's `--resolved` path renders empty when it is over 64 bytes, as most are. It is a path, not a version. A specifier written with a space, `>=3.12, <3.20`, shows its first clause.
- **Negative** — A non-ASCII virtualenv name in `.python-version` renders empty. `VIRTUAL_ENV` itself has no shape rule, so an active venv of that name still shows.
- **Negative** — A branch name over 128 bytes is cut by default. `max_length = 0` under `[[segments.vcs]]` turns that off.
- **Neutral** — T-06 stands, on purpose. A co-tenant's `/tmp/.python-version` or `/tmp/package.json` still applies under `/tmp`, because an owner check would blank pins in shared checkouts and containers. It is now one word of at most 64 characters, or a semver range.
- **Negative** — `sit` follows a symlinked `.git` or `.sit/HEAD`, so a repo can show the branch name of another repo it can name a path to. `sit` only prints something shaped `ref: refs/...`, so a token file shows `(detached)`. `cmdrs` only sees the output, so the fix belongs in `sit`. It is on the roadmap.
- **Neutral** — `agnos` is unchanged. `read_pin_file` is `file_read_all` there, as `read_regular_file` already was, and the roadmap's agnoshi row already says those guards must be reviewed when `cmdrs_getcwd` reads `$PWD`.

## Alternatives considered

- **The shape rule alone, as the audit proposed.** Leaves the one-word token, which it would show in full, because no rule can tell it from `my-venv`. It does not stop a one-line `.env` either, since uv needs `=`.
- **`O_NOFOLLOW` alone.** Closes T-05 and blanks every monorepo pin.
- **Refuse a link that leaves the repo.** There is no repo root to compare with: `cmdrs` walks up for a pin and knows nothing else about the tree, and `~/.nvmrc -> ~/dotfiles/nvmrc` is legitimate.
- **An allow-list of targets, or a deny-list of `/proc` and `~/.ssh`.** A list of bad paths is the shape that keeps missing one, and `/proc/self/environ` was missed by the audit.
- **Digit-first pins.** Stops a token, and also `lts/iron`, `stable`, `node` and every virtualenv name.
- **An opt-in cap.** Nothing changes for anyone, and the gap stays open by default.
- **A cap inside `render_prompt`.** One site instead of nine, but it would need a third name-to-field table beside `_sgr_for` and `_bg_for`, and it could not keep the dirty marker.
