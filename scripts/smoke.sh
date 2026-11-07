#!/usr/bin/env bash
# Run the binary that ships. Usage: scripts/smoke.sh build/cmdrs
#
# The suite compiles src/ into a test binary and never runs src/main.cyr, and the bench
# gate times render_prompt in-process. So a binary that crashed on its first line, or
# stalled for 200 ms at startup, or had lost the sanitizer call in render_prompt, passed
# every gate (audit 2026-11-06, SC-03). This is the check on what users actually run.
#
# SMOKE_BUDGET_US overrides the 5 ms cold-start budget. It takes the best of 21 runs,
# because a stall shows in every run and scheduler noise does not.
set -euo pipefail

bin="$(realpath "$1")"
budget_us="${SMOKE_BUDGET_US:-5000}"
fail() { echo "smoke: $1" >&2; exit 1; }

want="cmdrs $(tr -d '[:space:]' < VERSION)"
[[ "$("$bin" --version)" == "$want" ]] || fail "--version is not '$want'"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

# A hostile project file, through the real render path. The last line is the C1 pair
# that a dropped byte used to reassemble (audit 2026-11-06, T-03).
printf '3.11\033[31mX\033]0;t\007\302\001\233Y\n' > .python-version
# package.json is the other repo-controlled parser input, so it gets the same treatment.
printf '{"engines":{"node":">=18\033]0;t\007\302\001\233"}}' > package.json
printf '[[prompt]]\nsegments = ["python_env", "node_env"]\nright_segments = ["python_env"]\ntrailer = "> "\n' > .commandress
export HOME="$work"
unset VIRTUAL_ENV

out="$("$bin")" || fail "non-zero exit"
[[ "$out" == *'> ' ]] || fail "the left prompt lost its trailer"
[[ "$out" == *'>=18'* ]] || fail "node_env did not read package.json"
[[ "$out" != *$'\033]'* ]] || fail "OSC from a project file reached stdout"
[[ "$out" != *$'\a'* ]] || fail "BEL from a project file reached stdout"
[[ "$out" != *$'\033[31m'* ]] || fail "SGR from a project file reached stdout"
[[ "$out" != *$'\302\233'* ]] || fail "a C1 CSI from a project file reached stdout"

right="$("$bin" --side=right)" || fail "--side=right: non-zero exit"
[[ "$right" != *'> '* ]] || fail "--side=right painted the trailer"
[[ "$right" == *'3.11'* ]] || fail "--side=right lost its segment"

[[ -z "$("$bin" --help 2>/dev/null)" ]] || fail "--help wrote to stdout"
"$bin" --no-such-flag >/dev/null 2>&1 || fail "a bad flag must not exit non-zero"

best=999999999
for _ in {1..21}; do
  start=$EPOCHREALTIME
  "$bin" >/dev/null
  end=$EPOCHREALTIME
  us=$(( ${end/./} - ${start/./} ))
  if (( us < best )); then best=$us; fi
done
(( best <= budget_us )) || fail "cold start ${best} us exceeds ${budget_us} us"

echo "smoke: OK (best cold start ${best} us of ${budget_us} us)"
