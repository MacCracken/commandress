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
2. **Does not** set `prompt_subst`, deliberately — see the security note below. It is not needed: the command substitution happens in the hook, so `$PROMPT` holds finished bytes by render time.
3. Defines `_cmdrs_precmd`: captures `$?` into `$AGNOSHI_LAST_EXIT`, renders both sides, and doubles every `%` before assigning `PROMPT` / `RPROMPT`, so segment content is drawn as literal text rather than as zsh prompt escapes.
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

- **`cmdrs` is single-invocation.** No persistent daemon, no precmd-async. Whatever each segment costs is paid every redraw. The 5 ms cold-start budget ([`docs/architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)) is what governs the per-segment surface; the M6 cache layer (v0.7.0) means `vcs` runs ~7.6 µs cached.
- **`RPROMPT` is zsh-only.** bash has no native right-prompt; the bash adapter omits the `--side=right` call.

## Manual setup (no adapter)

If you prefer to inline the hook rather than `source` the adapter, the equivalent paste is:

```zsh
# NOTE: no `setopt prompt_subst`. Do not add it — see the security note below.
_cmdrs_precmd() {
  export AGNOSHI_LAST_EXIT=$?
  local _l _r
  _l="$(cmdrs)"
  _r="$(cmdrs --side=right)"
  PROMPT="${_l//\%/%%}"        # `%` doubled: render segment content literally
  RPROMPT="${_r//\%/%%}"
}
precmd_functions+=(_cmdrs_precmd)
```

Same behavior; no path caching.

## Security: never let zsh expand the prompt string

**This applies to any hand-rolled setup, including the paste above.**

`cmdrs` renders bytes it does not choose — a `sit` branch name, the contents of
`.python-version` / `.nvmrc` / `rust-toolchain` / `VERSION`, `$VIRTUAL_ENV`. A repository
you merely `cd` into picks those bytes. `cmdrs` strips control bytes, but `$`, `(`, `)`
and `%` are ordinary printable characters and pass through as text — correctly, they are
legal in a branch name.

So the prompt string is **data, not a script**:

- **Never `setopt prompt_subst`.** It tells zsh to run command substitution on the prompt
  at every redraw, which turns a repo shipping `.python-version` containing `$(...)` into
  arbitrary command execution on every keystroke. This adapter set it until v1.1.6; the
  [2026-08-26 audit](../audit/2026-08-26-audit.md) (finding P-01) confirmed the execution
  and removed it. It was never needed for this design.
- **Double `%` → `%%`.** zsh expands `%` prompt escapes whether or not `prompt_subst` is
  set, so this is a separate channel that the same input reaches.

Same class as CVE-2021-3934 (oh-my-zsh, branch name via `print -P`) and CVE-2021-45444
(zsh `PROMPT_SUBST`). To self-test any prompt setup: put `$(touch /tmp/x)` in a
`.python-version`, `cd` there, press enter a few times, and confirm `/tmp/x` does not
appear.

## Reverting to starship

Re-enable the `eval "$(starship init zsh)"` line you commented out in `~/.zshrc`, comment out the `source .../adapters/zsh.sh` line, and `exec zsh`. Both prompt systems are stateless — switching is just which `$PROMPT` setter wins on the next redraw.
