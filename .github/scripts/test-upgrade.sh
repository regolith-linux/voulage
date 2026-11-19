#!/bin/bash
#
# Test that a Regolith desktop installed from one archive line upgrades
# cleanly to another, e.g. from "stable <codename> v3.4" to
# "stable <codename> v3.5", the way users upgrade: change the sources line,
# then "apt full-upgrade".
#
# Runs as root in a clean <distro>:<codename> container (see
# .github/workflows/test-desktop-upgradable.yml):
#
#   1. install regolith-desktop and each session package the "from" line has
#      (regolith-session-flashback, regolith-session-sway),
#   2. replace the sources line with the "to" line and run
#      "apt-get full-upgrade",
#   3. check the result.
#
# The test fails when the upgrade fails, when a package it installed in
# step 1 is no longer installed, when a package is left not upgraded or in a
# broken state, or when an installed package is older than the "to" line's
# version. Packages that were removed, or that are still installed but no
# longer in any archive line (left over from the "from" line), are listed as
# warnings: they are expected when a release drops a package, and belong in
# the release notes.
#
# Usage: test-upgrade.sh <distro> <codename> <arch> <from: "suite component"> <to: "suite component">
#   e.g. test-upgrade.sh ubuntu noble amd64 "stable v3.4" "stable v3.5"

set -o errexit
set -o nounset
set -o pipefail

if [ $# -ne 5 ]; then
  echo "Usage: $0 <distro> <codename> <arch> <from suite component> <to suite component>" >&2
  exit 2
fi

DISTRO=$1
CODENAME=$2
ARCH=$3
read -r FROM_SUITE FROM_COMPONENT <<< "$4"
read -r TO_SUITE TO_COMPONENT <<< "$5"

ARCHIVE_URL=${ARCHIVE_URL:-http://archive.regolith-desktop.com}
KEY_URL="$ARCHIVE_URL/regolith.key"
KEYRING=/etc/apt/keyrings/regolith.gpg
SOURCES=/etc/apt/sources.list.d/regolith.list
SESSIONS=(regolith-session-flashback regolith-session-sway)
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}

export DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC LC_ALL=C
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

FROM_LINE="deb [arch=$ARCH signed-by=$KEYRING] $ARCHIVE_URL/$DISTRO/$FROM_SUITE $CODENAME $FROM_COMPONENT"
TO_LINE="deb [arch=$ARCH signed-by=$KEYRING] $ARCHIVE_URL/$DISTRO/$TO_SUITE $CODENAME $TO_COMPONENT"

FAILED=0
fail() {
  echo "::error::$1"
  echo "- :x: $1" >> "$SUMMARY"
  FAILED=1
}
warn() {
  echo "::warning::$1"
  echo "- :warning: $1" >> "$SUMMARY"
}

installed_packages() {
  dpkg-query -W -f '${db:Status-Abbrev} ${Package} ${Version}\n' | awk '$1 == "ii" { print $2, $3 }' | sort
}

echo "## Upgrade $DISTRO $CODENAME $ARCH: $FROM_SUITE $FROM_COMPONENT → $TO_SUITE $TO_COMPONENT" >> "$SUMMARY"

echo "::group::Prepare the container"
apt-get update
apt-get "${APT_OPTS[@]}" install --no-install-recommends ca-certificates wget gnupg tzdata
mkdir -p /etc/apt/keyrings
wget -qO - "$KEY_URL" | gpg --dearmor > "$KEYRING"
echo "::endgroup::"

echo "::group::Install from $FROM_LINE"
echo "$FROM_LINE" > "$SOURCES"
apt-get update
targets=(regolith-desktop)
for session in "${SESSIONS[@]}"; do
  if [ -z "$(apt-cache madison "$session" 2>/dev/null)" ]; then
    continue
  fi
  # A session package can be in the archive without being installable on the
  # codename (e.g. regolith-session-sway in bookworm v3.4, whose sway
  # packages aren't built for bookworm): leave it out, but say so.
  if apt-get -s install regolith-desktop "$session" > /dev/null 2>&1; then
    targets+=("$session")
  else
    warn "$session is in the from line but not installable there, not testing it"
  fi
done
echo "Installing: ${targets[*]}"
apt-get "${APT_OPTS[@]}" install "${targets[@]}"
installed_packages > /tmp/before.txt
echo "::endgroup::"
echo "Installed from the from line: \`${targets[*]}\` ($(wc -l < /tmp/before.txt) packages in total)" >> "$SUMMARY"

echo "::group::Upgrade to $TO_LINE"
echo "$TO_LINE" > "$SOURCES"
apt-get update
if ! apt-get "${APT_OPTS[@]}" full-upgrade; then
  fail "apt-get full-upgrade failed"
fi
installed_packages > /tmp/after.txt
echo "::endgroup::"

echo "::group::Check the upgraded system"
for package in "${targets[@]}"; do
  if ! awk -v p="$package" '$1 == p { found = 1 } END { exit !found }' /tmp/after.txt; then
    fail "$package is not installed after the upgrade"
  fi
done

if ! apt-get check; then
  fail "apt-get check reports broken dependencies"
fi

audit=$(dpkg --audit || true)
if [ -n "$audit" ]; then
  echo "$audit"
  fail "dpkg --audit reports packages in a broken state"
fi

# Nothing may be left to upgrade, hold back or remove.
pending=$(apt-get -s "${APT_OPTS[@]}" full-upgrade | grep -E '^(Inst|Remv) ' || true)
if [ -n "$pending" ]; then
  echo "$pending"
  fail "the upgrade left packages to install, upgrade or remove: $(echo "$pending" | awk '{print $2}' | sort -u | tr '\n' ' ')"
fi

# Every installed package that the to line has must be at least at its
# version there (a downgrade would mean the to line is behind the from line).
# The to line's indexes, binary-<arch> and binary-all; apt may store them
# compressed (Docker images set Acquire::GzipIndexes), which cat-file reads.
mapfile -t to_indexes < <(find /var/lib/apt/lists \
  -name "*_${DISTRO}_${TO_SUITE}_dists_${CODENAME}_${TO_COMPONENT}_binary-${ARCH}_Packages*" -o \
  -name "*_${DISTRO}_${TO_SUITE}_dists_${CODENAME}_${TO_COMPONENT}_binary-all_Packages*")
if [ ${#to_indexes[@]} -eq 0 ]; then
  fail "no package index of the to line in /var/lib/apt/lists"
else
  for index in "${to_indexes[@]}"; do
    /usr/lib/apt/apt-helper cat-file "$index"
  done | awk '/^Package:/ { p = $2 } /^Version:/ { print p, $2 }' | cat > /tmp/to-index.txt
  if [ ! -s /tmp/to-index.txt ]; then
    fail "the package index of the to line lists no package: ${to_indexes[*]}"
  fi
  while read -r package version candidate; do
    if dpkg --compare-versions "$version" lt "$candidate"; then
      fail "$package is at $version, older than $candidate in the to line"
    fi
  done < <(awk 'NR == FNR { v[$1] = $2; next } $1 in v { print $1, v[$1], $2 }' /tmp/after.txt /tmp/to-index.txt)
fi

# Set operations use awk, not comm or join: uutils coreutils 0.2.2 (the
# default coreutils of Ubuntu 25.10) gives wrong results for comm on
# correctly sorted input.
only_in() {  # only_in <a> <b>: packages in list a but not in list b
  awk 'NR == FNR { seen[$1]; next } !($1 in seen) { print $1 }' "$2" "$1" | sort -u | tr '\n' ' '
}

removed=$(only_in /tmp/before.txt /tmp/after.txt)
if [ -n "$removed" ]; then
  warn "removed by the upgrade: $removed"
fi

# Installed packages that no archive line has any more: left over from the
# from line, e.g. packages the new release dropped.
leftover=$(apt list --installed 2>/dev/null | awk -F/ '/,local\]/ { print $1 }' | tr '\n' ' ')
if [ -n "$leftover" ]; then
  warn "installed but no longer in any archive line (left over from $FROM_SUITE $FROM_COMPONENT): $leftover"
fi

changed=$(awk 'NR == FNR { v[$1] = $2; next } ($1 in v) && v[$1] != $2 { print $1 " " v[$1] " → " $2 }' /tmp/before.txt /tmp/after.txt)
added=$(only_in /tmp/after.txt /tmp/before.txt)
{
  echo "<details><summary>Package changes ($(echo -n "$changed" | grep -c . || true) upgraded, $(echo -n "$added" | wc -w) new)</summary>"
  echo
  echo '```'
  echo "$changed"
  [ -n "$added" ] && echo "new: $added"
  echo '```'
  echo "</details>"
} >> "$SUMMARY"
echo "::endgroup::"

if [ "$FAILED" -ne 0 ]; then
  echo "Upgrade test failed."
  exit 1
fi
echo "- :white_check_mark: upgrade succeeded" >> "$SUMMARY"
echo "Upgrade test passed."
