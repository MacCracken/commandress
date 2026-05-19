#!/usr/bin/env bash
# bench-history.sh — append a bench run to docs/benchmarks/history.csv.
#
# Reads `cyrius bench` output on stdin. For each line of the shape
#   <name>: <avg><unit> avg (min=<min><unit> max=<max><unit>) [<iters> iters]
# appends one row to docs/benchmarks/history.csv:
#   date,version,name,avg_ns,min_ns,max_ns,iters
#
# All values are normalised to nanoseconds for storage so future plots
# / analyses don't have to re-parse unit suffixes.
#
# Usage:
#   cyrius bench tests/commandress.bcyr | scripts/bench-history.sh
#
# Env overrides (useful for back-filling rows from saved bench output):
#   BENCH_HISTORY_CSV — destination CSV path (default docs/benchmarks/history.csv)
#   BENCH_DATE        — date column override (default $(date -u +%Y-%m-%d))
#   BENCH_VERSION     — version column override (default $(cat VERSION))

set -euo pipefail

CSV="${BENCH_HISTORY_CSV:-docs/benchmarks/history.csv}"
DATE="${BENCH_DATE:-$(date -u +%Y-%m-%d)}"
VERSION="${BENCH_VERSION:-$(cat VERSION 2>/dev/null || echo unknown)}"

mkdir -p "$(dirname "$CSV")"

if [[ ! -f "$CSV" ]]; then
  echo "date,version,name,avg_ns,min_ns,max_ns,iters" > "$CSV"
fi

to_ns() {
  local n="$1" unit="$2"
  case "$unit" in
    ns) awk -v n="$n" 'BEGIN { printf("%d\n", n + 0) }' ;;
    us) awk -v n="$n" 'BEGIN { printf("%d\n", n * 1000) }' ;;
    ms) awk -v n="$n" 'BEGIN { printf("%d\n", n * 1000000) }' ;;
    *)  echo "0" ;;
  esac
}

input="$(cat)"
appended=0

while IFS= read -r line; do
  # Skip non-bench lines (banners, warnings, dce notes, blanks).
  if ! grep -qE '^[[:space:]]*[a-zA-Z_][^:]*: *[0-9]+(ns|us|ms) avg' <<< "$line"; then
    continue
  fi

  name="$(sed -E 's/^[[:space:]]*([^:]+):.*/\1/' <<< "$line" | sed -E 's/[[:space:]]+$//')"
  avg_pair="$(sed -E 's/.*: *([0-9.]+)(ns|us|ms) avg.*/\1 \2/' <<< "$line")"
  min_pair="$(sed -E 's/.*min=([0-9.]+)(ns|us|ms).*/\1 \2/' <<< "$line")"
  max_pair="$(sed -E 's/.*max=([0-9.]+)(ns|us|ms).*/\1 \2/' <<< "$line")"
  iters="$(sed -E 's/.*\[([0-9]+) iters\].*/\1/' <<< "$line")"

  # shellcheck disable=SC2086
  avg_ns="$(to_ns $avg_pair)"
  # shellcheck disable=SC2086
  min_ns="$(to_ns $min_pair)"
  # shellcheck disable=SC2086
  max_ns="$(to_ns $max_pair)"

  # Escape commas in the name (segment labels use parens / spaces, not
  # commas today, but defend against future labels that do).
  name_csv="$(sed 's/,/;/g' <<< "$name")"

  echo "$DATE,$VERSION,$name_csv,$avg_ns,$min_ns,$max_ns,$iters" >> "$CSV"
  appended=$(( appended + 1 ))
done <<< "$input"

echo "bench-history: appended $appended rows to $CSV (date=$DATE version=$VERSION)"
