# Benchmarks

`cmdrs` runs once per shell prompt redraw. The render must be fast enough to be **invisible** at typing speed, and predictable enough that adding segments doesn't blow the envelope. This document is what we measure, the budgets we hold ourselves to, and the numbers we currently hit. Refreshed at the 2026-08-26 doc sweep against **v1.1.6**.

## Budget

**5 ms cold start, total.** [`architecture/001-prompt-render-budget.md`](architecture/001-prompt-render-budget.md) is the breakdown:

| Component | Target | Today |
|---|---|---|
| Process exec | ~1 ms | OS-bound; not addressable from cmdrs |
| `Context` init (env-var slurp, getcwd, parse last-exit) | ≤ 250 µs | sub-µs measured |
| Config load + CYML parse (`~/.commandress`) | ≤ 500 µs | ~3 µs (`config_default` baseline) |
| All segments combined | ≤ 2.5 ms | ~1 µs default set + ~7.6 µs cached vcs |
| Render + final write | ≤ 250 µs | bundled into `render_prompt` ~10.9 µs |
| **Headroom** | ~500 µs | many ms |

The 5 ms gate is enforced in CI via [`scripts/bench-gate.sh`](../scripts/bench-gate.sh) (added in v0.7.0 / M6) — `cyrius bench` output piped through, fails the build if `render_prompt` avg > 5000 µs. Override per-run: `BUDGET_US=3000 scripts/bench-gate.sh`.

## Per-segment

Numbers from the **v1.1.6** run (Linux 7.1.9-arch1-2, x86_64, dev host). The 6.5.x harness subtracts a measured timer floor (~1.3 µs per clock read) from every sample. Captured by `cyrius bench tests/commandress.bcyr`; historical series in [`benchmarks/history.csv`](benchmarks/history.csv).

| Segment | Avg | Notes |
|---|---|---|
| `cwd_render` | ~665 ns | `getcwd` syscall + `$HOME`-shorten + truncate. No I/O beyond the syscall. |
| `exit_render(nonzero)` | ~40 ns | Pure integer-to-string + bracket-wrap. No I/O. |
| `cyrius_env_parse_version` | ~75 ns | Pure parser; no fork/exec. |
| `cyrius_env_render` (file path) | ~7 µs | getcwd + ancestor walk for `cyrius.cyml` + open/read `VERSION` + trim. Three syscalls. |
| `python_env_basename` | ~95 ns | Pure parser. |
| `python_env_render` (empty walk) | ~12 µs | getcwd + ancestor walk hitting root (`.python-version` not found). Worst case for the segment. |
| `node_env_render` (empty walk) | ~6 µs | Same shape as python_env. |
| `rustup_env_render` (empty walk) | ~6 µs | Same shape. |
| `vcs_parse_render` (pure parser) | ~230 ns | Branch-name extraction from a fabricated `sit status` buffer. |
| `vcs_render` (**cached, 1 s TTL**) | ~7.6 µs hot avg | Cold path: fork + exec + parse ≈ 1.8 ms. Cache hit: stat + read. The headline M6 win — ~240× faster on the cached path. |
| `cli_parse` (cmdit `--side`) | ~11.8 µs | Added 1.1.5. **Outside `render_prompt`** — `side` is a parameter, so the gate below is unaffected. See [ADR 0008](adr/0008-cli-parsing-via-cmdit.md) for why the 56 ns → 11.8 µs regression was accepted. |

Across the default `["cwd", "vcs", "exit"]` segment set, **`render_prompt` is ~10.9 µs avg** — **0.2 % of the 5 ms budget consumed**.

## End-to-end

Process-level measurement (fork + exec + render + stdout-write, measured from a parent shell):

| Scenario | Avg per redraw | Notes |
|---|---|---|
| Cache cold (force-clear cache dir between runs) | **~2.4 ms** | Fork + exec + sit fork + sit exec + parse + cache write |
| Cache warm | **~0.96 ms** | Fork + exec + cache hit (stat + read) + write to stdout. Measured 1.1.6, 100 invocations. |

The warm figure is the one that matters for "is this fast enough": it is dominated by **process exec**, not by anything commandress does — `render_prompt` is ~1 % of it. That is also why the 1.1.5 cmdit adoption's ~11.8 µs parse cost was undetectable end-to-end (interleaved A/B: −15 / +1 / +11 µs).

Both are well under the perceptible-latency threshold (~50 ms for keystroke-to-screen).

## Trends

The CSV at [`benchmarks/history.csv`](benchmarks/history.csv) accumulates one row per (release × bench) since v0.6.1, normalised to nanoseconds. **Gap warning**: it holds no rows between 0.9.0 and 1.1.4 — `bench-history.sh` silently dropped every decimal-average row from 6.4.x onward until that was fixed in 1.1.4, so the trend line jumps that span. Plotting `avg_ns` per `name` against `version` shows:

- **`vcs_render`**: 4.6 ms (v0.5.0) → ~7.6 µs (v0.7.0+). M6 cache landed.
- **`render_prompt`**: 2 µs (v0.5.0) → 3 µs (v0.6.0 — adds SGR wrap overhead) → ~11 µs (v0.7.0+ — vcs now in the default set, still cached). Flat across 1.1.4–1.1.6 within run-to-run noise (10.6–11.0 µs).
- **`config_default`**: 154 ns (v0.5.0) → 2–3 µs (v0.6.0+). Tradeoff for the M5 default-theme bake — paid once per redraw, 0.06 % of budget.

All other segments are stable within run-to-run variance.

## How to reproduce

```sh
cyrius bench tests/commandress.bcyr
```

For trend tracking:

```sh
cyrius bench tests/commandress.bcyr | scripts/bench-history.sh
```

Appends one row per bench result to `docs/benchmarks/history.csv` keyed on `date,version`. See [`docs/benchmarks/README.md`](benchmarks/README.md) for column semantics.

## Variance notes

`vcs_render` and the file-walk env segments are sensitive to system load — fork+exec timing in particular varies under contention. The benchmark loops average 100+ iterations to dampen the noise, but a single bench on a busy host can show 2-3× variance vs a quiet host. The CI gate's 5 ms budget is intentionally generous (≈ 500× headroom over the typical 10 µs) to absorb runner variance without false-positive failures.

The CSV captures the variance as `min_ns` / `max_ns` alongside `avg_ns` so trend plots can show error bars.
