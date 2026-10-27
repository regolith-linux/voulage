#!/usr/bin/env bash
#
# Tests for the package versions that update_changelog() in ext-debian.sh
# writes for each stage.
#
# Each case creates a throwaway package repository with a debian/changelog and
# one commit at a fixed committer date, runs update_changelog() on it, and
# checks the resulting version and how it sorts against other versions.
#
# Requires: bash, git, dpkg-dev, devscripts (dch)
#
# Usage: .github/scripts/tests/test-update-changelog.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# keep the user's git configuration out of the fixtures
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME="test" GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="test" GIT_COMMITTER_EMAIL="test@example.com"
export DEBEMAIL="test@example.com" DEBFULLNAME="test"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# shellcheck source=SCRIPTDIR/../ext-debian.sh
source "$SCRIPT_DIR/../ext-debian.sh"
set +e

FAILED=0

pass() {
  echo -e "\033[0;32mPASS\033[0m: $1"
}

fail() {
  echo -e "\033[0;31mFAIL\033[0m: $1"
  FAILED=1
}

# make_package <dir> <package> <changelog version> <distribution> <committer date>
make_package() {
  local dir=$1 package=$2 version=$3 dist=$4 date=$5

  mkdir -p "$dir/$package/debian/source"
  cat > "$dir/$package/debian/changelog" <<EOF
$package ($version) $dist; urgency=medium

  * Test entry.

 -- test <test@example.com>  Mon, 26 Oct 2026 18:57:00 +0000
EOF
  cat > "$dir/$package/debian/control" <<EOF
Source: $package
Section: x11
Priority: optional
Maintainer: test <test@example.com>
Standards-Version: 4.6.2

Package: $package
Architecture: all
Description: test package
 Test package.
EOF
  printf '#!/usr/bin/make -f\n%%:\n\tdh $@\n' > "$dir/$package/debian/rules"
  chmod +x "$dir/$package/debian/rules"
  echo "3.0 (quilt)" > "$dir/$package/debian/source/format"
  echo "content" > "$dir/$package/README"

  git -C "$dir/$package" init -q
  git -C "$dir/$package" add -A
  GIT_COMMITTER_DATE="$date" git -C "$dir/$package" commit -q -m "test"
}

# version_for <dir> <package> <stage> <codename>: run update_changelog(), print the new version
version_for() {
  (
    PKG_BUILD_PATH=$1 PACKAGE_NAME=$2 STAGE=$3 CODENAME=$4
    update_changelog >/dev/null 2>&1
    cd "$PKG_BUILD_PATH/$PACKAGE_NAME" && dpkg-parsechangelog --show-field Version
  )
}

head_short() {
  git -C "$1" rev-parse HEAD | cut -c1-7
}

expect_version() {
  local name=$1 actual=$2 expected=$3
  if [ "$actual" == "$expected" ]; then
    pass "$name: $actual"
  else
    fail "$name: expected '$expected', got '$actual'"
  fi
}

# expect_order <name> <a> <op> <b>
expect_order() {
  if dpkg --compare-versions "$2" "$3" "$4"; then
    pass "$1: $2 $3 $4"
  else
    fail "$1: expected $2 $3 $4"
  fi
}

#### quilt-style changelog version, each stage

D="$WORK_DIR/quilt"
make_package "$D" "pkg" "1.2.2-1" "noble" "2026-10-26T18:57:00Z"
SHA=$(head_short "$D/pkg")
cp -a "$D" "$D-copy"

expect_version "unstable, quilt version" "$(version_for "$D" pkg unstable resolute)" \
  "1.2.2-1-1regolith+git20261026.185700.$SHA-resolute"

for stage in testing backports release-3_4 release-3_5; do
  rm -rf "$D" && cp -a "$D-copy" "$D"
  expect_version "$stage keeps the release version" "$(version_for "$D" pkg "$stage" resolute)" \
    "1.2.2-1-1regolith-resolute"
done

rm -rf "$D" && cp -a "$D-copy" "$D"
expect_version "experimental, quilt version" "$(version_for "$D" pkg experimental resolute)" \
  "1.2.2-1-1regolith+git20261026.185700.$SHA-resolute"

#### the same commit gives the same version in every job

rm -rf "$D" && cp -a "$D-copy" "$D"
first=$(version_for "$D" pkg unstable questing)
rm -rf "$D" && cp -a "$D-copy" "$D"
again=$(version_for "$D" pkg unstable questing)
expect_version "rebuilding the same commit does not bump" "$again" "$first"

rm -rf "$D" && cp -a "$D-copy" "$D"
resolute=$(version_for "$D" pkg unstable resolute)
expect_version "codenames share the upstream version (one .orig.tar.gz)" "${resolute%-*}" "${first%-*}"

#### native-style changelog version

D="$WORK_DIR/native"
make_package "$D" "native" "4.11.12" "jammy" "2026-10-26T23:53:10Z"
SHA=$(head_short "$D/native")
expect_version "unstable, native version" "$(version_for "$D" native unstable resolute)" \
  "4.11.12-1regolith+git20261026.235310.$SHA-resolute"

#### version with a tilde

D="$WORK_DIR/tilde"
make_package "$D" "tilde" "2.1.1-1ubuntu1~ppa9" "bionic" "2026-10-26T08:00:00Z"
SHA=$(head_short "$D/tilde")
expect_version "unstable, version with a tilde" "$(version_for "$D" tilde unstable resolute)" \
  "2.1.1-1ubuntu1~ppa9-1regolith+git20261026.080000.$SHA-resolute"

#### UNRELEASED changelog entry

D="$WORK_DIR/unreleased"
make_package "$D" "unrel" "4.12.0" "UNRELEASED" "2026-10-27T09:00:00Z"
SHA=$(head_short "$D/unrel")
expect_version "unstable, UNRELEASED entry" "$(version_for "$D" unrel unstable resolute)" \
  "4.12.0-1regolith~git20261027.090000.$SHA-resolute"
if (PKG_BUILD_PATH=$D PACKAGE_NAME=unrel CODENAME=resolute dist_valid); then
  pass "UNRELEASED entry: dist_valid accepts the updated changelog"
else
  fail "UNRELEASED entry: dist_valid rejects the updated changelog"
fi

#### no git checkout: keep building, without a snapshot

D="$WORK_DIR/nogit"
make_package "$D" "nogit" "1.0.0" "jammy" "2026-10-26T18:57:00Z"
rm -rf "$D/nogit/.git"
expect_version "unstable without a git checkout" "$(version_for "$D" nogit unstable resolute)" \
  "1.0.0-1regolith-resolute"

#### version ordering

snap="1.2.2-1-1regolith+git20261026.185700.52ece7e-resolute"
expect_order "above the release in testing" "$snap" gt "1.2.2-1-1regolith-resolute"
expect_order "above today's unstable build of the same release" "$snap" gt "1.2.2-1-1regolith-resolute"
expect_order "below the next release" "$snap" lt "1.2.3-1-1regolith-resolute"
expect_order "below the next Debian revision" "$snap" lt "1.2.2-2-1regolith-resolute"
expect_order "later commit, same day" "1.2.2-1-1regolith+git20261026.190500.0123abc-resolute" gt "$snap"
expect_order "later commit, next day" "1.2.2-1-1regolith+git20261027.000100.fedcba9-resolute" gt "$snap"
expect_order "next release is above every snapshot of the previous one" \
  "4.11.13-1regolith-resolute" gt "4.11.12-1regolith+git20261231.235959.fffffff-resolute"
expect_order "UNRELEASED snapshot is below its release" \
  "4.12.0-1regolith~git20261027.090000.1234567-resolute" lt "4.12.0-1regolith-resolute"
expect_order "UNRELEASED snapshot is above the previous release's snapshots" \
  "4.12.0-1regolith~git20261027.090000.1234567-resolute" gt "4.11.12-1regolith+git20261026.235310.46ded90-resolute"
expect_order "snapshot after the release is above the UNRELEASED snapshots" \
  "4.12.0-1regolith+git20261028.100000.89abcde-resolute" gt "4.12.0-1regolith~git20261027.090000.1234567-resolute"
expect_order "same snapshot on the next Ubuntu release" \
  "1.2.2-1-1regolith+git20261026.185700.52ece7e-resolute" gt "1.2.2-1-1regolith+git20261026.185700.52ece7e-questing"

#### source package file names (stage_source, rebuild-sources.sh and the archive rely on them)

D="$WORK_DIR/source"
make_package "$D" "srcpkg" "1.2.2-1" "noble" "2026-10-26T18:57:00Z"
SHA=$(head_short "$D/srcpkg")
upstream="1.2.2-1-1regolith+git20261026.185700.$SHA"
(
  PKG_BUILD_PATH=$D PACKAGE_NAME=srcpkg STAGE=unstable CODENAME=resolute LOCAL_BUILD=true
  update_changelog >/dev/null 2>&1
  stage_source >/dev/null 2>&1
  rm -rf "$D/srcpkg/.git"
  cd "$D" && dpkg-source -b srcpkg >/dev/null 2>&1
)
for file in "srcpkg_${upstream}.orig.tar.gz" "srcpkg_${upstream}-resolute.debian.tar.xz" "srcpkg_${upstream}-resolute.dsc"; do
  if [ -f "$D/$file" ]; then
    pass "source package file $file"
  else
    fail "source package file $file not found: $(cd "$D" && ls)"
  fi
done

if [ "$FAILED" != 0 ]; then
  echo -e "\033[0;31mSome tests failed.\033[0m"
  exit 1
fi
echo -e "\033[0;32mAll tests passed.\033[0m"
