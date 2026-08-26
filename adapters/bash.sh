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

# SECURITY — bash expands PS1 with `promptvars` ON BY DEFAULT, which means
# parameter expansion AND command substitution are performed on the prompt
# string at every redraw.
#
# `cmdrs` output carries bytes chosen by whatever repository the user is
# standing in — branch names, `.python-version` / `.nvmrc` /
# `rust-toolchain` / `VERSION` contents. `cmdrs` strips control bytes
# (audit F-1), but `$`, `(` and `)` are ordinary printable characters and
# pass through as text, correctly so.
#
# With promptvars left at its default, a repo shipping a `.python-version`
# containing `$(...)` therefore ran that command on every redraw. Verified
# as arbitrary command execution in the 2026-08-26 audit (P-01) and fixed
# here by turning the option off: the prompt is DATA, not a script.
#
# Same class as CVE-2021-3934 / CVE-2021-45444; `adapters/agnoshi.sh`
# states the same rule for the agnoshi contract (audit F-12).
#
# Scoped caveat, stated rather than hidden: `shopt` is shell-global, not
# per-prompt, so sourcing this adapter turns promptvars off for the whole
# session. A user whose own PS1 relies on `\$(date)`-style substitution
# would lose that. That is the correct trade — the alternative is leaving
# an execution channel open — and it is called out in adapters/README.md.
shopt -u promptvars

# SECOND, INDEPENDENT channel: bash decodes backslash escapes in PS1
# (audit 2026-08-26, A-04 · HIGH). This is NOT covered by `shopt -u promptvars`
# — prompt backslash decoding is unconditional.
#
# `cmdrs` strips control BYTES, correctly. But `\` and `e` are printable, so a
# repo shipping `.python-version` containing the six characters `\e[31m` passes
# the F-1 sanitizer untouched — and bash's prompt decoder then turns `\e` into a
# real ESC (0x1b) and `\a` into a real BEL (0x07) inside the shell. The
# sanitizer is bypassed by reconstructing the control byte on the far side of it.
#
# Verified: `cmdrs` emitted `v \ e [ 3 1 m R E D \ a` with no 033 or 007 in it;
# after `${PS1@P}` the same string contained `033 [ 3 1 m` and `\a`.
#
# Doubling `\` -> `\\` makes the decoder emit one literal backslash and stop,
# so the escape never forms. Applied to the RENDERED bytes only — the \001/\002
# readline markers added below are raw control bytes, not backslash sequences,
# so they are unaffected.
_cmdrs_prompt_command() {
  # First statement — captures $? from the user's last command.
  local exit_code=$?
  export AGNOSHI_LAST_EXIT=$exit_code
  local _raw
  _raw=$(_cmdrs_bash_render)
  PS1=${_raw//\\/\\\\}
}

# Prepend our hook so other tools' PROMPT_COMMAND keeps running too.
PROMPT_COMMAND="_cmdrs_prompt_command${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
