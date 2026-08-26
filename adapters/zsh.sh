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
#   3. Renders the prompt as a LITERAL STRING. It deliberately does NOT
#      set `prompt_subst`, and it doubles every `%` — see the security
#      note below. Both are load-bearing.
#
# SECURITY — why this adapter must never enable prompt_subst
#
#   `cmdrs` output contains bytes from OUTSIDE the user's control: a
#   `sit` branch name, `.python-version` / `.nvmrc` / `rust-toolchain` /
#   `VERSION` file contents, `$VIRTUAL_ENV`. A repository the user merely
#   `cd`s into chooses those bytes.
#
#   `cmdrs` strips control bytes (audit F-1) but `$`, `(`, `)` and `%`
#   are ordinary printable characters and are passed through as text —
#   correctly, they are legal in a branch name.
#
#   This adapter used to `setopt prompt_subst`, which tells zsh to run
#   command substitution on the prompt EVERY REDRAW. A repo shipping
#   `.python-version` containing `$(...)` therefore executed that command
#   on every keystroke-triggered redraw. Verified as arbitrary command
#   execution in the 2026-08-26 audit (P-01) and fixed there.
#
#   The `setopt` was never needed for this design: PROMPT is assigned from
#   `$( )` in the precmd hook below, so by the time zsh renders it, it
#   already holds finished bytes — there is no `$(cmdrs)` left in it to
#   expand. The option bought nothing and opened the hole.
#
#   `%` is a second, separate channel: zsh expands `%` prompt escapes
#   whether or not prompt_subst is set, so segment content containing `%`
#   could forge prompt state. Doubling `%` -> `%%` renders it literally.
#
#   Same class as CVE-2021-3934 (oh-my-zsh: branch name through `print -P`)
#   and CVE-2021-45444 (zsh PROMPT_SUBST). `adapters/agnoshi.sh` states the
#   same rule for the agnoshi contract (audit F-12).
#
# Override path priority:
#   COMMANDRESS_BIN > $(command -v cmdrs)

typeset -g _CMDRS="${COMMANDRESS_BIN:-${commands[cmdrs]:-}}"

if [[ -z "$_CMDRS" ]]; then
  print -u2 "commandress: cmdrs not on PATH (set COMMANDRESS_BIN or install it)"
  return 1
fi

# NOTE: no `setopt prompt_subst` here, deliberately — see the security
# note above. Do not add it back.

_cmdrs_precmd() {
  # MUST capture $? first — every subsequent statement (including the
  # PROMPT subshell below) resets it.
  export AGNOSHI_LAST_EXIT=$?
  # `${x//\%/%%}` doubles every `%` so segment content is rendered as
  # literal text rather than as zsh prompt escapes. The substitution
  # itself happens HERE, once per prompt; what lands in PROMPT is
  # finished bytes.
  local _l _r
  _l="$($_CMDRS)"
  _r="$($_CMDRS --side=right)"
  PROMPT="${_l//\%/%%}"
  RPROMPT="${_r//\%/%%}"
}

# precmd_functions is zsh's array of pre-prompt hooks. Append so we
# don't clobber other tools the user already has wired in.
precmd_functions+=(_cmdrs_precmd)
