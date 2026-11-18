#!/usr/bin/env bash
#
# Tests for the binary package set that publish() in ext-debian.sh publishes.
#
# Each case builds a throwaway source package with debhelper, the way CI does
# (a source build, then a binary build), runs publish() on the result and
# checks which files it published, or that it refused to publish anything.
#
# Requires: bash, dpkg-dev, debhelper, a C compiler
#
# Usage: .github/scripts/tests/test-publish.sh

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

export DEBEMAIL="test@example.com" DEBFULLNAME="test"
unset DEB_BUILD_PROFILES DEB_BUILD_OPTIONS

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# shellcheck source=SCRIPTDIR/../ext-debian.sh
source "$SCRIPT_DIR/../ext-debian.sh"
set +e

ARCH=$(dpkg --print-architecture)
FAILED=0

pass() {
  echo -e "\033[0;32mPASS\033[0m: $1"
}

fail() {
  echo -e "\033[0;31mFAIL\033[0m: $1"
  FAILED=1
}

# make_package <case> <control stanzas> <rules dh options> [<extra>]
# Creates source package "demo" 1.0-1 for <case>. Binary package "demo-bin"
# installs a compiled program, so debhelper adds demo-bin-dbgsym; every other
# binary package installs a text file. <extra> is "arch-all" for a source
# with only Architecture: all packages.
make_package() {
  local case_dir="$WORK_DIR/$1"
  local stanzas="$2"
  local dh_options="$3"
  local src="$case_dir/demo"

  mkdir -p "$src/debian"
  echo 'int main(void) { return 0; }' > "$src/demo.c"
  echo "data" > "$src/demo.txt"

  cat > "$src/debian/changelog" <<EOF
demo (1.0-1) unstable; urgency=medium

  * Test package.

 -- test <test@example.com>  Mon, 16 Nov 2026 12:00:00 +0000
EOF
  cat > "$src/debian/control" <<EOF
Source: demo
Section: misc
Priority: optional
Maintainer: test <test@example.com>
Build-Depends: debhelper-compat (= 13)
Standards-Version: 4.6.2
Rules-Requires-Root: no

$stanzas
EOF
  cat > "$src/debian/rules" <<EOF
#!/usr/bin/make -f
%:
	dh \$@ $dh_options

override_dh_auto_build:
	\$(CC) -g -O2 -o demo demo.c

override_dh_auto_install:
	for p in \$\$(dh_listpackages); do \\
	  if [ "\$\$p" = demo-bin ]; then \\
	    install -D -m 755 demo debian/\$\$p/usr/bin/demo; \\
	  else \\
	    install -D -m 644 demo.txt debian/\$\$p/usr/share/demo/\$\$p.txt; \\
	  fi; \\
	done
EOF
  chmod +x "$src/debian/rules"
  mkdir -p "$src/debian/source"
  echo "3.0 (quilt)" > "$src/debian/source/format"
  tar -C "$case_dir" --exclude=demo/debian -czf "$case_dir/demo_1.0.orig.tar.gz" demo

  (
    cd "$src" &&
      dpkg-buildpackage -S -us -uc -d &&
      dpkg-buildpackage -b -us -uc
  ) > "$case_dir/build.log" 2>&1 || {
    fail "$1: the test package did not build"
    tail -20 "$case_dir/build.log" | sed 's/^/    /'
    return 1
  }
}

# run_publish <case>: runs publish() for <case>, prints the published file
# names (sorted) and returns publish()'s status.
run_publish() {
  local case_dir="$WORK_DIR/$1"
  local status

  (
    PKG_BUILD_PATH="$case_dir"
    PKG_PUBLISH_PATH="$case_dir/publish"
    PACKAGE_NAME=demo
    DISTRO=debian CODENAME=test SUITE=testing COMPONENT=main STAGE=testing
    LOCAL_BUILD=false
    PKG_LINE="demo test 1.0-1 0"
    publish
  ) > "$case_dir/publish.log" 2>&1
  status=$?
  find "$case_dir/publish" -type f -name '*.deb' -printf '%f\n' 2>/dev/null | sort | tr '\n' ' '
  return $status
}

# expect_published <case> <expected .deb names, sorted, space separated>
expect_published() {
  local got
  if got=$(run_publish "$1"); then
    if [ "$got" == "$2 " ]; then
      pass "$1: published $2"
    else
      fail "$1: published '$got', expected '$2 '"
    fi
  else
    fail "$1: publish refused, expected '$2'"
    sed 's/^/    /' "$WORK_DIR/$1/publish.log"
  fi
}

# expect_refused <case> <text the error has to contain>
expect_refused() {
  local got
  if got=$(run_publish "$1"); then
    fail "$1: published '$got', expected publish to be refused"
  elif [ -n "$got" ]; then
    fail "$1: publish failed but still published '$got'"
  elif ! grep -qF -- "$2" "$WORK_DIR/$1/publish.log"; then
    fail "$1: publish refused, but the log doesn't mention '$2'"
    sed 's/^/    /' "$WORK_DIR/$1/publish.log"
  else
    pass "$1: refused ($2)"
  fi
}

V="1.0-1"
BIN="Package: demo-bin
Architecture: any
Depends: \${shlibs:Depends}, \${misc:Depends}, demo-common
Description: demo program
 Demo."
COMMON="Package: demo-common
Architecture: all
Depends: \${misc:Depends}
Description: demo common files
 Demo."
EXTRA="Package: demo-extra
Architecture: any
Depends: \${misc:Depends}, demo-common
Description: demo extra session
 Demo."

# 1. Everything built: all declared packages are published, -dbgsym is not.
make_package all-built "$BIN

$COMMON

$EXTRA" "" &&
  expect_published all-built "demo-bin_${V}_${ARCH}.deb demo-common_${V}_all.deb demo-extra_${V}_${ARCH}.deb" &&
  if grep -qE " demo-bin-dbgsym_${V}_${ARCH}\.d?deb$" "$WORK_DIR/all-built/demo_${V}_${ARCH}.changes"; then
    pass "all-built: the .changes lists demo-bin-dbgsym, which was left out"
  else
    fail "all-built: the .changes lists no demo-bin-dbgsym, so leaving it out wasn't tested"
  fi

# 2. debian/rules leaves out a package nothing depends on (like
#    regolith-session-sway on Debian): the rest is published.
make_package excluded-leaf "$BIN

$COMMON

$EXTRA" "-Ndemo-extra" &&
  expect_published excluded-leaf "demo-bin_${V}_${ARCH}.deb demo-common_${V}_all.deb"

# 3. debian/rules leaves out a package another one depends on: refused.
make_package excluded-dependency "$BIN

$COMMON

$EXTRA" "-Ndemo-common" &&
  expect_refused excluded-dependency "demo-bin (Depends: demo-common) needs demo-common"

# 4. The missing package is one alternative of the dependency, the other comes
#    from outside the source: published.
make_package excluded-alternative "Package: demo-bin
Architecture: any
Depends: \${shlibs:Depends}, \${misc:Depends}, demo-common | base-files
Description: demo program
 Demo.

$COMMON" "-Ndemo-common" &&
  expect_published excluded-alternative "demo-bin_${V}_${ARCH}.deb"

# 5. The missing package is provided by one that was built: published.
make_package provided "$BIN

$COMMON
Provides: demo-data

Package: demo-extra
Architecture: any
Depends: \${misc:Depends}, demo-data
Description: demo extra session
 Demo.

Package: demo-data
Architecture: all
Depends: \${misc:Depends}
Description: demo data
 Demo." "-Ndemo-data" &&
  expect_published provided "demo-bin_${V}_${ARCH}.deb demo-common_${V}_all.deb demo-extra_${V}_${ARCH}.deb"

# 6. Only Architecture: all packages: the binary .changes is still named after
#    the build architecture.
make_package arch-all-only "$COMMON" "" &&
  expect_published arch-all-only "demo-common_${V}_all.deb"

# 7. A .deb changed after the build: refused.
make_package tampered "$BIN

$COMMON" "" &&
  echo "junk" >> "$WORK_DIR/tampered/demo-common_${V}_all.deb" &&
  expect_refused tampered "demo-common_${V}_all.deb does not match the size and SHA-256 sum"

# 8. A .deb listed in the .changes is gone: refused.
make_package deleted "$BIN

$COMMON" "" &&
  rm "$WORK_DIR/deleted/demo-common_${V}_all.deb" &&
  expect_refused deleted "demo-common_${V}_all.deb is listed in"

# 9. No binary .changes (the binary build didn't finish): refused.
make_package no-changes "$COMMON" "" &&
  rm "$WORK_DIR/no-changes/demo_${V}_${ARCH}.changes" &&
  expect_refused no-changes "demo_${V}_${ARCH}.changes not found"

if [ "$FAILED" -ne 0 ]; then
  echo "Some tests failed."
  exit 1
fi
echo "All tests passed."
