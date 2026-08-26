# 003 — What `cyrius.lock` actually records, and what a `path` override does to it

commandress gained its first `cyrius.lock` at 1.1.5, with the cmdit dependency
([ADR 0008](../adr/0008-cli-parsing-via-cmdit.md)). Two properties of that file are
non-obvious, and both were established by experiment on Cyrius 6.5.35 rather than
taken from the surrounding ecosystem's comments.

## 1. Line order is not stable across machines

`cyrius deps` writes the lock as one `commit` line (per git dep) followed by
`<sha256>  lib/<file>` lines — 119 of them here. **The order of the hash lines is
not deterministic across machines.** It tracks the directory read order of `lib/`,
so the same dependency graph produces the same 119 hashes in a different sequence
on a fresh CI checkout than on a developer box.

Consecutive local runs *are* byte-stable, which makes this easy to get wrong: the
first version of the CI guard was `git diff --exit-code -- cyrius.lock`, it passed
every local check, and it failed on its first real CI run with a ~100-line diff of
reordered-but-identical entries (`lib/bayan.cyr` carried byte-identical hashes on
both sides).

**Consequence**: any check on this file must be order-insensitive. `scripts/lock-check.sh`
compares the `commit` lines and the hash lines as two independently sorted sets.

## 2. A `path` override erases the dep pin entirely

The ecosystem comments (stiva's `cyrius.cyml`, quoted into ours when the dep landed)
say the lock "records only bare `<sha256>  lib/<file>` lines (no dep name / version /
rev), so it cannot detect the substitution" when a `path = "../<dep>"` override
silently wins over a `tag`.

**On 6.5.35 that is no longer true, and the correction cuts the useful way.** The lock
*does* record a pin line:

```
commit	e69bcaa361dca638bb73a7a3669378bed851aa40	cmdit	https://github.com/MacCracken/cmdit.git	1.2.4
```

sha, dep name, URL, and tag. And resolving with `path = "../cmdit"` active does not
merely change that line — **it omits it completely**. A path-override lock has zero
`commit` lines.

That makes the substitution *detectable*, where the older comment assumed it was not:
a committed lock missing a `commit` line for a declared git dep was built against a
sibling checkout. `scripts/lock-check.sh` fails on exactly that, and it is the case
the script exists for.

## Verified behaviour

Measured against the real toolchain and dependency (Cyrius 6.5.35, cmdit 1.2.4):

| Committed lock state | `lock-check.sh` |
|---|---|
| Clean tag resolution | pass |
| Same entries, shuffled order | **pass** (property 1) |
| One file hash altered | fail — file-set branch |
| Dep `commit` sha altered to a nonexistent rev | fail — `cyrius deps` cannot resolve it |
| Generated with `path = "../cmdit"` active | **fail — pin branch** (property 2) |

## Practical rule

Keep `path = "../cmdit"` commented out in `cyrius.cyml` and resolve from the tag, so
the lock means one thing and CI's build is the build. To develop cmdit alongside
commandress, uncomment it, work, then tag cmdit, bump the pin here, re-resolve with
the override off, and commit that lock. CI will reject the other kind.
