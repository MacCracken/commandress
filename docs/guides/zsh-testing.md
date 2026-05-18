# Testing `cmdrs` in zsh

> **Status**: Pre-M7. The first-party zsh adapter ships in v0.8.0 ([roadmap](../development/roadmap.md) M7). This guide is the manual swap-in for testing 0.5.0+ today.

`cmdrs` reads shell context from env vars and writes the prompt to stdout — one invocation per redraw, no shell-specific code. zsh's `precmd` hook is enough to drive it. This page is the four-line recipe + caveats.

## What you'll see

After the swap, your zsh prompt is whatever `cmdrs` renders given the current `~/.commandress.cyml`. With no config file, you get the v0.5.0 default: `<cwd> $ ` (cwd home-shortened, trailing space-`$`-space).

```
~/Repos/commandress $ █
```

To turn on more segments, drop the [example config](#example-config) below.

## Install

Build a fresh `cmdrs` from this repo, then place it somewhere on `$PATH`:

```sh
cyrius build src/main.cyr build/cmdrs
sudo install -m 0755 build/cmdrs /usr/local/bin/cmdrs
# or, without sudo (assumes ~/.local/bin is on PATH):
install -Dm 0755 build/cmdrs ~/.local/bin/cmdrs
```

Confirm it's reachable:

```sh
command -v cmdrs    # → /usr/local/bin/cmdrs (or wherever you put it)
cmdrs               # → prints the default prompt and exits
```

## Wire into zsh

In `~/.zshrc`, comment out whatever currently sets `PROMPT` (commonly `eval "$(starship init zsh)"`), then add:

```zsh
setopt prompt_subst
_cmdrs_precmd() {
  export AGNOSHI_LAST_EXIT=$?
  PROMPT="$(cmdrs)"
}
precmd_functions+=(_cmdrs_precmd)
```

`_cmdrs_precmd` runs before every prompt redraw. It captures the previous command's exit code into `$AGNOSHI_LAST_EXIT` (the env var `cmdrs` reads for the `exit` segment) and replaces `PROMPT` with whatever `cmdrs` printed.

Open a new shell — or `exec zsh` — to pick up the change.

## Example config

`~/.commandress.cyml` lights up the full M4 segment set:

```cyml
[[prompt]]
segments  = ["cwd", "vcs", "cyrius_env", "python_env", "node_env", "rustup_env", "exit"]
separator = " "
trailer   = " $ "

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
~/work/myproj main* myproj exit-3 [3] $
```

## Caveats

- **Monochrome only until v0.6.0.** ANSI color and themed separators are M5. Today every segment renders as plain bytes — readable but unstyled.
- **The `vcs` segment is ~1.8 ms per redraw** (fork + exec of `sit`). Acceptable but visible compared to the µs-range non-shellout segments. M6 caching (1 s TTL on probe results) closes this; until then, `vcs` is opt-in for a reason.
- **`cmdrs` is single-invocation.** No persistent daemon, no precmd-async. Whatever each segment costs is paid every redraw. The 5 ms cold-start budget ([`docs/architecture/001-prompt-render-budget.md`](../architecture/001-prompt-render-budget.md)) is what governs the per-segment surface.
- **No bash adapter recipe yet.** Bash needs a `PROMPT_COMMAND` instead of `precmd`. The shape is similar; M7 covers it.

## Reverting to starship

Re-enable the line you commented out in `~/.zshrc`, comment out the `_cmdrs_precmd` block, and `exec zsh`. Both prompt systems are stateless — switching is just which `PROMPT` setter wins on the next redraw.
