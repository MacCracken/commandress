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
- **zsh must NOT set `prompt_subst`**, and `zsh.sh` deliberately does not. (It did until the 2026-08-26 audit; see the security section below.) The option was never needed: `PROMPT` is assigned from `$( )` inside the `precmd` hook, so by render time it holds finished bytes, not a `$(cmdrs)` to expand.
- **bash sources turn `promptvars` off** (`shopt -u promptvars`), for the same reason. Note this is shell-global, not per-prompt: if your own `PS1` relies on `$(...)`/`${...}` being expanded at render time, that stops working once you source `bash.sh`. That is the intended trade — the alternative leaves a command-execution channel open — and you can render dynamic content by computing it in `PROMPT_COMMAND` instead.
- **agnoshi will need to set `$AGNOSHI_LAST_EXIT`** before invoking the prompt command, and capture stdout as the prompt string. Spec lives in [`agnoshi.sh`](agnoshi.sh)'s header comment until agnoshi co-signs.

## Security: the prompt string is DATA, not a script

`cmdrs` renders bytes it does not choose. A branch name, `.python-version`,
`.nvmrc`, `rust-toolchain`, `VERSION`, `$VIRTUAL_ENV` — a repository you merely
`cd` into picks those. `cmdrs` strips control bytes at the render chokepoint
(audit F-1), but `$`, `(`, `)` and `%` are ordinary printable characters and are
passed through as text, because they are legal in a branch name.

**So the shell must never expand the prompt string.** Both shipped adapters used
to let it, and both executed attacker-chosen commands on every redraw as a
result — confirmed and fixed in the [2026-08-26 audit](../docs/audit/2026-08-26-audit.md)
(finding P-01). The rules an adapter must follow:

| Shell | Rule | Why |
|---|---|---|
| zsh | never `setopt prompt_subst`; double `%` → `%%` | `prompt_subst` runs command substitution on the prompt each redraw; `%` escapes expand even without it |
| bash | `shopt -u promptvars` | on by default, and it applies parameter expansion **and** command substitution to `PS1` |
| agnoshi | pass the bytes through verbatim | the 5-point contract in [`agnoshi.sh`](agnoshi.sh) (audit F-12) |

Same class as CVE-2021-3934 (oh-my-zsh, branch name via `print -P`) and
CVE-2021-45444 (zsh `PROMPT_SUBST`). If you write a new adapter, the test is
simple: put `$(touch /tmp/x)` in a `.python-version`, `cd` there, press enter a
few times, and confirm `/tmp/x` does not appear.

## Customization

Every adapter respects `$COMMANDRESS_BIN` (set it before sourcing) to point at a non-PATH `cmdrs` binary — useful when iterating between builds.

Prompt content + colour live in `~/.commandress` (see [`../docs/themes/`](../docs/themes/) for ready-made themes). Adapters don't customize the prompt; they're glue.
