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

- **Both shells need colour marked as zero-width**, or a long input line overwrites the prompt. `bash.sh` wraps each SGR in `\001..\002`, and `zsh.sh` in `%{ %}`. `cmdrs` itself stays shell-agnostic and emits plain ANSI.
- **bash has no native right-prompt.** `right_segments` in `~/.commandress` is silently unused under bash. Use zsh if you want them.
- **Sourcing an adapter leaves prompt expansion on**: `prompt_subst` in zsh, `promptvars` in bash. The security section says why. If your own `PS2` or similar contains `$`, it will expand.
- **agnoshi will need to set `$AGNOSHI_LAST_EXIT`** before invoking the prompt command, and capture stdout as the prompt string. Spec lives in [`agnoshi.sh`](agnoshi.sh)'s header comment until agnoshi co-signs.

## Security: the prompt string is DATA, not a script

`cmdrs` renders bytes it does not choose. A directory name, a branch name,
`.python-version`, `.nvmrc`, `rust-toolchain`, `VERSION`, `$VIRTUAL_ENV` — a repository
you merely `cd` into picks those. `cmdrs` strips control bytes at the render chokepoint
(audit F-1), but `$`, `(`, `)`, `` ` ``, `%` and `\` are ordinary printable characters
and are passed through as text, because they are legal in a branch name.

**So the rendered bytes must never be in the shell's prompt variable.** Keep them in
another variable, and set the prompt variable to a fixed reference to it. The shell
expands that once and does not re-parse the value. See
[ADR 0011](../docs/adr/0011-prompt-holds-a-reference-not-the-bytes.md).

The 2026-08-26 audit (P-01) tried turning prompt expansion off instead, and that is not
enough: stock zsh themes turn it back on, and bash's POSIX mode ignores the option. The
[2026-11-06 audit](../docs/audit/2026-11-06-audit.md) found both (T-01, T-02). The rules
an adapter must follow:

| Shell | Rule | Why |
|---|---|---|
| zsh | `PROMPT='${var}'`, single quotes, with `prompt_subst` on; double `%` → `%%` | `prompt_subst` runs command substitution on `PROMPT` each redraw; `%` escapes expand after it, whatever the option says |
| bash | `PS1='${var}'`, single quotes, with `promptvars` on | backslash decoding is unconditional, and POSIX mode expands `PS1` whatever the option says |
| agnoshi | pass the bytes through verbatim | the 5-point contract in [`agnoshi.sh`](agnoshi.sh) (audit F-12) |

Do not run an external tool from a redraw hook, either. `bash.sh` used to pipe through
`sed`, which `$PATH` resolved on every redraw, so `.` ahead of `/usr/bin` ran a `sed` from
the repo you had just entered (T-04).

Same class as CVE-2021-3934 (oh-my-zsh, branch name via `print -P`) and
CVE-2021-45444 (zsh `PROMPT_SUBST`). `git-prompt.sh` uses the same indirection for
branch names. If you write a new adapter, add it to
[`scripts/adapter-check.sh`](../scripts/adapter-check.sh), which CI runs. It stands in a
directory whose name is the attack, across the option states that used to let it through.
Use a directory name rather than `.python-version`, because the default segments do not
read that file, so the test can pass on a vulnerable setup (T-10).

## Customization

Every adapter respects `$COMMANDRESS_BIN` (set it before sourcing) to point at a non-PATH `cmdrs` binary — useful when iterating between builds.

Prompt content + colour live in `~/.commandress` (see [`../docs/themes/`](../docs/themes/) for ready-made themes). Adapters don't customize the prompt; they're glue.
