# 0012 — The probe cache is bounded by construction, not by eviction

**Status**: Accepted
**Date**: 2026-11-06

## Context

The cache kept one file per (segment, cwd), forever. Entries were tiny, but nothing collected them, and the 1.2.2 key change left every 8-hex entry an orphan. On tmpfs each non-empty entry costs 4 KiB of RAM, and a machine that had seen about 99,000 directories held 198 MB.

The roadmap assumed eviction: walk the directory and delete old entries. [The 2026-11-06 audit](../audit/2026-11-06-audit.md) measured what that takes. A bounded sweep is possible: one `getdents`, a few `unlinkat`s, under 5 µs per miss on average. But it needs a re-checked directory fd, name-shape filters, `fstatat` with no-follow, and an answer for tmpfs returning newest entries first. All of that is new code deleting files under `/tmp`, added to a release whose purpose is to reduce risk.

The same measurement showed what the cache is actually for. The TTL is one second with one-second mtime resolution, so an entry can never be served once it is about 2 s old. The useful cache is the directories visited in the last two seconds, which is a handful.

## Decision

**A cache file name is one of 256 slots per segment: `<segment>-<low byte of the hash>`. The entry is the full 64-bit hash as 16 hex digits, then the value. A read that finds another directory's key is a miss.**

There is nothing to sweep, because the directory cannot exceed 256 entries per segment, about 1 MiB at one page each. The key inside the entry keeps the 1.2.2 guarantee that one directory never shows another's branch.

## Consequences

- **Positive** — No eviction code, no `getdents`, no deletion. The bound holds on any filesystem and needs no clock.
- **Negative** — Two directories in one slot replace each other. With entries this short-lived, that costs a miss at most, and it takes two directories hashing alike and redrawing within the same second.
- **Negative** — Each entry grows by 16 bytes, and a hit compares 16 bytes.
- **Neutral** — Files from older versions are orphans and are never touched. They go at the next reboot on tmpfs, or through `systemd-tmpfiles`. A killed writer can still leave a `.tmp.<pid>`, which is rare now that `SIGXFSZ` is handled, and is cleaned the same way.
- **Neutral** — A future cached segment with a much longer TTL should re-check this. 1.4.1's shellouts would be the first.
  > **Update 2026-11-06** (annotation, not a revision): re-checked at 1.4.1. Version probes live 60 s, and this holds, because an entry is keyed by the tool's path rather than the cwd, so there are only a handful. See [ADR 0014](0014-version-probes-never-see-the-repo.md).

## Alternatives considered

- **A bounded sweep in `cache_put`.** Prototyped and measured at the costs above. It works, but it adds the riskiest kind of code to fix a problem a naming change removes.
- **A sweep in a forked child.** It would break "no child outliving the budget", and the stdout pipe stays open until exit anyway.
- **A size or count cap with LRU.** It needs metadata that survives across processes, for a cache whose entries die in two seconds.
