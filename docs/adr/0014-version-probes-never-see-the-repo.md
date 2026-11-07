# 0014 — Version probes run outside the repo, and are cached per tool

**Status**: Accepted
**Date**: 2026-11-06

## Context

Roadmap 1.4.1 asked for `python --version`, `node --version` and `rustup show active-toolchain`, each behind a per-segment flag, default off, with "the 1 s TTL cache" making them "affordable" and vcs `budget_ms` as the pattern. [ADR 0005](0005-language-env-probe-pattern.md) kept a slot for them.

Measuring those commands first showed the plan could not be built as written, for two reasons.

**It was unsafe.** Run where the user stands, as every shellout here had been:

| Command, in a hostile directory | What happened |
|---|---|
| `rustup show active-toolchain`, with `rust-toolchain.toml` naming an uninstalled channel | **Tried to download it**, and wrote to the rustup home. Measured on rustup 1.29.2 with no network. The docs give `RUSTUP_AUTO_INSTALL` a default of 1. |
| `rustc --version`, with a `path` toolchain in `rust-toolchain.toml` | **Ran a binary from the repo.** |
| `rustup show active-toolchain`, same file | Printed the path. Ran nothing. |
| `python --version`, `node --version` | Opened nothing in the repo, checked with inotify against a control. |

Plain interpreters are safe. Anything that resolves a version per directory is not, and on many machines `python` and `node` on `PATH` are exactly that: a shim. pyenv's [CVE-2022-35861](https://vulnerability.circl.lu/vuln/CVE-2022-35861) ran attacker-chosen executables through a crafted `.python-version`, and mise's [CVE-2026-35533](https://osv.dev/vulnerability/GHSA-436v-8fw5-4mj8) ran a script from a repo's config. Neither was run here: no shims are installed on the dev host, and these come from the published advisories. A prompt that runs such a tool in the cwd turns `cd` into execution, whatever the tool's version.

**It was too slow.** ADR 0005 assumed 1–3 ms per shellout. Medians on the dev host, against a 5 ms budget for the whole prompt:

| Command | Median |
|---|---|
| `cyrius --version` | 0.4–1.9 ms |
| `python --version` | 4.6 ms |
| `rustup show active-toolchain` | 6.8 ms |
| `node --version` | 15 ms |

And a 1 s cache does not help. Prompts usually arrive more than a second apart, so it would miss on nearly every redraw.

## Decision

**A version probe runs from `/`, with a fixed environment, and its answer is cached per tool for 60 s. It only runs when no pin file exists, the segment's `shellout = true` is set, and a project marker is above the cwd.**

- **`/`, not the cwd.** The tool has nothing to act on. `shellout_capture_in` refuses to run the command if it cannot get there.
- **Fixed environment.** `RUSTUP_AUTO_INSTALL=0`, so even a missing default toolchain installs nothing. No `HOME`, no `PATH`. The one thing inherited is `RUSTUP_HOME`, if it is an absolute path: without it, rustup looks in the passwd home and creates one there if there is none, so a user who moved it would get an empty segment and a stray directory.
- **Per tool, 60 s.** The answer does not depend on the cwd, so an entry is keyed by the tool's resolved path. That costs one slow prompt a minute, and about 5 µs on the others.
- **Failure is cached too**, so a stalling tool costs one budget a minute, not one per redraw. The entry is claimed as a failure before the tool runs, and replaced by the answer.
- **No cache, no probe, and that includes a cache that cannot be written.** A full `/tmp` reads as a miss every time, so a probe that wrote only afterwards would run the tool on every redraw, and a stalling tool would stall every prompt. A failed claim stops the probe.
- **Output must look like a version.** At most 64 characters of `[0-9A-Za-z.+_-]`. A Python or Node version must start with a digit, because words are made of those characters too: `Python not found` would otherwise render `not`. A rustup toolchain may be named anything, so it must be followed by the reason rustup always prints, such as `(default)`. Anything else renders empty, before it reaches the sanitizer.
- **A pin file stops a probe, whatever it says.** An empty `.nvmrc`, a `path` toolchain and a `rust-toolchain.toml` with no channel all render empty. The project has said something this repo cannot read, the machine's default may be wrong there, and for a `path` toolchain it certainly is. Empty is better than wrong.
- **A project marker gates each one**: `pyproject.toml` or `requirements.txt`, `package.json`, `Cargo.toml`. Otherwise `python_env` would show in every directory.
- **Never `rustc --version`.**

`shellout = true` and `budget_ms` are new fields on the three segments, additive under [ADR 0007](0007-schema-freeze.md). `budget_ms` is 1 to 1000 and defaults to 50.

`cyrius_env` keeps running `cyrius --version` in the cwd. That tool also reads the repo's pin, but it refuses a pin that is not a plain version (tested with a traversal), and showing the pinned toolchain is the point.

## Consequences

- **Positive** — A repo cannot influence a probe. Replayed through the shipped binary: a `path` toolchain, an uninstalled channel, a planted `python3` with `.` on `PATH`, a hanging tool, a flood and escape sequences all failed, and `~/.rustup` was unchanged.
- **Positive** — With every probe off, nothing changes. A differential against 1.4.0 shows it.
- **Negative** — **A probe reports the machine's version, not the project's.** A project pinned some way this repo does not read, such as `.tool-versions`, `.node-version` or a Volta pin, shows the global version, which is wrong there. That is the price of keeping the repo out, and more pin files are the fix, not a probe in the cwd.
- **Negative** — A version change can take 60 s to show.
- **Negative** — With an empty environment a shim may fail and render empty. That is the safe direction.
- **Negative** — A machine with `rustup` but no rustup home gets one created by the probe. A repo cannot cause this, and `rustup` does the same for any command.
- **Negative** — The exit status is not read: a tool that prints a well-formed version and then fails still shows it. Stopping reading means killing the child ([Architecture 002](../architecture/002-shellout-watchdog.md)), so the status is not there to read, and a tool run from `/` gives a repo no way to cause this.
- **Negative** — One prompt a minute takes the tool's full time, about 5 to 20 ms, over the 5 ms budget. This is opt-in.
- **Neutral** — The cache layout is unchanged. [ADR 0012](0012-cache-bounded-by-construction.md) asked for a re-check at a longer TTL: a probe has about one key per segment, the tool's path, so nothing cycles through its slots the way cwds do. Two paths for one tool that share a slot, say from two shells with different `PATH`s, evict each other and run the tool on each redraw. That costs time and shows no wrong value, and it takes a 1-in-256 collision.

## Alternatives considered

- **As the roadmap wrote it: in the cwd, cached per directory for 1 s.** Unsafe and slow, as above.
- **In the cwd, with `RUSTUP_AUTO_INSTALL=0`.** This stops the download but not a shim reading the repo. It handles one tool's one behaviour.
- **Refuse known shim paths.** Which paths? They vary by tool and install, and a list of bad paths is the shape that keeps missing one.
- **`rustc --version`.** The obvious command, and the one that ran repo code.
- **Dropping the shellouts for more pin files.** Safe, free and more correct where it applies. It leaves a project with no pin showing nothing, which is what this opt-in exists for. The two are not exclusive, and more pin files stay worth adding.
