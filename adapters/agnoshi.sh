# commandress — agnoshi adapter (contract).
#
# Source from your login shell *before* starting agnoshi:
#
#   source /path/to/commandress/adapters/agnoshi.sh
#   agnsh
#
# Or wire it into agnoshi's rc / init file when one lands. Setting
# the variable system-wide also works:
#
#   echo 'export AGNOSHI_PROMPT_CMD=cmdrs' | sudo tee -a /etc/profile.d/commandress.sh
#
# ===== STATUS =====
#
# Contract-only. As of commandress v0.8.0, the prompt-cmd contract
# below is **defined**; **agnoshi has not yet adopted it**. agnoshi
# currently renders its prompt internally (`src/prompt.cyr`). When
# agnoshi reads `$AGNOSHI_PROMPT_CMD` and shells out per redraw,
# sourcing this file flips the prompt over to `cmdrs` with zero
# extra config. Until then, this file just sets the env var — a
# harmless no-op for shells that don't consume it.
#
# ===== CONTRACT =====
#
# The agnoshi ↔ commandress prompt contract (owned by commandress
# until agnoshi co-signs):
#
#   1. agnoshi reads `$AGNOSHI_PROMPT_CMD` once per prompt cycle.
#      Empty / unset → agnoshi falls back to its built-in prompt.
#   2. Before invoking the command, agnoshi exports:
#        AGNOSHI_LAST_EXIT  — exit code of the user's last command
#        (other env passes through unchanged — HOME / PWD / VIRTUAL_ENV
#        / TZ / etc. — so segments that read them work transparently)
#   3. agnoshi runs `$AGNOSHI_PROMPT_CMD` (left-prompt) and captures
#      stdout as the prompt string. The captured output may contain
#      raw ANSI SGR escapes; agnoshi is responsible for any width-
#      accounting markers its readline-equivalent needs (cf. bash's
#      \001..\002 wrap in `bash.sh`). zsh / agnoshi can consume the
#      raw escapes; bash needs wrapping.
#
#      AUDIT F-12 (see docs/audit/2026-05-18-audit.md): the captured
#      bytes are a LITERAL PROMPT STRING. agnoshi MUST NOT pass them
#      through percent-expansion, variable-expansion, backtick-eval,
#      command-substitution, or any other shell-syntax interpretation
#      pass. Precedents — CVE-2021-3934 (oh-my-zsh `print -P` on git
#      branch names), CVE-2021-45444 (zsh PROMPT_SUBST recursion):
#      attacker-controlled segment content containing %-, $-, or
#      backtick sequences becomes RCE if the consumer re-expands.
#      The bytes go straight to the terminal. cmdrs's own audit-F-1
#      sanitization closes the C0/escape side; the no-re-expand rule
#      closes the shell-syntax side.
#   4. Right-prompt (optional, if agnoshi grows an RPROMPT surface):
#      agnoshi runs `$AGNOSHI_PROMPT_CMD --side=right` and renders
#      the result on the right edge. Empty output → no right prompt.
#   5. The command is exec'd directly (no shell-expansion layer)
#      so users with whitespace-bearing paths can use the cstring
#      form: `AGNOSHI_PROMPT_CMD="/path with spaces/cmdrs"`.
#
# See `docs/guides/zsh-setup.md` for the analogous zsh adapter and
# `adapters/bash.sh` for the bash side.

export AGNOSHI_PROMPT_CMD=cmdrs
