# commandress — bash adapter.
#
# Source from your ~/.bashrc:
#
#   source /path/to/commandress/adapters/bash.sh
#
# Or for a system-wide install:
#
#   sudo install -m 0644 adapters/bash.sh /usr/share/commandress/bash.sh
#   echo 'source /usr/share/commandress/bash.sh' >> ~/.bashrc
#
# What it does:
#   1. Resolves `cmdrs` once (cached in $_CMDRS) so per-prompt redraw
#      doesn't re-walk PATH. Override with COMMANDRESS_BIN if needed.
#   2. Hooks PROMPT_COMMAND to capture $? into $AGNOSHI_LAST_EXIT and
#      keep the rendered bytes in $_cmdrs_ps1. PS1 is a fixed reference to
#      that variable. See the security note below: this is what makes the
#      prompt data rather than a script.
#   3. Wraps ANSI SGR sequences in \001..\002 markers so bash's prompt-
#      width accounting treats them as zero-width. Without this, lines
#      wrap to the wrong column because bash counts colour escape
#      bytes as visible characters.
#
# What it doesn't do:
#   - **No right-prompt.** bash has no native RPROMPT analogue (cursor-
#     position tricks exist but are brittle). Right-side segments
#     configured in `~/.commandress` are silently ignored under bash.
#     Use zsh if you want them.
#
# Override path priority:
#   COMMANDRESS_BIN > $(command -v cmdrs)

_CMDRS="${COMMANDRESS_BIN:-$(command -v cmdrs 2>/dev/null)}"

if [[ -z "$_CMDRS" ]]; then
  printf 'commandress: cmdrs not on PATH (set COMMANDRESS_BIN or install it)\n' >&2
  return 1
fi

_cmdrs_ps1=''

# $1 with each ANSI SGR escape (`\x1b[...m`) wrapped in \001..\002, in $REPLY, so
# readline's width logic treats it as zero-width.
#
# An `ESC [` need not open an SGR. The sanitizer removes ESC from segment text, but
# `trailer`, `separator` and the glyphs are the user's own and may hold any sequence,
# such as a cursor shape, so the loop passes anything else through. Every path through
# it shortens `rest`, or a config like that would hang every new shell.
#
# Pure bash, because a `sed` here cost a process on every redraw and was found through
# $PATH, so `.` ahead of /usr/bin ran a `sed` from the repo the user had just entered
# (audit 2026-11-06, T-04). The patterns are all ASCII after ESC, which no multibyte
# encoding uses as a lead byte, so this needs no locale of its own. `=~` would be
# shorter, and it would overwrite a user's BASH_REMATCH between their commands.
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

# SECURITY — the prompt is data, and this adapter does not depend on an option.
#
# `cmdrs` output carries bytes chosen by whatever repository the user is standing
# in: a branch name, a directory name, `.python-version` / `.nvmrc` /
# `rust-toolchain` / `VERSION` contents. `cmdrs` strips control bytes (audit F-1),
# but `$`, `(`, `)`, `` ` `` and `\` are ordinary printable characters and pass
# through as text, correctly.
#
# Bash handles PS1 in two stages, so those bytes must never be in PS1 itself. They
# sit in a variable, and PS1 is the fixed text `${_cmdrs_ps1}`:
#
#   1. Backslash decoding runs first and is unconditional. It sees only the
#      fixed text, so a repo's six characters `\e[31m` cannot become a real ESC
#      (audit 2026-08-26, A-04, which used to need every `\` doubled here).
#   2. Expansion runs next. It expands the reference once and does not re-parse
#      the value, so a repo's `$(...)` is text (audit 2026-08-26, P-01).
#
# P-01 used to rely on `shopt -u promptvars` with the bytes in PS1. POSIX mode
# ignores that option, so `set -o posix`, or just `POSIXLY_CORRECT=1`, brought the
# command execution back, and so did any later `shopt -s promptvars` (audit
# 2026-11-06, T-02). So this adapter now turns the option ON, every redraw. If
# something turns it off afterwards the prompt shows the text `${_cmdrs_ps1}`: ugly,
# and safe.
#
# Same class as CVE-2021-3934 / CVE-2021-45444; git's `git-prompt.sh` uses the same
# indirection for branch names. `adapters/agnoshi.sh` states the rule for the
# agnoshi contract (audit F-12).
_cmdrs_prompt_command() {
  # First statement — captures $? from the user's last command.
  local exit_code=$?
  export AGNOSHI_LAST_EXIT=$exit_code
  local REPLY
  _cmdrs_bash_wrap "$("$_CMDRS")"
  _cmdrs_ps1=$REPLY
  # Single quotes, deliberately. Never put the rendered bytes in PS1 directly.
  shopt -s promptvars
  PS1='${_cmdrs_ps1}'
}

# Prepend our hook so other tools' PROMPT_COMMAND keeps running too. Only once:
# re-sourcing .bashrc would otherwise run it twice, and the second run sees $? = 0.
case "$PROMPT_COMMAND" in
  *_cmdrs_prompt_command*) ;;
  *) PROMPT_COMMAND="_cmdrs_prompt_command${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac
