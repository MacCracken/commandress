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
#      reassign PS1 from `cmdrs` output.
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

# Wrap each ANSI SGR escape (`\x1b[...m`) in \001..\002 so bash's
# readline-width logic treats them as zero-width. Without this, the
# cursor on long commands jumps to the wrong column. The pattern
# matches only SGR (terminating `m`) — sufficient for cmdrs's current
# emit surface.
_cmdrs_bash_render() {
  "$_CMDRS" "$@" | sed $'s/\x1b\\[[0-9;]*m/\x01&\x02/g'
}

_cmdrs_prompt_command() {
  # First statement — captures $? from the user's last command.
  local exit_code=$?
  export AGNOSHI_LAST_EXIT=$exit_code
  PS1=$(_cmdrs_bash_render)
}

# Prepend our hook so other tools' PROMPT_COMMAND keeps running too.
PROMPT_COMMAND="_cmdrs_prompt_command${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
