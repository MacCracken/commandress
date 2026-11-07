# 003 — What `cyrius.lock` actually records, and what a `path` override does to it

commandress gained its first `cyrius.lock` at 1.1.5, with the cmdit dependency
([ADR 0008](../adr/0008-cli-parsing-via-cmdit.md)). Two properties of that file are
non-obvious, and both were established by experiment on Cyrius 6.5.35 rather than
taken from the surrounding ecosystem's comments.

## 1. Line order is not stable across machines

`cyrius deps` writes the lock as one `commit` line (per git dep) followed by
`<sha256>  lib/<file>` lines — 116 of them as of 1.2.3. **The order of the hash lines is
not deterministic across machines.** It tracks the directory read order of `lib/`,
so the same dependency graph produces the same hashes in a different sequence
on a fresh CI checkout than on a developer box.

Consecutive local runs *are* byte-stable, which makes this easy to get wrong: the
first version of the CI guard was `git diff --exit-code -- cyrius.lock`, it passed
every local check, and it failed on its first real CI run with a ~100-line diff of
reordered-but-identical entries (`lib/bayan.cyr` carried byte-identical hashes on
both sides).

**Consequence**: any check on this file must be order-insensitive. `scripts/lock-check.sh`
sorts both sides before it compares them.

## 2. A `path` override erases the dep pin entirely

This describes pins before cyrius 6.7.6. Section 4 has the current behaviour.

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

## 3. A tag bump can leave the old pin in the lock

Measured on Cyrius 6.6.20, moving cmdit `1.2.4` to `1.2.6`. `cyrius lib sync` carries
`commit` lines forward, and `cyrius deps` then adds the new tag's line without pruning the
old one:

```
commit	e69bcaa361dca638bb73a7a3669378bed851aa40	cmdit	https://github.com/MacCracken/cmdit.git	1.2.4
commit	c74cb7de35d66abd670d362888949f83c385fc95	cmdit	https://github.com/MacCracken/cmdit.git	1.2.6
```

Later `cyrius deps` runs keep both lines. The stale line is noise rather than a build hazard,
because the file hashes still describe what is compiled, but it does make the lock wrong.
`cyrius deps --locked` prints a `note:` calling this "fail-closed" and then exits 0.

## 4. From cyrius 6.7.6 a `path` override cannot win

Cyrius 6.7.6 made manifests git-first, so section 2 describes older pins only. Measured on 6.7.18
with `path = "../cmdit"` beside the tag:

| Run | What it builds | `lib/` and `cyrius.lock` |
|---|---|---|
| `cyrius deps` | The tag, with a one-line hint naming the unused checkout | Unchanged |
| `CYRIUS_LOCAL=1 cyrius deps` | The sibling, in `build/local-deps/` | Unchanged |

## 5. What each guard catches

Measured at 1.2.2 on cyrius 6.7.18, each bad state committed and then checked from a fresh
clone with an empty deps cache. 37 bad states were tried. The table counts how many each
guard missed.

| Guard | Missed |
|---|---|
| `cyrius deps --verify` | 23 |
| CI as it stood (`cyrius deps`, then the old `lock-check.sh`) | 14 |
| Old `lock-check.sh` alone | 12 |
| `cyrius deps --locked` alone | 8 |
| **`scripts/lock-check.sh` since 1.2.3** | **0**, in both step orders |

Three things explain the gap.

**The manifest is in the same commit.** `cyrius deps` restores and checks only the footprint
it works out from `cyrius.cyml`. Anything else in `lib/` is "outside the declared footprint":
kept, and silently re-hashed into the lock. So one commit could drop `pwd` from `[deps].stdlib`,
edit `lib/pwd.cyr` and fix its lock line, and every guard passed. The edited code then shipped
from a green CI (2026-11-06 audit, SC-01). Nothing requires an `include "lib/x.cyr"` to be
declared.

**`cyrius deps` repairs what it is about to be checked for.** Run first, as CI did, it hid an
altered file from the next step and regenerated a deleted lock, which removes the commit pin
that stops a moved tag (SC-02). Comparing a tree against itself is how the guard failed twice
(A-03, then this).

**A stale pin only prints a `note:`.** Failing on that text would close 2 of `--locked`'s 8
misses, and an upstream rewording would turn the check off silently.

So the guard reads no notes and does not parse the manifest. It regenerates `lib/` and the lock
from the pins in a throwaway worktree of HEAD and compares them with what is committed.
`lib/` is tracked (116 files, 38 of them compiled), which is why it has to check bytes.

It does not cover tampering in `src/`, a compromised toolchain, or a commit that moves the pins
and `lib/` together on purpose. Those are review questions.

## Moving the toolchain and a dep tag together

1. Bump `[package].cyrius` and `[deps.<name>].tag`.
2. Run `cyrius lib sync --full` **before** any `deps` or `build`. A build first writes the
   previous pin's hashes into the lock, and `lib sync` then refuses to run without
   `--relock`.
3. Run `rm cyrius.lock && cyrius deps` so the old pin cannot survive.
4. Check that `grep -c '^commit' cyrius.lock` equals the number of git deps.

To pick the tag, read that tag's own `cyrius` pin. `cyrius update` takes the latest tag,
which can require a newer toolchain than the one this repo is moving to.

## Practical rule

Resolve from the tag. To develop cmdit alongside commandress, uncomment `path` and work with
`CYRIUS_LOCAL=1`, which never writes `lib/` or the lock. Then tag cmdit and bump the pin here,
following the section above.
