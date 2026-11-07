#!/usr/bin/env bash
# Run the binary that ships. Usage: scripts/smoke.sh build/cmdrs
#
# The suite compiles src/ into a test binary and never runs src/main.cyr, and the bench
# gate times render_prompt in-process. So a binary that crashed on its first line, or
# stalled for 200 ms at startup, or had lost the sanitizer call in render_prompt, passed
# every gate (audit 2026-11-06, SC-03). This is the check on what users actually run.
#
# SMOKE_BUDGET_US overrides the 5 ms cold-start budget. It takes the best of 21 runs,
# because a stall shows in every run and scheduler noise does not.
set -euo pipefail

bin="$(realpath "$1")"
budget_us="${SMOKE_BUDGET_US:-5000}"
fail() { echo "smoke: $1" >&2; exit 1; }

want="cmdrs $(tr -d '[:space:]' < VERSION)"
[[ "$("$bin" --version)" == "$want" ]] || fail "--version is not '$want'"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

# Hostile project files, through the real render path. Neither is shaped like a pin, so
# neither renders (ADR 0015).
printf '3.11\033[31mX\033]0;t\007\302\001\233Y\n' > .python-version
printf '{"engines":{"node":">=18\033]0;t\007\302\001\233"}}' > package.json
printf '[[prompt]]\nsegments = ["python_env", "node_env"]\nright_segments = ["python_env"]\ntrailer = "> "\n' > .commandress
export HOME="$work"
unset VIRTUAL_ENV

out="$("$bin")" || fail "non-zero exit"
[[ "$out" == *'> ' ]] || fail "the left prompt lost its trailer"
[[ "$out" != *'3.11'* ]] || fail "a hostile .python-version rendered"
[[ "$out" != *'>=18'* ]] || fail "a hostile package.json rendered"

printf '3.11\n' > .python-version
printf '{"engines":{"node":">=18"}}' > package.json
out="$("$bin")" || fail "non-zero exit"
[[ "$out" == *'3.11'* ]] || fail "python_env did not read .python-version"
[[ "$out" == *'>=18'* ]] || fail "node_env did not read package.json"

# Text with no shape rule goes through the sanitizer, so this is the check that the
# shipped binary calls it. The last part is the C1 pair that a dropped byte used to
# reassemble (audit 2026-11-06, T-03).
export VIRTUAL_ENV=$'/venvs/3.11\033[31mX\033]0;t\007\302\001\233Y'
out="$("$bin")" || fail "non-zero exit"
[[ "$out" == *'3.11'* ]] || fail "python_env lost VIRTUAL_ENV"
[[ "$out" != *$'\033]'* ]] || fail "OSC from VIRTUAL_ENV reached stdout"
[[ "$out" != *$'\a'* ]] || fail "BEL from VIRTUAL_ENV reached stdout"
[[ "$out" != *$'\033[31m'* ]] || fail "SGR from VIRTUAL_ENV reached stdout"
[[ "$out" != *$'\302\233'* ]] || fail "a C1 CSI from VIRTUAL_ENV reached stdout"

right="$("$bin" --side=right)" || fail "--side=right: non-zero exit"
[[ "$right" != *'> '* ]] || fail "--side=right painted the trailer"
[[ "$right" == *'3.11'* ]] || fail "--side=right lost its segment"
unset VIRTUAL_ENV

# A version probe must never see the repo. The stand-in `node` records where it ran and
# what it was given, in a project with no pin. ADR 0014.
# In a tree of their own, because the walks would find the hostile files above.
probes="$(mktemp -d)"
trap 'rm -rf "$work" "$probes"' EXIT
cd "$probes"
mkdir -p stub project probehome
printf '{}' > project/package.json
printf '#!/bin/sh\npwd > %s/probe-cwd\nenv > %s/probe-env\necho v26.1.0\n' "$probes" "$probes" > stub/node
chmod +x stub/node
printf '[[prompt]]\nsegments = ["node_env"]\ntrailer = ""\n' > probehome/.commandress
(cd project && HOME="$probes/probehome" PATH="$probes/stub:/usr/bin:/bin" "$bin" >/dev/null)
[[ ! -e probe-cwd ]] || fail "a probe ran with shellout off"
printf '[[prompt]]\nsegments = ["node_env"]\ntrailer = ""\n[[segments.node_env]]\nfg = "default"\nshellout = true\nbudget_ms = 1000\n' > probehome/.commandress
probed="$(cd project && HOME="$probes/probehome" PATH="$probes/stub:/usr/bin:/bin" "$bin")"
[[ "$probed" == '26.1.0' ]] || fail "the node probe rendered '$probed'"
[[ "$(cat probe-cwd)" == '/' ]] || fail "a probe ran in the repo, not in /"
if grep -q '^HOME=' probe-env; then fail "a probe was handed HOME"; fi

# The rustup home is the one thing a probe inherits, because rustup would otherwise look
# in the default one and create it. Only an absolute path means anything from `/`.
mkdir -p stub2 stub3
sed 's/^echo v26/echo v27/' stub/node > stub2/node
sed 's/^echo v26/echo v28/' stub/node > stub3/node
chmod +x stub2/node stub3/node
(cd project && RUSTUP_HOME=/custom/rustup HOME="$probes/probehome" PATH="$probes/stub2:/usr/bin:/bin" "$bin" >/dev/null)
grep -q '^RUSTUP_HOME=/custom/rustup$' probe-env || fail "a probe lost RUSTUP_HOME"
(cd project && RUSTUP_HOME=relative HOME="$probes/probehome" PATH="$probes/stub3:/usr/bin:/bin" "$bin" >/dev/null)
if grep -q '^RUSTUP_HOME=' probe-env; then fail "a probe was handed a relative RUSTUP_HOME"; fi

# What each segment asks, what stops it, and which budget it gets. A stand-in logs its
# name and arguments. A new directory is a new cache key, so each case runs for real.
tools() {
    mkdir -p "$1"
    printf '#!/bin/sh\n/usr/bin/sleep %s\necho "python3 $*" >> %s/tools.log\necho "Python 3.12.1"\n' "$2" "$probes" > "$1/python3"
    printf '#!/bin/sh\n/usr/bin/sleep %s\necho "node $*" >> %s/tools.log\necho v26.1.0\n' "$2" "$probes" > "$1/node"
    printf '#!/bin/sh\n/usr/bin/sleep %s\necho "rustup $*" >> %s/tools.log\necho "stable-x86_64-unknown-linux-gnu (default)"\n' "$2" "$probes" > "$1/rustup"
    printf '#!/bin/sh\necho "rustc $*" >> %s/tools.log\necho "rustc 9.9.9"\n' "$probes" > "$1/rustc"
    chmod +x "$1"/*
}
budgets() {
    printf '[[prompt]]\nsegments = ["python_env", "node_env", "rustup_env"]\nseparator = " "\ntrailer = ""\n' > probehome/.commandress
    printf '[[segments.python_env]]\nfg = "default"\nshellout = true\nbudget_ms = %s\n' "$1" >> probehome/.commandress
    printf '[[segments.node_env]]\nfg = "default"\nshellout = true\nbudget_ms = %s\n' "$2" >> probehome/.commandress
    printf '[[segments.rustup_env]]\nfg = "default"\nshellout = true\nbudget_ms = %s\n' "$3" >> probehome/.commandress
}
render_in() { (cd "$1" && HOME="$probes/probehome" PATH="$2:/usr/bin:/bin" "$bin"); }

mkdir -p allthree pinned blankpins
touch allthree/pyproject.toml allthree/package.json allthree/Cargo.toml
cp allthree/* pinned/
cp allthree/* blankpins/
printf '3.9\n' > pinned/.python-version
printf '18\n' > pinned/.nvmrc
printf '1.80\n' > pinned/rust-toolchain
touch blankpins/.python-version blankpins/.nvmrc blankpins/rust-toolchain

budgets 1000 1000 1000
tools t1 0
rm -f tools.log
[[ "$(render_in allthree "$probes/t1")" == '3.12.1 26.1.0 stable' ]] || fail "the three probes rendered '$(render_in allthree "$probes/t1")'"
[[ "$(sort tools.log | tr '\n' ';')" == 'node --version;python3 --version;rustup show active-toolchain;' ]] \
    || fail "the probes ran: $(tr '\n' ';' < tools.log)"

tools t2 0
rm -f tools.log
[[ "$(render_in pinned "$probes/t2")" == '3.9 18 1.80' ]] || fail "a pin file lost to a probe"
[[ ! -e tools.log ]] || fail "a probe ran with a pin file there: $(tr '\n' ';' < tools.log)"

tools t3 0
rm -f tools.log
[[ -z "$(render_in blankpins "$probes/t3")" ]] || fail "an empty pin file let a probe answer"
[[ ! -e tools.log ]] || fail "a probe ran past an empty pin file: $(tr '\n' ';' < tools.log)"

# A tool slower than the small budgets and quicker than the large one: only the segment
# holding the large one can answer.
tools t4 0.2; budgets 1000 1 1
[[ "$(render_in allthree "$probes/t4")" == '3.12.1' ]] || fail "python_env did not get its own budget_ms"
tools t5 0.2; budgets 1 1000 1
[[ "$(render_in allthree "$probes/t5")" == '26.1.0' ]] || fail "node_env did not get its own budget_ms"
tools t6 0.2; budgets 1 1 1000
[[ "$(render_in allthree "$probes/t6")" == 'stable' ]] || fail "rustup_env did not get its own budget_ms"

# A bad budget_ms is reported whether or not the probe is on.
printf '[[prompt]]\nsegments = ["node_env"]\n[[segments.node_env]]\nbudget_ms = 5000\n' > probehome/.commandress
[[ "$(render_in allthree "$probes/t1" 2>&1 >/dev/null)" == *'budget_ms in [[segments.node_env]]'* ]] \
    || fail "a bad budget_ms was not reported with shellout off"

# A pin that is a symlink must keep its name, whatever the file holds. ADR 0015.
mkdir -p links/shared
touch links/package.json
printf 'hunter2\n' > token
printf '20\n' > links/shared/.nvmrc
printf '[[prompt]]\nsegments = ["node_env"]\ntrailer = ""\n[[segments.node_env]]\nfg = "default"\n' > probehome/.commandress
ln -s shared/.nvmrc links/.nvmrc
[[ "$(render_in links "$probes/t1")" == '20' ]] || fail "a pin linked under its own name was lost"
rm links/.nvmrc
ln -s ../token links/.nvmrc
[[ -z "$(render_in links "$probes/t1")" ]] || fail "a pin linked to another name was shown"
rm links/.nvmrc
# A one-word file, so the shape rule cannot be what stops it.
ln -s /proc/self/comm links/.nvmrc
[[ -z "$(render_in links "$probes/t1")" ]] || fail "a proc file reached the prompt"
rm links/.nvmrc

# ~/.commandress is the user's own, so a dotfile manager may link it from any name.
mv probehome/.commandress probehome/dotfile.cyml
ln -s dotfile.cyml probehome/.commandress
printf '20\n' > links/.nvmrc
[[ "$(render_in links "$probes/t1")" == '20' ]] || fail "a linked ~/.commandress was refused"
rm links/.nvmrc probehome/.commandress probehome/dotfile.cyml

# Every segment takes max_length, from its own slot. A long enough value for each.
mkdir -p capped
printf '3.12.1\n' > capped/.python-version
printf '20.11.1\n' > capped/.nvmrc
printf '1.79.0\n' > capped/rust-toolchain
printf '[package]\n' > capped/cyrius.cyml
printf '1.2.3\n' > capped/VERSION
printf '#!/bin/sh\nprintf "On branch feature\\nChanges not staged\\n"\n' > t1/sit
chmod +x t1/sit
for seg in exit vcs time hostname user cyrius_env python_env node_env rustup_env; do
    printf '[[prompt]]\nsegments = ["%s"]\ntrailer = ""\n[[segments.%s]]\nfg = "default"\nmax_length = 2\n' "$seg" "$seg" > probehome/.commandress
    capped_out="$(cd capped && HOME="$probes/probehome" PATH="$probes/t1:/usr/bin:/bin" AGNOSHI_LAST_EXIT=127 "$bin")"
    [[ "$capped_out" == '..' ]] || fail "$seg did not take its own max_length: '$capped_out'"
done
printf '[[prompt]]\nsegments = ["vcs"]\ntrailer = ""\n[[segments.vcs]]\nfg = "default"\nmax_length = 6\n' > probehome/.commandress
[[ "$(render_in capped "$probes/t1")" == 'fe...*' ]] || fail "a cut lost the dirty marker"

# The default, on what a repo can reach: a branch name that would flood the screen.
mkdir -p t7 flood
printf '#!/bin/sh\nprintf "On branch %%08000d\\nnothing to commit, working tree clean\\n" 0\n' > t7/sit
chmod +x t7/sit
printf '[[prompt]]\nsegments = ["vcs"]\ntrailer = ""\n[[segments.vcs]]\nfg = "default"\n' > probehome/.commandress
flooded="$(render_in flood "$probes/t7")"
[[ "${#flooded}" == 128 ]] || fail "a long branch rendered ${#flooded} bytes, not the default 128"
[[ "$flooded" == *... ]] || fail "a cut branch did not end in dots"

# A VERSION the rule refuses stops the segment, as any pin does. Showing the toolchain
# there would present it as the project's version.
mkdir -p badversion
printf '[package]\n' > badversion/cyrius.cyml
printf '1:2.3\n' > badversion/VERSION
printf '#!/bin/sh\necho "cyrius $*" >> %s/tools.log\necho "cyrius 9.9.9"\n' "$probes" > t1/cyrius
chmod +x t1/cyrius
printf '[[prompt]]\nsegments = ["cyrius_env"]\ntrailer = ""\n[[segments.cyrius_env]]\nfg = "default"\n' > probehome/.commandress
rm -f tools.log
[[ -z "$(render_in badversion "$probes/t1")" ]] || fail "a refused VERSION fell through to the toolchain"
[[ ! -e tools.log ]] || fail "cyrius ran past a refused VERSION"
rm badversion/VERSION
[[ "$(render_in badversion "$probes/t1")" == '9.9.9' ]] || fail "no VERSION at all must still ask the toolchain"
cd "$work"

[[ -z "$("$bin" --help 2>/dev/null)" ]] || fail "--help wrote to stdout"
"$bin" --no-such-flag >/dev/null 2>&1 || fail "a bad flag must not exit non-zero"

best=999999999
for _ in {1..21}; do
  start=$EPOCHREALTIME
  "$bin" >/dev/null
  end=$EPOCHREALTIME
  us=$(( ${end/./} - ${start/./} ))
  if (( us < best )); then best=$us; fi
done
(( best <= budget_us )) || fail "cold start ${best} us exceeds ${budget_us} us"

echo "smoke: OK (best cold start ${best} us of ${budget_us} us)"
