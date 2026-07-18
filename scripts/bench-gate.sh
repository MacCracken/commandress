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

# Expected shape: "  render_prompt (...): 8.848us avg (min=... max=...) [25000 iters]"
# Extract "<n><unit> avg" → "<n> <unit>". <n> may be a decimal: the bench
# harness emits sub-µs precision (e.g. "8.848us") since cyrius 6.4.x, where
# it used to print integers ("9us"). Optional-fraction group keeps both.
parsed="$(printf '%s\n' "$line" | sed -E 's/.*: *([0-9]+(\.[0-9]+)?)(ns|us|ms) avg.*/\1 \3/')"
n="$(awk '{print $1}' <<< "$parsed")"
unit="$(awk '{print $2}' <<< "$parsed")"

# Validate unit first — if the sed didn't match (unexpected line shape),
# `unit` is a stray token and this catches it before the awk math runs.
case "$unit" in
  ns|us|ms) ;;
  *)
    echo "bench-gate: unrecognized avg unit '$unit' in line: $line" >&2
    exit 1
    ;;
esac

# Normalize to µs and compare, both in awk — decimal averages break bash's
# integer `(( ))` arithmetic. awk prints "1" when over budget, else "0".
us="$(awk -v n="$n" -v u="$unit" 'BEGIN {
  if (u == "ns") v = n / 1000;
  else if (u == "ms") v = n * 1000;
  else v = n;
  printf "%.3f", v;
}')"
over="$(awk -v us="$us" -v b="$BUDGET_US" 'BEGIN { print (us > b) ? 1 : 0 }')"

if [[ "$over" == "1" ]]; then
  echo "FAIL: render_prompt ${n}${unit} (= ${us} µs) exceeds budget ${BUDGET_US} µs" >&2
  echo "      source line: $line" >&2
  exit 1
fi

echo "OK: render_prompt ${n}${unit} (= ${us} µs) within budget ${BUDGET_US} µs"
