#!/usr/bin/env bash
# Prove the shell adapters treat the prompt as data. Usage: scripts/adapter-check.sh build/cmdrs
#
# Stands in a directory whose NAME is the attack, runs each adapter's hook, and asks the
# shell to expand the prompt the way a redraw does (`print -P` in zsh, `${PS1@P}` in
# bash), across the option states that used to let it through. Nothing was testing the
# adapters, so the 2026-08-26 fix for command execution quietly depended on an option
# that stock zsh themes set (audit 2026-11-06, T-01, T-02).
#
# Needs zsh and bash. A missing shell is a failure, not a pass.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$(realpath "$1")"
for shell in zsh bash; do
  command -v "$shell" >/dev/null || { echo "adapter-check: $shell is not installed" >&2; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/home"
fails=0
checks=0

# Each payload would create a file named PWNED in the cwd if it ever ran.
payloads=(
  '$(touch PWNED)'
  '`touch PWNED`'
  '${${:-$(touch PWNED)}}'
  '$((a[$(touch PWNED)]))'
  '%F{$(touch PWNED)}x'
  '\$(touch PWNED)'
  '\`touch PWNED\`'
)

# check <shell> <before-source> <after-source> <dir> [home]. Prints nothing on success.
check() {
  local shell=$1 before=$2 after=$3 dir=$4 home=${5:-$work/home} expanded
  case "$shell" in
    zsh)
      expanded="$(cd "$dir" && HOME="$home" COMMANDRESS_BIN="$bin" timeout 20 zsh -f -c "
        $before
        source '$root/adapters/zsh.sh'
        $after
        _cmdrs_precmd
        [[ \$PROMPT == '\${_cmdrs_left}' ]] || print 'PROMPT-NOT-FIXED'
        [[ \$RPROMPT == '\${_cmdrs_right}' ]] || print 'RPROMPT-NOT-FIXED'
        print -rP -- \"\$PROMPT\"
      " 2>&1)" || {
        echo "adapter-check: $shell [$before|$after] failed or hung" >&2
        fails=$((fails + 1))
      }
      ;;
    bash)
      expanded="$(cd "$dir" && HOME="$home" COMMANDRESS_BIN="$bin" timeout 20 bash --noprofile --norc -c "
        shopt -s expand_aliases
        $before
        source '$root/adapters/bash.sh'
        $after
        _cmdrs_prompt_command
        [[ \$PS1 == '\${_cmdrs_ps1}' ]] || echo 'PS1-NOT-FIXED'
        printf '%s\n' \"\${PS1@P}\"
      " 2>&1)" || {
        echo "adapter-check: $shell [$before|$after] failed or hung" >&2
        fails=$((fails + 1))
      }
      ;;
  esac
  checks=$((checks + 1))
  if [[ "$expanded" == *'bad pattern'* || "$expanded" == *'set in enclosing scope'* ]]; then
    echo "adapter-check: $shell [$before|$after] let a shell option reach the rendered bytes" >&2
    fails=$((fails + 1))
  fi
  if [[ -e "$dir/PWNED" ]]; then
    echo "adapter-check: $shell [$before|$after] EXECUTED in $(basename "$dir")" >&2
    rm -f "$dir/PWNED"
    fails=$((fails + 1))
  fi
  if [[ "$expanded" == *NOT-FIXED* ]]; then
    echo "adapter-check: $shell [$before|$after] put the rendered bytes in the prompt variable" >&2
    fails=$((fails + 1))
  fi
  if [[ "$expanded" != *"$(basename "$dir")"* ]]; then
    echo "adapter-check: $shell [$before|$after] did not render $(basename "$dir") as text" >&2
    fails=$((fails + 1))
  fi
  if [[ "$expanded" == *$'\033[31mRED'* ]]; then
    echo "adapter-check: $shell [$before|$after] decoded a backslash escape from a directory name" >&2
    fails=$((fails + 1))
  fi
}

i=0
for payload in "${payloads[@]}"; do
  i=$((i + 1))
  dir="$work/p$i/$payload"
  mkdir -p "$dir"
  check zsh '' '' "$dir"
  check zsh 'setopt prompt_subst' '' "$dir"
  check zsh '' 'setopt prompt_subst' "$dir"
  check zsh 'setopt sh_word_split ksh_arrays' '' "$dir"
  check zsh 'setopt glob_subst glob_assign' '' "$dir"
  check zsh 'setopt warn_nested_var' '' "$dir"
  check zsh 'setopt local_options' '' "$dir"
  check zsh 'emulate ksh' '' "$dir"
  check zsh '' 'unsetopt prompt_subst' "$dir"
  check bash '' '' "$dir"
  check bash 'set -o posix' '' "$dir"
  check bash '' 'set -o posix' "$dir"
  check bash '' 'POSIXLY_CORRECT=1' "$dir"
  check bash '' 'shopt -s promptvars' "$dir"
  check bash '' 'shopt -u promptvars' "$dir"
done

# With glob options on, a glob qualifier at the very end of the rendered bytes would
# run, so this needs an uncoloured segment and no trailer after it.
mkdir -p "$work/bare"
printf '[[prompt]]\nsegments = ["cwd"]\nright_segments = ["cwd"]\ntrailer = ""\n[[segments.cwd]]\nfg = "default"\n' > "$work/bare/.commandress"
dir="$work/q/x*(e:touch PWNED:)"
mkdir -p "$dir"
check zsh '' '' "$dir" "$work/bare"
check zsh 'setopt glob_subst glob_assign' '' "$dir" "$work/bare"

# `trailer` is the user's own and may hold any sequence, not just SGR. A wrap that
# assumes otherwise loops forever, and every new shell hangs with it.
mkdir -p "$work/csi" "$work/csidir"
printf '[[prompt]]\nsegments = ["cwd"]\ntrailer = "\\u001b[6 q$ "\n' > "$work/csi/.commandress"
check bash '' '' "$work/csidir" "$work/csi"
check zsh '' '' "$work/csidir" "$work/csi"

# Sourcing twice, as re-sourcing an rc file does, must not lose the exit status.
if [[ "$(cd "$work" && HOME="$work/home" COMMANDRESS_BIN="$bin" bash --noprofile --norc -c "
  source '$root/adapters/bash.sh'; source '$root/adapters/bash.sh'; printf '%s' \"\$PROMPT_COMMAND\"")" != '_cmdrs_prompt_command' ]]; then
  echo "adapter-check: bash hooked itself twice" >&2
  fails=$((fails + 1))
fi
if [[ "$(cd "$work" && HOME="$work/home" COMMANDRESS_BIN="$bin" zsh -f -c "
  source '$root/adapters/zsh.sh'; source '$root/adapters/zsh.sh'; print -r -- \$#precmd_functions")" != 1 ]]; then
  echo "adapter-check: zsh hooked itself twice" >&2
  fails=$((fails + 1))
fi

# The six characters of a backslash escape must stay text (audit 2026-08-26, A-04).
dir="$work/esc/\\e[31mRED"
mkdir -p "$dir"
check bash '' '' "$dir"
check bash 'set -o posix' '' "$dir"

# Colour must be zero-width to the shell, or a long line overwrites the prompt.
if [[ "$(cd "$work" && HOME="$work/home" COMMANDRESS_BIN="$bin" zsh -f -c "
  source '$root/adapters/zsh.sh'; _cmdrs_precmd; print -r -- \"\$_cmdrs_left\"")" != *'%{'*'%}'* ]]; then
  echo "adapter-check: zsh did not wrap SGR in %{ %}" >&2
  fails=$((fails + 1))
fi
if [[ "$(cd "$work" && HOME="$work/home" COMMANDRESS_BIN="$bin" bash --noprofile --norc -c "
  source '$root/adapters/bash.sh'; _cmdrs_prompt_command; printf '%s' \"\$_cmdrs_ps1\"")" != *$'\001'*$'\002'* ]]; then
  echo "adapter-check: bash did not wrap SGR in \\001..\\002" >&2
  fails=$((fails + 1))
fi

if (( fails > 0 )); then
  echo "adapter-check: $fails failure(s) in $checks checks" >&2
  exit 1
fi
echo "adapter-check: OK ($checks checks)"
