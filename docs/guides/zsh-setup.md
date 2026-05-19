# Using `cmdrs` in zsh

> **Status**: Shipped — `adapters/zsh.sh` is a first-party adapter as of v0.8.0 (M7). The previous "testing recipe" inlined the precmd hook by hand; that's now a single `source` line.

`cmdrs` reads shell context from env vars and writes the prompt to stdout — one invocation per redraw, no shell-specific code. zsh's `precmd` hook plus a tiny wrapper does the integration. This page covers the adapter install + the one customization knob most users care about.

## Install

Build + place `cmdrs` on `$PATH` (skip if already installed):

```sh
cyrius build src/main.cyr build/cmdrs
sudo install -m 0755 build/cmdrs /usr/local/bin/cmdrs
# or, without sudo (assumes ~/.local/bin is on PATH):
install -Dm 0755 build/cmdrs ~/.local/bin/cmdrs
```

Then add one line to `~/.zshrc`:

```zsh
source /path/to/commandress/adapters/zsh.sh
```

Or, for a system-wide install of the adapter:

```sh
sudo install -m 0644 adapters/zsh.sh /usr/share/commandress/zsh.sh
echo 'source /usr/share/commandress/zsh.sh' >> ~/.zshrc
```

Open a new shell — or `exec zsh` — and the prompt switches over.

## What the adapter does

[`adapters/zsh.sh`](../../adapters/zsh.sh):

1. Resolves `cmdrs` once at source time and caches it in `$_CMDRS`. Per-redraw cost is one shell builtin lookup, not a PATH walk.
2. Sets `prompt_subst` (zsh's option for evaluating `$(...)` inside `$PROMPT` on each redraw).
3. Defines `_cmdrs_precmd`: captures `$?` into `$AGNOSHI_LAST_EXIT`, assigns `PROMPT="$($_CMDRS)"`, assigns `RPROMPT="$($_CMDRS --side=right)"`.
4. Appends `_cmdrs_precmd` to `precmd_functions` so it runs before every prompt — without clobbering other hooks you may have.

## Customize via `COMMANDRESS_BIN`

If `cmdrs` isn't on `$PATH` — or you want to switch between builds — set `COMMANDRESS_BIN` *before* sourcing the adapter:

```zsh
export COMMANDRESS_BIN=~/repos/commandress/build/cmdrs
source /path/to/commandress/adapters/zsh.sh
```

The adapter prefers `COMMANDRESS_BIN` over the PATH-resolved `cmdrs`.

## Example config

`~/.commandress` lights up a full set of segments plus a right-side time:

```cyml
[[prompt]]
segments       = ["cwd", "vcs", "cyrius_env", "python_env", "node_env", "rustup_env", "exit"]
right_segments = ["time"]
separator      = " "
trailer        = " $ "

[[segments.cwd]]
home_shorten = true

[[segments.exit]]
hide_zero = true

[[segments.vcs]]
show_dirty   = true
dirty_marker = "*"
```

Each env segment renders only when its condition is met:

- `cyrius_env` — inside a Cyrius project (`cyrius.cyml` in an ancestor). Emits the trimmed contents of `<root>/VERSION`, or `cyrius --version` as fallback.
- `python_env` — `$VIRTUAL_ENV` set (emits its basename) or a `.python-version` file in an ancestor.
- `node_env` — `.nvmrc` in an ancestor.
- `rustup_env` — `rust-toolchain` (plain-format) in an ancestor.

A typical render inside a Python project with a venv active and a dirty sit repo:

```
~/work/myproj main* myproj 22:47 $
```

For a curated theme drop-in, see [`docs/themes/`](../themes/).

## Caveats

- **`cmdrs` is single-invocation.** No persistent daemon, no precmd-async. Whatever each segment costs is paid every redraw. The 5 ms cold-start budget ([`docs/architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)) is what governs the per-segment surface; the M6 cache layer (v0.7.0) means `vcs` runs ~7 µs cached.
- **`RPROMPT` is zsh-only.** bash has no native right-prompt; the bash adapter omits the `--side=right` call.

## Manual setup (no adapter)

If you prefer to inline the hook rather than `source` the adapter, the equivalent paste is:

```zsh
setopt prompt_subst
_cmdrs_precmd() {
  export AGNOSHI_LAST_EXIT=$?
  PROMPT="$(cmdrs)"
  RPROMPT="$(cmdrs --side=right)"
}
precmd_functions+=(_cmdrs_precmd)
```

Same behavior; no path caching.

## Reverting to starship

Re-enable the `eval "$(starship init zsh)"` line you commented out in `~/.zshrc`, comment out the `source .../adapters/zsh.sh` line, and `exec zsh`. Both prompt systems are stateless — switching is just which `$PROMPT` setter wins on the next redraw.
