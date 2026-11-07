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
2. Defines `_cmdrs_precmd`: captures `$?` into `$AGNOSHI_LAST_EXIT`, renders both sides, and keeps the bytes in `$_cmdrs_left` and `$_cmdrs_right`.
3. Doubles every `%`, so segment content is text rather than prompt escapes, and wraps each colour sequence in `%{ %}`, so zsh counts it as zero-width. Without that, long input lines overwrite the prompt.
4. Sets `PROMPT` and `RPROMPT` to a **fixed reference** to those variables, and turns `prompt_subst` on so the reference expands. This is what makes the prompt safe: see the security note below.
5. Appends `_cmdrs_precmd` to `precmd_functions` so it runs before every prompt — without clobbering other hooks you may have.

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
- `rustup_env` — `rust-toolchain` or `rust-toolchain.toml` in an ancestor.

A typical render inside a Python project with a venv active and a dirty sit repo:

```
~/work/myproj main* myproj 22:47 $
```

For a curated theme drop-in, see [`docs/themes/`](../themes/).

## Caveats

- **`cmdrs` is single-invocation.** No persistent daemon, no precmd-async. Whatever each segment costs is paid every redraw. The 5 ms cold-start budget ([`docs/architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)) is what governs the per-segment surface; the M6 cache layer (v0.7.0) means `vcs` runs ~7.6 µs cached.
- **`RPROMPT` is zsh-only.** bash has no native right-prompt; the bash adapter omits the `--side=right` call.

## Manual setup (no adapter)

If you prefer to inline the hook rather than `source` the adapter, the equivalent paste is:

```zsh
typeset -g _cmdrs_left='' _cmdrs_right=''
setopt prompt_subst prompt_percent
_cmdrs_zsh_render() {
  emulate -L zsh                  # REQUIRED: keeps your options away from the bytes
  setopt extendedglob
  local MATCH MBEGIN MEND open='%{' close='%}' s
  s="$(cmdrs)"
  s=${s//\%/%%}                   # REQUIRED: `%` doubled
  _cmdrs_left=${s//(#m)$'\e'\[[0-9;]#m/$open$MATCH$close}
  s="$(cmdrs --side=right)"
  s=${s//\%/%%}
  _cmdrs_right=${s//(#m)$'\e'\[[0-9;]#m/$open$MATCH$close}
}
_cmdrs_precmd() {
  export AGNOSHI_LAST_EXIT=$?
  _cmdrs_zsh_render
  setopt prompt_subst prompt_percent
  PROMPT='${_cmdrs_left}'         # REQUIRED: single quotes, a reference, never the bytes
  RPROMPT='${_cmdrs_right}'       # REQUIRED: the same
}
(( ${precmd_functions[(I)_cmdrs_precmd]} )) || precmd_functions+=(_cmdrs_precmd)
```

Same behavior; no path caching.

## Security: the prompt variable holds a reference, never the bytes

**This applies to any hand-rolled setup, including the paste above.**

`cmdrs` renders bytes it does not choose — a directory name, a `sit` branch name, the
contents of `.python-version` / `.nvmrc` / `rust-toolchain` / `VERSION`, `$VIRTUAL_ENV`. A
repository you merely `cd` into picks those bytes. `cmdrs` strips control bytes, but `$`,
`(`, `)`, `` ` `` and `%` are ordinary printable characters and pass through as text —
correctly, they are legal in a branch name.

So the prompt string is **data, not a script**:

- **Never put the rendered bytes in `PROMPT` or `RPROMPT`.** With `prompt_subst` on, zsh
  runs command substitution on those variables at every redraw. Keep the bytes in another
  variable and set `PROMPT='${_cmdrs_left}'`. zsh expands that once and does not re-parse
  the value, so whatever it holds cannot run.
- **Do not rely on `prompt_subst` being off.** Until 1.2.3 this guide said to leave it off.
  That is not enough: `promptinit` themes set it through `prompt_opts`, so stock zsh with
  `prompt adam2` ran commands from a directory name
  ([2026-11-06 audit](../audit/2026-11-06-audit.md), T-01; [ADR 0011](../adr/0011-prompt-holds-a-reference-not-the-bytes.md)).
  The adapter now turns the option on, and nothing depends on it. If something turns it off
  afterwards, the prompt shows the text `${_cmdrs_left}`, which is ugly and safe.
- **Touch the bytes only under `emulate -L zsh`.** With `glob_subst glob_assign` on, even
  `var=$bytes` is a glob, and a qualifier like `(e:...:)` in a repo's file runs a command.
- **Double `%` → `%%`.** zsh expands `%` prompt escapes after the substitution, whatever the
  option says, so this is a separate channel that the same input reaches.

Sourcing the adapter leaves `prompt_subst` on for the session. If your own `PS2` or
similar contains `$`, it will now expand.

Same class as CVE-2021-3934 (oh-my-zsh, branch name via `print -P`) and CVE-2021-45444
(zsh `PROMPT_SUBST`). To self-test any prompt setup, use a directory name, because the
default segments do not read `.python-version`:

```sh
mkdir -p '/tmp/t/$(touch PWNED)' && cd '/tmp/t/$(touch PWNED)'
```

Press enter a few times, then run `ls`. Do this with `setopt prompt_subst` in your shell as
well. No `PWNED` file may appear.

## Reverting to starship

Re-enable the `eval "$(starship init zsh)"` line you commented out in `~/.zshrc`, comment out the `source .../adapters/zsh.sh` line, and `exec zsh`. Both prompt systems are stateless — switching is just which `$PROMPT` setter wins on the next redraw.
