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

## 3. A tag bump can leave the old pin in the lock, and the guard passes it

Measured on Cyrius 6.6.20, moving cmdit `1.2.4` to `1.2.6`. `cyrius lib sync` carries
`commit` lines forward, and `cyrius deps` then adds the new tag's line without pruning the
old one:

```
commit	e69bcaa361dca638bb73a7a3669378bed851aa40	cmdit	https://github.com/MacCracken/cmdit.git	1.2.4
commit	c74cb7de35d66abd670d362888949f83c385fc95	cmdit	https://github.com/MacCracken/cmdit.git	1.2.6
```

Later `cyrius deps` runs keep both lines. `lock-check.sh` then compares two pins against the
same two pins and reports `OK — 2 dep pin(s)`. The script proves that re-resolving does not
change the lock. It does not prove that the lock holds exactly the tags in `cyrius.cyml`.

| Committed lock state | `lock-check.sh` |
|---|---|
| Old and new `commit` lines for the same dep | **pass — a blind spot** |
| Regenerated from empty (one `commit` line) | pass |

## 4. From cyrius 6.7.6 a `path` override cannot win

Cyrius 6.7.6 made manifests git-first, so section 2 describes older pins only. Measured on 6.7.18
with `path = "../cmdit"` beside the tag:

| Run | What it builds | `lib/` and `cyrius.lock` |
|---|---|---|
| `cyrius deps` | The tag, with a one-line hint naming the unused checkout | Unchanged |
| `CYRIUS_LOCAL=1 cyrius deps` | The sibling, in `build/local-deps/` | Unchanged |

6.7.6 also added `cyrius deps --locked`, which resolves the tags, writes nothing, and fails naming
each difference. It and `scripts/lock-check.sh` do not catch the same things:

| Committed state | `deps --locked` | `lock-check.sh` |
|---|---|---|
| Clean tag resolution | pass | pass |
| A vendored `lib/` file altered | **fail, naming the file** | pass |
| An extra stale `commit` line (section 3) | pass, with a `note:` naming the stale pin | pass |

So neither one fails on the section 3 blind spot. The stale line is noise rather than a build hazard,
because the file hashes still describe what is compiled, but it does make the lock wrong.

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
