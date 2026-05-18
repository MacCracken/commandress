# Changelog

All notable changes to commandress will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **ADR 0002** — segment rendering model: each segment is a pure fn of the prompt context; no shared mutable state; config-driven order Just Works because segments are leaves. [`docs/adr/0002-segment-rendering-model.md`](docs/adr/0002-segment-rendering-model.md).
- **ADR 0003** — config format: `~/.commandress.cyml` is CYML (Cyrius-native), not TOML; matches `cyrius.cyml` mental model, markdown body reserved for user notes. [`docs/adr/0003-config-format.md`](docs/adr/0003-config-format.md).
- **Architecture note 001** — prompt render budget: 5 ms cold start total, 500 µs per-segment default, slow segments degrade to empty (never stall). [`docs/architecture/001-prompt-render-budget.md`](docs/architecture/001-prompt-render-budget.md).
- **`src/segments/cwd.cyr`** — current-working-directory segment. `getcwd` syscall + strict-prefix `$HOME` → `~` shortening (no `/home/macro` matching `/home/macrobench`).
- **`src/segments/exit.cyr`** — last-exit segment. Empty on `0`, `[N]` on non-zero. Reads from `$AGNOSHI_LAST_EXIT`.
- **`src/render.cyr`** — render pipeline. Walks the (currently hard-coded) segment list, joins non-empty outputs with a single space, appends `$ ` trailer.
- **`src/main.cyr`** — wires `getenv` → `Context` → `render_prompt`. Replaces the `hello from commandress` stub.
- **Tests** (`tests/commandress.tcyr`) — 7 tests across cwd + exit segments (13 assertions), incl. home-prefix exact-match, strict-prefix, bad-home fallback, negative exit code. `cyrius test` 13/13 green.
- **Benchmarks** (`tests/commandress.bcyr`) — per-segment + full-prompt timings. Initial numbers on the dev host: cwd 664 ns / exit 38 ns / `render_prompt` 2 µs avg — **0.04 % of the 5 ms budget**. (Old `bench(...)` 3-arg scaffold stub replaced; it didn't reference any real symbol — `bench_new` + `bench_batch_start/stop` is the real API.)

### Changed

- Bumped Cyrius toolchain pin from `5.11.54` → `5.11.59` in `cyrius.cyml` and synced `lib/` from `~/.cyrius/versions/5.11.59/lib` via `cyrius lib sync`. Picks up the v5.11.55–.59 wrapper polish (manifest-pin drift detection, `--strict-pin`, `cyrius lib sync` itself) and the DCE-aware undef-fn reachability filter (cross-arch).
- Binary size: **58,568 B → 73,544 B** (+14,976 B for the M1 segments + render pipeline + tests).
- Roadmap M1 ADR references renumbered: `ADR 0001/0002` → `ADR 0002/0003` (the original `0001` is reserved for the already-accepted repo-split decision; ADR numbers never renumber).

## [0.1.0] — 2026-05-15

### Added

- Initial `cyrius init commandress` scaffold — `VERSION`, `cyrius.cyml`, `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `LICENSE`, `.gitignore`, `src/{main,test}.cyr`, `tests/commandress.{tcyr,bcyr,fcyr}`, `docs/{adr,architecture,guides,examples,development}/` per [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md).
- Cyrius toolchain pin `5.11.54` in `cyrius.cyml [package].cyrius`.
- Binary output name `cmdrs` (short for *commandress*) configured via `[build].output`.
- README, CLAUDE.md, `docs/development/{state,roadmap}.md`, `docs/guides/getting-started.md` filled with project-specific content per [first-party-standards.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md).

### Identity

`commandress` (binary: `cmdrs`) — a structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) and eventually bash/zsh. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius. Stateless, segment-based, config-driven, zero non-stdlib deps.
