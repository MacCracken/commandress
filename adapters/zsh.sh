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
#   3. Keeps the rendered bytes in $_cmdrs_left / $_cmdrs_right, and sets
#      PROMPT and RPROMPT to a fixed reference to them. See the security
#      note below: this is what makes the prompt data rather than a script.
#   4. Wraps each ANSI SGR sequence in %{ %} so zsh counts it as zero-width.
#      Without this zsh counts colour bytes as columns, which puts the right
#      prompt and long input lines in the wrong place.
#
# SECURITY — the prompt is data, and this adapter does not depend on an option
#
#   `cmdrs` output contains bytes from OUTSIDE the user's control: a `sit`
#   branch name, a directory name, `.python-version` / `.nvmrc` /
#   `rust-toolchain` / `VERSION` file contents, `$VIRTUAL_ENV`. A repository
#   the user merely `cd`s into chooses those bytes. `cmdrs` strips control
#   bytes (audit F-1), but `$`, `(`, `)`, `` ` `` and `%` are ordinary
#   printable characters and are passed through as text, correctly: they are
#   legal in a branch name.
#
#   With `prompt_subst` on, zsh runs command substitution on PROMPT at every
#   redraw. Those bytes must therefore never be in PROMPT itself. They sit in
#   a variable, and PROMPT is the fixed text `${_cmdrs_left}`. zsh expands that
#   once and does not re-parse the value, so what the value holds cannot run.
#
#   The 2026-08-26 audit (P-01) tried the opposite: it removed the adapter's
#   `setopt prompt_subst` and kept the bytes in PROMPT. That is only safe while
#   nothing else sets the option, and plenty does: `promptinit` themes set it
#   through `prompt_opts`, so stock zsh with `prompt adam2` ran commands from a
#   directory name (audit 2026-11-06, T-01). So this adapter now turns the
#   option ON, every redraw. If something turns it off afterwards the prompt
#   shows the text `${_cmdrs_left}`: ugly, and safe.
#
#   `%` is a second, separate channel: zsh expands `%` prompt escapes after
#   the substitution, whatever the option says, so segment content containing
#   `%` could forge prompt state, and through `%F{...}` reach CVE-2021-45444 on
#   an old zsh. Doubling `%` -> `%%` renders it literally.
#
#   Same class as CVE-2021-3934 (oh-my-zsh: branch name through `print -P`)
#   and CVE-2021-45444 (zsh PROMPT_SUBST). git's `git-prompt.sh` uses the same
#   indirection for branch names. `adapters/agnoshi.sh` states the rule for the
#   agnoshi contract (audit F-12).
#
# Override path priority:
#   COMMANDRESS_BIN > $(command -v cmdrs)

typeset -g _CMDRS="${COMMANDRESS_BIN:-${commands[cmdrs]:-}}"

if [[ -z "$_CMDRS" ]]; then
  print -u2 "commandress: cmdrs not on PATH (set COMMANDRESS_BIN or install it)"
  return 1
fi

typeset -g _cmdrs_left='' _cmdrs_right=''

# At source time as well as in the hook: under `local_options`, which `emulate ksh`
# sets, a setopt inside a function is undone when it returns.
setopt prompt_subst prompt_percent

# Render both sides into $_cmdrs_left and $_cmdrs_right, ready for zsh's `%` stage.
#
# Everything that touches the rendered bytes runs here, under `emulate -L zsh`, so the
# user's options cannot reach them. It matters: with `glob_subst glob_assign` on, a
# plain `var=$bytes` is a glob, and `(e:...:)` in a repo's file runs a command. The
# `setopt` below stays in the hook because it has to outlive this function.
#
# The `%` doubling runs first, so it cannot touch the %{ %} that come next.
_cmdrs_zsh_render() {
  emulate -L zsh
  setopt extendedglob
  local MATCH MBEGIN MEND open='%{' close='%}' s
  s="$("$_CMDRS")"
  s=${s//\%/%%}
  _cmdrs_left=${s//(#m)$'\e'\[[0-9;]#m/$open$MATCH$close}
  s="$("$_CMDRS" --side=right)"
  s=${s//\%/%%}
  _cmdrs_right=${s//(#m)$'\e'\[[0-9;]#m/$open$MATCH$close}
}

_cmdrs_precmd() {
  # MUST capture $? first — every subsequent statement resets it.
  export AGNOSHI_LAST_EXIT=$?
  _cmdrs_zsh_render
  # Single quotes, deliberately: see the security note above. Never put the
  # rendered bytes in PROMPT or RPROMPT directly.
  setopt prompt_subst prompt_percent
  PROMPT='${_cmdrs_left}'
  RPROMPT='${_cmdrs_right}'
}

# precmd_functions is zsh's array of pre-prompt hooks. Append so we
# don't clobber other tools the user already has wired in. Only once: re-sourcing
# .zshrc would otherwise render every prompt twice.
(( ${precmd_functions[(I)_cmdrs_precmd]} )) || precmd_functions+=(_cmdrs_precmd)
