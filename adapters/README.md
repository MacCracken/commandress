# Shell adapters

Sourceable shell scripts that wire `cmdrs` into a shell's prompt loop. One `source` line in your rc file does the integration — no inline `precmd` / `PROMPT_COMMAND` recipes to maintain by hand.

## Available adapters

| Adapter | Shell | Status | Detailed guide |
|---|---|---|---|
| [`zsh.sh`](zsh.sh) | zsh | ✓ Live — `precmd` + `PROMPT` + `RPROMPT` | [`zsh-setup.md`](../docs/guides/zsh-setup.md) |
| [`bash.sh`](bash.sh) | bash | ✓ Live — `PROMPT_COMMAND` + `PS1`; left-only (no native RPROMPT) | [`bash-setup.md`](../docs/guides/bash-setup.md) |
| [`agnoshi.sh`](agnoshi.sh) | [agnoshi](https://github.com/MacCracken/agnoshi) | ⏳ Contract-only — agnoshi hasn't adopted `$AGNOSHI_PROMPT_CMD` yet; the file documents the spec and sets the env var so adoption flips the prompt over with no further change here | header comment inside `agnoshi.sh` |

## One-line install

```sh
# Pick the line matching your shell:
echo 'source /path/to/commandress/adapters/zsh.sh' >> ~/.zshrc
echo 'source /path/to/commandress/adapters/bash.sh' >> ~/.bashrc
echo 'source /path/to/commandress/adapters/agnoshi.sh' >> ~/.profile   # any rc that's read before `agnsh` starts
```

Open a new shell — or `exec zsh` / `exec bash` — and the prompt switches over.

## What every adapter does

- Captures `$?` into `$AGNOSHI_LAST_EXIT` *first* (any later statement clobbers it). `cmdrs`'s `exit` segment reads that env var.
- Caches the resolved `cmdrs` path in `$_CMDRS` so per-redraw cost is one builtin lookup, not a PATH walk. `COMMANDRESS_BIN` overrides.
- Runs `cmdrs` (left side) — and on zsh, also `cmdrs --side=right` for `RPROMPT` — once per prompt redraw. The output is the prompt string, possibly with ANSI SGR escapes inside it.

## Shell-specific quirks

- **bash needs `\001..\002` markers around non-printable ANSI escapes** for readline's width accounting. `bash.sh` wraps via a one-line `sed` filter on `cmdrs` output. `cmdrs` itself stays shell-agnostic.
- **bash has no native right-prompt.** `right_segments` in `~/.commandress` is silently unused under bash. Use zsh if you want them.
- **zsh needs `setopt prompt_subst`** to evaluate `$(cmdrs)` inside `$PROMPT` per redraw. `zsh.sh` sets it.
- **agnoshi will need to set `$AGNOSHI_LAST_EXIT`** before invoking the prompt command, and capture stdout as the prompt string. Spec lives in [`agnoshi.sh`](agnoshi.sh)'s header comment until agnoshi co-signs.

## Customization

Every adapter respects `$COMMANDRESS_BIN` (set it before sourcing) to point at a non-PATH `cmdrs` binary — useful when iterating between builds.

Prompt content + colour live in `~/.commandress` (see [`../docs/themes/`](../docs/themes/) for ready-made themes). Adapters don't customize the prompt; they're glue.
