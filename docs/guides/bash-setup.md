# Using `cmdrs` in bash

> **Status**: Shipped — `adapters/bash.sh` is a first-party adapter as of v0.8.0 (M7).

`cmdrs` reads shell context from env vars and writes the prompt to stdout — one invocation per redraw, no shell-specific code. bash's `PROMPT_COMMAND` plus a small wrapper does the integration. This page covers the adapter install + the one bash-specific quirk it handles for you.

## Install

Build + place `cmdrs` on `$PATH` (skip if already installed):

```sh
cyrius build src/main.cyr build/cmdrs
sudo install -m 0755 build/cmdrs /usr/local/bin/cmdrs
# or, without sudo (assumes ~/.local/bin is on PATH):
install -Dm 0755 build/cmdrs ~/.local/bin/cmdrs
```

Then add one line to `~/.bashrc`:

```bash
source /path/to/commandress/adapters/bash.sh
```

Or, for a system-wide install of the adapter:

```sh
sudo install -m 0644 adapters/bash.sh /usr/share/commandress/bash.sh
echo 'source /usr/share/commandress/bash.sh' >> ~/.bashrc
```

Open a new shell — or `exec bash` — and the prompt switches over.

## What the adapter does

[`adapters/bash.sh`](../../adapters/bash.sh):

1. Resolves `cmdrs` once at source time and caches it in `$_CMDRS`. Per-redraw cost is one `command -v` lookup at startup, not a PATH walk on every prompt.
2. Turns **`promptvars` off** (`shopt -u promptvars`) and doubles every `\` in the rendered bytes before assigning `PS1` — both are security-critical, see the note below.
3. Defines `_cmdrs_prompt_command`: captures `$?` into `$AGNOSHI_LAST_EXIT`, assigns `PS1` from `cmdrs` output.
4. Wraps each ANSI SGR escape (`\x1b[...m`) in `\001..\002` markers so bash's readline-width accounting treats them as zero-width. Without this, lines wrap to the wrong column because bash counts colour bytes as visible characters.
5. Prepends to `PROMPT_COMMAND` so other tools' hooks keep running.

The wrap step is bash-specific. zsh handles raw ANSI escapes in `$PROMPT` correctly without markers; bash needs `\001..\002` around non-printables. The adapter handles it via a one-line `sed` filter on `cmdrs` output — `cmdrs` itself stays shell-agnostic.

## Customize via `COMMANDRESS_BIN`

If `cmdrs` isn't on `$PATH` — or you want to switch between builds — set `COMMANDRESS_BIN` *before* sourcing the adapter:

```bash
export COMMANDRESS_BIN=~/repos/commandress/build/cmdrs
source /path/to/commandress/adapters/bash.sh
```

The adapter prefers `COMMANDRESS_BIN` over the PATH-resolved `cmdrs`.

## Example config

Use the same `~/.commandress` as zsh — the config file is shell-agnostic. See [`zsh-setup.md`](zsh-setup.md#example-config) for the example.

For curated theme drop-ins, see [`docs/themes/`](../themes/).

## What's missing vs zsh

- **No right-prompt.** bash has no native `RPROMPT` analogue. Cursor-position tricks exist but are brittle (resize, line-wrap, and history-edit all break them); we don't ship them. If your `~/.commandress` declares `right_segments`, those segments are silently unused under bash. Use zsh if you want a right-prompt.

## Caveats

- **`cmdrs` is single-invocation.** No persistent daemon. The 5 ms cold-start budget ([`docs/architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)) is what governs the per-segment surface; the M6 cache layer (v0.7.0) makes `vcs` cost ~7.6 µs cached.
- **The `sed` wrap adds a small (~µs) cost per redraw.** Negligible against the prompt-budget envelope.

## Manual setup (no adapter)

```bash
shopt -u promptvars          # REQUIRED — see the security note below
_cmdrs_prompt_command() {
  local exit_code=$?
  export AGNOSHI_LAST_EXIT=$exit_code
  local _raw
  _raw=$(cmdrs | sed $'s/\x1b\\[[0-9;]*m/\x01&\x02/g')
  PS1=${_raw//\\/\\\\}       # REQUIRED — backslashes doubled
}
PROMPT_COMMAND="_cmdrs_prompt_command${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
```

Same behavior as the adapter; no path caching.

## Security: the prompt string is data, not a script

**This applies to any hand-rolled setup, including the paste above.** Both lines marked
REQUIRED are load-bearing, and bash needs *both* because they close different channels.

`cmdrs` renders bytes it does not choose — a `sit` branch name, the contents of
`.python-version` / `.nvmrc` / `rust-toolchain` / `VERSION`, `$VIRTUAL_ENV`. A repository
you merely `cd` into picks those bytes. `cmdrs` strips control bytes, but the characters
below are printable and pass through as text, correctly so.

- **`shopt -u promptvars`.** The option is **on by default**, and it applies parameter
  expansion *and command substitution* to `PS1` at every redraw — so a repo shipping
  `.python-version` containing `$(...)` executes it on every keystroke. Confirmed and
  fixed in v1.1.6 ([2026-08-26 audit](../audit/2026-08-26-audit.md), finding P-01).
- **Double `\` → `\\`.** Bash's prompt backslash decoding is **unconditional** — turning
  `promptvars` off does not touch it. `\` and `e` are printable, so `\e[31m` survives the
  sanitizer and bash then decodes it into a real ESC inside the shell, reconstructing the
  control byte on the far side of the filter (finding A-04).

Note the trade-off: `shopt` is shell-global, so this disables `promptvars` for the whole
session. If your own `PS1` relies on `$(...)` expanding at render time, compute it in
`PROMPT_COMMAND` instead.

To self-test any prompt setup: put `$(touch /tmp/x)` in a `.python-version`, `cd` there,
press enter a few times, and confirm `/tmp/x` does not appear.

## Reverting to starship

Re-enable the `eval "$(starship init bash)"` line in `~/.bashrc`, comment out the `source .../adapters/bash.sh` line, and `exec bash`. Both prompt systems are stateless — switching is just which `PS1` setter wins on the next redraw.
