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
2. Defines `_cmdrs_prompt_command`: captures `$?` into `$AGNOSHI_LAST_EXIT` and keeps the rendered bytes in `$_cmdrs_ps1`.
3. Wraps each ANSI SGR escape (`\x1b[...m`) in `\001..\002` markers so bash's readline-width accounting treats them as zero-width. Without this, lines wrap to the wrong column. It does this in pure bash, so a redraw starts no extra process.
4. Sets `PS1` to a **fixed reference** to that variable, and turns `promptvars` on so the reference expands. This is what makes the prompt safe: see the security note below.
5. Prepends to `PROMPT_COMMAND` so other tools' hooks keep running.

zsh needs the same wrap, in its own `%{ %}` form. The adapters handle it; you don't need to think about it.

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

## Manual setup (no adapter)

```bash
_cmdrs_ps1=''
_cmdrs_bash_wrap() {
  local rest=$1 head params
  REPLY=''
  while [[ $rest == *$'\033['* ]]; do
    head=${rest%%$'\033['*}
    rest=${rest#"$head"$'\033['}
    params=${rest%%[!0-9\;]*}
    if [[ ${rest:${#params}:1} == m ]]; then
      REPLY+=$head$'\001\033['$params$'m\002'
      rest=${rest:${#params}+1}
    else
      REPLY+=$head$'\033['
    fi
  done
  REPLY+=$rest
}
_cmdrs_prompt_command() {
  local exit_code=$?
  export AGNOSHI_LAST_EXIT=$exit_code
  local REPLY
  _cmdrs_bash_wrap "$(cmdrs)"
  _cmdrs_ps1=$REPLY
  shopt -s promptvars
  PS1='${_cmdrs_ps1}'        # REQUIRED: single quotes, a reference, never the bytes
}
case "$PROMPT_COMMAND" in
  *_cmdrs_prompt_command*) ;;
  *) PROMPT_COMMAND="_cmdrs_prompt_command${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac
```

Same behavior as the adapter; no path caching.

## Security: the prompt variable holds a reference, never the bytes

**This applies to any hand-rolled setup, including the paste above.** The line marked
REQUIRED is load-bearing.

`cmdrs` renders bytes it does not choose — a directory name, a `sit` branch name, the
contents of `.python-version` / `.nvmrc` / `rust-toolchain` / `VERSION`, `$VIRTUAL_ENV`. A
repository you merely `cd` into picks those bytes. `cmdrs` strips control bytes, but the
characters below are printable and pass through as text, correctly so.

Bash handles `PS1` in two stages, and the bytes must not be in `PS1` for either:

- **Backslash decoding** runs first and is unconditional. With the bytes in `PS1`, a repo's
  six characters `\e[31m` become a real ESC inside the shell, past the sanitizer
  ([2026-08-26 audit](../audit/2026-08-26-audit.md), A-04). With a reference, the decoder
  only ever sees the fixed text.
- **Expansion** runs next. With the bytes in `PS1`, a repo's `$(...)` runs at every redraw
  (P-01). With a reference, bash expands it once and does not re-parse the value.

**Do not rely on `promptvars` being off.** Until 1.2.3 this guide said to run
`shopt -u promptvars`. POSIX mode ignores that option, so `set -o posix`, or just
`POSIXLY_CORRECT=1`, brought the command execution back
([2026-11-06 audit](../audit/2026-11-06-audit.md), T-02; [ADR 0011](../adr/0011-prompt-holds-a-reference-not-the-bytes.md)).
The adapter now turns it on, and nothing depends on it. If something turns it off afterwards,
the prompt shows the text `${_cmdrs_ps1}`, which is ugly and safe.

Sourcing the adapter leaves `promptvars` on, which is bash's own default.

To self-test any prompt setup, use a directory name, because the default segments do not
read `.python-version`:

```sh
mkdir -p '/tmp/t/$(touch PWNED)' && cd '/tmp/t/$(touch PWNED)'
```

Press enter a few times, then run `ls`. Do this after `set -o posix` as well. No `PWNED` file
may appear.

## Reverting to starship

Re-enable the `eval "$(starship init bash)"` line in `~/.bashrc`, comment out the `source .../adapters/bash.sh` line, and `exec bash`. Both prompt systems are stateless — switching is just which `PS1` setter wins on the next redraw.
