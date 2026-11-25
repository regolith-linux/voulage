#!/usr/bin/env bash
#
# Tests for the targets that failed-targets.sh holds back from publishing.
#
# Each case writes the build markers that the passing legs of a build matrix
# would leave and checks which "<stage> <distro> <codename>" lines come out.
#
# Requires: bash, jq
#
# Usage: .github/scripts/tests/test-failed-targets.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

FAILED=0

pass() {
  echo -e "\033[0;32mPASS\033[0m: $1"
}

fail() {
  echo -e "\033[0;31mFAIL\033[0m: $1"
  FAILED=1
}

# check <case> <expected output> <marker>...
# Runs failed-targets.sh with the current STAGES, DISTROS, CODENAMES, ARCHES,
# EXCLUDES and INCLUDES after creating one marker file per argument.
check() {
  local name="$1" expected="$2"
  shift 2

  local markers="$WORK_DIR/$name"
  mkdir -p "$markers"
  local marker
  for marker in "$@"; do
    [ -n "$marker" ] || continue
    echo "$marker" > "$markers/$marker"
  done

  local output
  if ! output=$("$SCRIPT_DIR/../failed-targets.sh" "$markers" 2>&1); then
    fail "$name: failed-targets.sh exited with an error: $output"
    return
  fi

  if [ "$output" == "$expected" ]; then
    pass "$name"
  else
    fail "$name: expected [$expected], got [$output]"
  fi
}

# The matrix of a testing build of two Ubuntu codenames and one Debian
# codename on two architectures. Debian has no noble or stonking and Ubuntu
# has no trixie, so those pairs are excluded, as matrix-builder does.
export STAGES='["testing"]'
export DISTROS='["ubuntu","debian"]'
export CODENAMES='["noble","stonking","trixie"]'
export ARCHES='["amd64","arm64"]'
export EXCLUDES='[{"distro":"ubuntu","codename":"trixie"},{"distro":"debian","codename":"noble"},{"distro":"debian","codename":"stonking"}]'
export INCLUDES='[]'

ALL=(
  testing-ubuntu-noble-amd64 testing-ubuntu-noble-arm64
  testing-ubuntu-stonking-amd64 testing-ubuntu-stonking-arm64
  testing-debian-trixie-amd64 testing-debian-trixie-arm64
)

check "all legs passed" "" "${ALL[@]}"

check "both architectures of one codename failed" "testing ubuntu stonking" \
  testing-ubuntu-noble-amd64 testing-ubuntu-noble-arm64 \
  testing-debian-trixie-amd64 testing-debian-trixie-arm64

check "one architecture of a codename failed" "testing ubuntu stonking" \
  testing-ubuntu-noble-amd64 testing-ubuntu-noble-arm64 \
  testing-ubuntu-stonking-arm64 \
  testing-debian-trixie-amd64 testing-debian-trixie-arm64

check "every leg failed" "testing debian trixie
testing ubuntu noble
testing ubuntu stonking"

check "markers of excluded pairs and of other runs are ignored" "testing ubuntu noble" \
  testing-ubuntu-noble-amd64 \
  testing-ubuntu-stonking-amd64 testing-ubuntu-stonking-arm64 \
  testing-debian-trixie-amd64 testing-debian-trixie-arm64 \
  testing-debian-noble-amd64 testing-debian-noble-arm64 \
  unstable-ubuntu-noble-arm64

# stage "all" builds several stages in one run; a stage is held on its own
STAGES='["unstable","testing"]' check "one stage of a codename failed" "testing ubuntu stonking" \
  "${ALL[@]/testing-ubuntu-stonking-amd64/}" \
  unstable-ubuntu-noble-amd64 unstable-ubuntu-noble-arm64 \
  unstable-ubuntu-stonking-amd64 unstable-ubuntu-stonking-arm64 \
  unstable-debian-trixie-amd64 unstable-debian-trixie-arm64

# release stages: matrix-builder also excludes debian/testing
STAGES='["release-3_5"]' CODENAMES='["noble","testing"]' \
  EXCLUDES='[{"distro":"ubuntu","codename":"testing"},{"distro":"debian","codename":"noble"},{"distro":"debian","codename":"testing"}]' \
  check "release stage with an excluded codename" "" \
  release-3_5-ubuntu-noble-amd64 release-3_5-ubuntu-noble-arm64

# a single-architecture run only needs that architecture's leg
ARCHES='["amd64"]' check "single architecture run" "" \
  testing-ubuntu-noble-amd64 testing-ubuntu-stonking-amd64 testing-debian-trixie-amd64

INCLUDES='[{"stage":"testing","distro":"ubuntu","codename":"questing"}]' \
  check "included targets are checked too" "testing ubuntu questing" "${ALL[@]}"

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi
