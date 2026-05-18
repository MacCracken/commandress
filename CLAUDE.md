# commandress — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (current version,
> binary size, segment count, supported shells, test counts, consumers)
> lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

## Project Identity

**commandress** (Latin/English: feminine form of "commander" — the prompt commands the line) — a structured, configurable shell prompt renderer for agnoshi (and eventually other shells). Sovereign-stack equivalent of starship, in Cyrius.

- **Type**: Binary (`cmdrs`)
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)
- **Shared crates**: [shared-crates.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/shared-crates.md)

## Goal

Own the *prompt-rendering* surface for AGNOS shells. Take shell context (`cwd`, last exit, git state, time, language env) as input; emit a configurable, segment-composed prompt string as output. Stay out of the shell's job — input loop, history, completion, execution all belong to agnoshi (or whatever shell invokes us). One binary, fast cold start, single render per redraw.

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, binary size, segment surface, supported shells, in-flight
> work, consumers. Refreshed every release.

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Project was scaffolded with `cyrius init commandress`. **Do not manually create project structure** — use the tools. If a tool is missing something, fix the tool.

## Quick Start

```sh
cyrius deps                                    # resolve stdlib deps
cyrius build src/main.cyr build/cmdrs          # compile (binary: cmdrs)
cyrius test                                    # run [build].test + tests/*.tcyr
cyrius bench tests/commandress.bcyr            # benchmarks
```

## Key Principles

- **Correctness over cleverness** — if the prompt is wrong, the bugs own you
- **Render time is a feature** — every segment runs on a budget; slow segments lose
- **Independent segments** — each segment is a pure function of input context; no shared mutable state, no cross-segment ordering dependencies
- **Config over code** — appearance, segment order, segment toggles live in `~/.commandress` (CYML format, no extension; see ADR 0006). Code change required only for new segment types
- **Static binary** — zero non-stdlib deps. Cold start under 5ms target on Cyrius-current hardware
- **agnoshi-first, shell-agnostic interface** — the binary takes context via env vars + flags; agnoshi-specific helpers live outside the binary (in agnoshi)
- ONE change at a time — never bundle unrelated segment additions
- Build with `cyrius build`, never raw `cat file | cc5`
- Every buffer declaration is a contract: `var buf[N]` = N **bytes**, not N entries

## Rules (Hard Constraints)

- **Read the genesis repo's CLAUDE.md first** — [agnosticos/CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to the GitHub API if needed
- Do not add external runtime deps — config + context-from-env is the only input surface
- Do not skip tests before claiming changes work
- Do not use `sys_system()` with unsanitized input — command injection risk; segments that read external state (git, vcs) must `exec_vec()` with explicit argv
- Do not trust external data (config file content, env vars, git output) without validation
- Do not use `break` in while loops with `var` declarations — use flag + `continue`
- Do not block on slow segments — segments missing their time budget render as empty, not as a stall
- Do not hardcode the toolchain version in CI YAML — `cyrius = "X.Y.Z"` in `cyrius.cyml` is the source of truth
- **No shell logic** — `cmdrs` does not execute commands, manage history, or own readline. If you find yourself implementing shell features, you're in the wrong repo (it's agnoshi)

## Process

### Work Loop (continuous)

1. **Work phase** — features (new segments), bug fixes, perf
2. **Build check** — `cyrius build src/main.cyr build/cmdrs`
3. **Test + benchmark additions** — every new segment gets a unit test + a render-time benchmark
4. **Internal review** — segment isolation, time budget, error handling
5. **Security check** — any new external command exec? Any new file read? Validate.
6. **Documentation** — CHANGELOG, `docs/development/state.md`, any ADR earned (new segment design, new config field, etc.)
7. **Version sync** — `VERSION`, `cyrius.cyml`, CHANGELOG header

### Task Sizing

- **Low/Medium**: a new segment (cwd / time / git-branch / exit-code) — batch freely
- **Large**: cross-segment refactors (rendering pipeline, config schema breaking change) — small bites, verify each

## Cyrius Conventions

- All struct fields are 8 bytes (`i64`), accessed via `load64` / `store64` with offset
- Heap allocation via `fl_alloc()` / `fl_free()` for data with individual lifetimes
- Bump allocation via `alloc()` for long-lived data (segment-output buffers)
- Enum values for constants — don't consume `gvar_toks` slots (256 initialized globals limit)
- `break` in while loops with `var` declarations is unreliable — use flag + `continue`
- No negative literals — write `(0 - N)` not `-N`
- No mixed `&&` / `||` in one expression — nest `if` blocks instead

## Documentation

- [`docs/adr/`](docs/adr/) — architecture decision records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — non-obvious constraints (*what's true about the code?*)
- [`docs/guides/`](docs/guides/) — task-oriented how-tos
- [`docs/examples/`](docs/examples/) — runnable examples
- [`docs/development/state.md`](docs/development/state.md) — **live state snapshot**, refreshed every release
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — milestones through v1.0
- [`CHANGELOG.md`](CHANGELOG.md) — source of truth for all changes

New quirks and constraints land in `docs/architecture/` as numbered items (`NNN-kebab-case.md`). New decisions land in `docs/adr/` using [`template.md`](docs/adr/template.md). **Never renumber either series.**

Full doc-tree convention: [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md).

## .gitignore

Standard scaffold per first-party-documentation § `.gitignore`. Do not edit unless adding repo-specific artifacts.

## CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/). Performance claims (cold-start time, per-segment render time, full-prompt render time) **must** include benchmark numbers. Breaking changes (config schema, output format) get a **Breaking** section with migration guide.
