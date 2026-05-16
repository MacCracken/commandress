# Changelog

All notable changes to commandress will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] — 2026-05-15

### Added

- Initial `cyrius init commandress` scaffold — `VERSION`, `cyrius.cyml`, `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `LICENSE`, `.gitignore`, `src/{main,test}.cyr`, `tests/commandress.{tcyr,bcyr,fcyr}`, `docs/{adr,architecture,guides,examples,development}/` per [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md).
- Cyrius toolchain pin `5.11.54` in `cyrius.cyml [package].cyrius`.
- Binary output name `cmdrs` (short for *commandress*) configured via `[build].output`.
- README, CLAUDE.md, `docs/development/{state,roadmap}.md`, `docs/guides/getting-started.md` filled with project-specific content per [first-party-standards.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md).

### Identity

`commandress` (binary: `cmdrs`) — a structured shell prompt renderer for [agnoshi](https://github.com/MacCracken/agnoshi) and eventually bash/zsh. Sovereign-stack equivalent of [starship](https://starship.rs/), in Cyrius. Stateless, segment-based, config-driven, zero non-stdlib deps.
