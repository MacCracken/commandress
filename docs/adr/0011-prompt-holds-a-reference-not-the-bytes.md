# 0011 — The shell's prompt variable holds a reference, never the rendered bytes

**Status**: Accepted
**Date**: 2026-11-06

## Context

`cmdrs` renders bytes a repository chooses: a directory name, a branch, the contents of `.python-version`. `$`, `` ` ``, `%` and `\` are legal in those, so they pass through as text, and the shell adapters must stop the shell from acting on them.

[P-01](../audit/2026-08-26-audit.md) did that by turning prompt expansion off: `setopt prompt_subst` was removed from `zsh.sh`, and `shopt -u promptvars` was added to `bash.sh`. The rendered bytes stayed in `PROMPT` and `PS1`.

That makes safety depend on shell state the adapter does not own. [The 2026-11-06 audit](../audit/2026-11-06-audit.md) measured the result, across 8 payloads in 12 option states on real shells: 31 of 96 cases ran a command. `prompt_subst` is set by zsh's own `promptinit` themes, so stock zsh with `prompt adam2` ran a command from a directory name under the default config (T-01). Bash ignores `promptvars` in POSIX mode, so `set -o posix`, or just `POSIXLY_CORRECT=1`, did the same (T-02). A later `shopt -s promptvars` reopened it too.

## Decision

**The rendered bytes live in a variable, and the prompt variable holds only a fixed reference to it: `PROMPT='${_cmdrs_left}'`, `RPROMPT='${_cmdrs_right}'`, `PS1='${_cmdrs_ps1}'`. Each adapter turns expansion ON at every redraw.**

Both shells expand a reference once and do not re-parse the value, so what the value holds cannot run. This inverts P-01: expansion is now required, and it is safe because of what the prompt variable contains, rather than what an option says.

Three things follow:

- In bash, backslash decoding runs before expansion and sees only the fixed text, so `\e[31m` in a value stays text. A-04's doubling of every `\` is gone.
- In zsh, `%` expansion runs after substitution whatever the options say, so `%` doubling stays.
- In zsh, the code that handles the bytes runs under `emulate -L zsh`, because the prompt variable is not the only place options can reach them. The first draft of this change assigned `_cmdrs_left=$REPLY` in the hook, and with `glob_subst glob_assign` on that assignment is a glob, so `(e:...:)` in a repo's file ran a command. An independent review caught it before release.

`scripts/adapter-check.sh` proves this on real shells in CI, and fails on both the 1.2.2 adapters and that first draft.

## Consequences

- **Positive** — What `PROMPT` holds no longer depends on what an option says, in any of the states tested. If something turns expansion off, the prompt shows the literal text `${_cmdrs_left}`, which is ugly and harmless. An exported `PS1` reaching a nested shell expands to nothing (T-09).
- **Negative** — Sourcing an adapter turns on `prompt_subst` or `promptvars` for the session, the reverse of 1.1.6. A `PS2` or similar of your own that contains `$` now expands, as you would expect of the shell's default. This is a behaviour change, and it is recorded in the CHANGELOG.
- **Neutral** — A manual paste needs a few more lines, because the reference needs a variable behind it. The guides carry vetted pastes, which were run through `adapter-check.sh`.

## Alternatives considered

- **Force the option off at every redraw.** This keeps the bytes in `PROMPT`, so the safety still depends on an option. It also loses to anything that runs after our hook, and it cannot help in bash's POSIX mode, where there is no off.
- **Escape the bytes so they are inert in both modes.** There is no such string. `\$` is safe with `prompt_subst` on and prints a backslash with it off, and a backtick cannot be split the way `$` can.
- **Pick by mode at each redraw, as `git-prompt.sh` does.** Reference when expansion is on, bytes when it is off. This leaves the user's options alone, but it has two code paths, and a later hook that turns expansion on in the same redraw executes the bytes. Always using the reference has one path and no such window.
