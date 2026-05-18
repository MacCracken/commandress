#!/usr/bin/env bash
# bench-gate.sh — fail CI if render_prompt avg exceeds the cold-start
# budget. Reads `cyrius bench` output on stdin; greps for the
# render_prompt line; parses `<n>{ns|us|ms} avg`; normalizes to µs;
# compares against BUDGET_US (default 5000 = 5 ms per
# architecture/001-prompt-render-budget.md).
#
# Usage:
#   cyrius bench tests/commandress.bcyr | scripts/bench-gate.sh
#   BUDGET_US=3000 scripts/bench-gate.sh < bench.out
#
# Exit codes:
#   0  — render_prompt within budget
#   1  — over budget OR parse failure (line missing / unknown unit)

set -euo pipefail

BUDGET_US="${BUDGET_US:-5000}"

# Read all of stdin; grep returns 1 on no-match and we want a clean
# error message in that case rather than `set -e` killing us silently.
input="$(cat)"
line="$(printf '%s\n' "$input" | grep -E '^[[:space:]]*render_prompt' || true)"

if [[ -z "$line" ]]; then
  echo "bench-gate: no 'render_prompt' line in input — did the bench fail?" >&2
  echo "----- captured input -----" >&2
  printf '%s\n' "$input" >&2
  exit 1
fi

# Expected shape: "  render_prompt (...): 9us avg (min=9us max=10us) [25000 iters]"
# Extract "<n><unit> avg" → "<n> <unit>".
parsed="$(printf '%s\n' "$line" | sed -E 's/.*: *([0-9]+)(ns|us|ms) avg.*/\1 \2/')"
n="$(awk '{print $1}' <<< "$parsed")"
unit="$(awk '{print $2}' <<< "$parsed")"

case "$unit" in
  ns) us=$(( n / 1000 )) ;;
  us) us="$n" ;;
  ms) us=$(( n * 1000 )) ;;
  *)
    echo "bench-gate: unrecognized avg unit '$unit' in line: $line" >&2
    exit 1
    ;;
esac

if (( us > BUDGET_US )); then
  echo "FAIL: render_prompt ${n}${unit} (= ${us} µs) exceeds budget ${BUDGET_US} µs" >&2
  echo "      source line: $line" >&2
  exit 1
fi

echo "OK: render_prompt ${n}${unit} (= ${us} µs) within budget ${BUDGET_US} µs"
