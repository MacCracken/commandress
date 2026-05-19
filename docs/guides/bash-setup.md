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
2. Defines `_cmdrs_prompt_command`: captures `$?` into `$AGNOSHI_LAST_EXIT`, assigns `PS1` from `cmdrs` output.
3. Wraps each ANSI SGR escape (`\x1b[...m`) in `\001..\002` markers so bash's readline-width accounting treats them as zero-width. Without this, lines wrap to the wrong column because bash counts colour bytes as visible characters.
4. Prepends to `PROMPT_COMMAND` so other tools' hooks keep running.

The wrap step is bash-specific. zsh handles raw ANSI escapes in `$PROMPT` correctly without markers (with `prompt_subst` set); bash needs `\001..\002` around non-printables. The adapter handles it via a one-line `sed` filter on `cmdrs` output — `cmdrs` itself stays shell-agnostic.

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

- **`cmdrs` is single-invocation.** No persistent daemon. The 5 ms cold-start budget ([`docs/architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)) is what governs the per-segment surface; the M6 cache layer (v0.7.0) makes `vcs` cost ~7 µs cached.
- **The `sed` wrap adds a small (~µs) cost per redraw.** Negligible against the prompt-budget envelope.

## Manual setup (no adapter)

```bash
_cmdrs_prompt_command() {
  local exit_code=$?
  export AGNOSHI_LAST_EXIT=$exit_code
  PS1=$(cmdrs | sed $'s/\x1b\\[[0-9;]*m/\x01&\x02/g')
}
PROMPT_COMMAND="_cmdrs_prompt_command${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
```

Same behavior as the adapter; no path caching.

## Reverting to starship

Re-enable the `eval "$(starship init bash)"` line in `~/.bashrc`, comment out the `source .../adapters/bash.sh` line, and `exec bash`. Both prompt systems are stateless — switching is just which `PS1` setter wins on the next redraw.
