# Benchmarks history

Time series of `cyrius bench tests/commandress.bcyr` results, one row per (release, bench) pair. The CSV is a checked-in artifact — committing it puts perf trends in `git log` next to the code changes that caused them.

## File

- [`history.csv`](history.csv) — append-only, header-on-row-1.

## Columns

| Column | Type | Notes |
|---|---|---|
| `date` | ISO-8601 (`YYYY-MM-DD`) | UTC, day-granularity. Override via `BENCH_DATE=...` |
| `version` | string | Reads `VERSION` at script-run time. Override via `BENCH_VERSION=...` |
| `name` | string | Bench label as emitted by `bench_report`. Commas in the label are remapped to `;` so the CSV stays well-formed |
| `avg_ns` | int | Average iteration cost in nanoseconds |
| `min_ns` | int | Fastest iteration |
| `max_ns` | int | Slowest iteration |
| `iters` | int | Total iterations the bench ran (rounds × batch in the bench harness) |

All time columns normalize to nanoseconds at write time. Source bench output uses `ns` / `us` / `ms` suffixes for readability; the CSV stores raw ns so downstream tools don't have to re-parse.

## Append a row

```sh
cyrius bench tests/commandress.bcyr | scripts/bench-history.sh
```

Run from the repo root. Each `bench_report` line in the bench output becomes one CSV row. The script is idempotent in the sense that re-running on the same day with the same version just appends another row pair — there's no dedup, so call it once per release rather than every time you run the bench locally.

## Read / plot

The CSV is small (12 rows per release × handful of releases). For trend plots, any spreadsheet or pandas-style tool reads it directly:

```python
import pandas as pd
df = pd.read_csv("docs/benchmarks/history.csv")
df.pivot_table(index="date", columns="name", values="avg_ns").plot()
```

## Manual back-fill

If you have saved bench output from a previous release that didn't get a row, run:

```sh
BENCH_VERSION=0.6.1 BENCH_DATE=2026-05-18 \
  scripts/bench-history.sh < /path/to/saved-bench.out
```

The script just appends; existing rows aren't touched.
