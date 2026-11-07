#!/usr/bin/env bash
# Install the Cyrius toolchain that `cyrius.cyml` pins. Run from the repo root.
#
# The `cyrius = "X.Y.Z"` pin is the single source of truth (CLAUDE.md: no toolchain
# version in CI YAML), so this reads it and hands it to the upstream installer.
#
# Do not hand-roll this by untarring the release asset into $HOME/.cyrius/{bin,lib}.
# That is the pre-6.5 layout, and from 6.5.x `cyrius deps` resolves the stdlib from
# $HOME/.cyrius/versions/<v>/lib and hard-fails if only the flat directories exist.
#
# Why each step is shaped as it is:
#
#   - The pin must look like a version. It goes into a URL, and curl normalises
#     `../..`, so a value such as `../../other/repo/main` would fetch another
#     repository's script and step around the tag pin (audit 2026-11-06, SC-07).
#   - The installer comes from the PINNED TAG, not `main`, so a change to that branch
#     cannot alter our builds (audit 2026-08-26, P-07). Git tags can still be moved.
#   - It is saved before it is run. `curl | sh` runs a partial script if the download
#     is cut short, and hid a failed fetch from the step (audit 2026-11-06, SC-06).
#
# What the installer verifies, stated exactly: the tarball's SHA256 against a file from
# the same release. On a fresh runner it prints "signature check skipped (no prior
# cyrsign; integrity is HTTPS + SHA256)", so this is not a signature check
# (audit 2026-11-06, SC-05).
set -euo pipefail

version="$(sed -n 's/^cyrius = "\(.*\)"$/\1/p' cyrius.cyml | head -n 1)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::the cyrius pin in cyrius.cyml is not X.Y.Z: '$version'"
  exit 1
fi

echo "Installing Cyrius $version"
installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT
curl -sSf "https://raw.githubusercontent.com/MacCracken/cyrius/$version/scripts/install.sh" -o "$installer"
CYRIUS_VERSION="$version" sh "$installer"

# A successful-looking install can leave no versions/<v>/lib snapshot, and every later
# cyrius command would then die on dependency resolution instead of here.
if [[ ! -d "$HOME/.cyrius/versions/$version/lib" ]]; then
  echo "::error::stdlib snapshot missing at ~/.cyrius/versions/$version/lib"
  exit 1
fi
"$HOME/.cyrius/bin/cyrius" version
if [[ -n "${GITHUB_PATH:-}" ]]; then echo "$HOME/.cyrius/bin" >> "$GITHUB_PATH"; fi
echo "toolchain ok: pin $version, snapshot present"
