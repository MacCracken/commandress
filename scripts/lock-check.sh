#!/usr/bin/env bash
# Fail unless `lib/` and `cyrius.lock` at HEAD are exactly what the pins regenerate.
#
# Regenerate both in a throwaway worktree of HEAD, then compare. It reads no working
# tree, so step order cannot change the answer and a local run cannot touch your edits.
# Comparing a tree against itself is how this guard failed twice before (audit
# 2026-08-26, A-03; audit 2026-11-06, SC-02). Do not bring back a working-tree fallback.
#
# Why not `cyrius deps --locked`. It trusts the manifest, and the manifest is in the
# same commit. Moving a compiled file out of the declared footprint exempts it, so a
# commit that drops `pwd` from `[deps].stdlib`, edits `lib/pwd.cyr` and fixes its lock
# line passed every guard here and shipped (audit 2026-11-06, SC-01). It also exits 0
# on a stale `commit` line, with only a `note:`. This guard caught all 37 bad states
# tried, in both step orders, where `--locked` alone missed 8. See
# docs/architecture/003-cyrius-lock-shape.md.
#
# The comparison sorts the lock, because `cyrius deps` does not emit entries in a
# stable order across machines.
#
# It does not cover tampering in `src/`, a compromised toolchain, or a commit that moves
# the pins and `lib/` together on purpose. Those are review questions.
#
# Exit: 0 clean, 1 anything else.
set -euo pipefail

tmp="$(mktemp -d)"
trap 'git worktree remove --force "$tmp/w" 2>/dev/null || true; rm -rf "$tmp"' EXIT

git cat-file -e HEAD:cyrius.lock || {
  echo "lock-check: no cyrius.lock committed at HEAD" >&2
  exit 1
}

git worktree add -q --detach "$tmp/w" HEAD
cd "$tmp/w"
rm -rf lib cyrius.lock
cyrius lib sync --full --no-lock >/dev/null
cyrius deps >/dev/null

drift="$(git status --porcelain -- lib)"
if [[ -n "$drift" ]]; then
  echo "lock-check: lib/ is not what the pins regenerate:" >&2
  echo "$drift" | head -n 20 >&2
  exit 1
fi

if ! diff <(git show HEAD:cyrius.lock | sort) <(sort cyrius.lock) >&2; then
  echo "lock-check: cyrius.lock is not what the pins regenerate" >&2
  exit 1
fi

echo "lock-check: OK, lib/ and cyrius.lock regenerate exactly from the pins"
