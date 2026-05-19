# commandress — zsh adapter.
#
# Source from your ~/.zshrc:
#
#   source /path/to/commandress/adapters/zsh.sh
#
# Or for a system-wide install:
#
#   sudo install -m 0644 adapters/zsh.sh /usr/share/commandress/zsh.sh
#   echo 'source /usr/share/commandress/zsh.sh' >> ~/.zshrc
#
# What it does:
#   1. Resolves `cmdrs` once (cached in $_CMDRS) so per-prompt redraw
#      doesn't re-walk PATH. Override with COMMANDRESS_BIN if needed.
#   2. Hooks `precmd` to capture the previous command's exit code into
#      $AGNOSHI_LAST_EXIT (the env var `cmdrs` reads for the `exit`
#      segment), then assigns $PROMPT from `cmdrs` (left side) and
#      $RPROMPT from `cmdrs --side=right`. Empty `right_segments` →
#      $RPROMPT empty → no right prompt rendered.
#   3. Sets `prompt_subst` so $(...) inside $PROMPT is evaluated each
#      redraw. (zsh's default is *not* to evaluate; without this, the
#      prompt would show the literal `$(cmdrs)` string.)
#
# Override path priority:
#   COMMANDRESS_BIN > $(command -v cmdrs)

typeset -g _CMDRS="${COMMANDRESS_BIN:-${commands[cmdrs]:-}}"

if [[ -z "$_CMDRS" ]]; then
  print -u2 "commandress: cmdrs not on PATH (set COMMANDRESS_BIN or install it)"
  return 1
fi

setopt prompt_subst

_cmdrs_precmd() {
  # MUST capture $? first — every subsequent statement (including the
  # PROMPT subshell below) resets it.
  export AGNOSHI_LAST_EXIT=$?
  PROMPT="$($_CMDRS)"
  RPROMPT="$($_CMDRS --side=right)"
}

# precmd_functions is zsh's array of pre-prompt hooks. Append so we
# don't clobber other tools the user already has wired in.
precmd_functions+=(_cmdrs_precmd)
