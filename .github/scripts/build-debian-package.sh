#!/bin/bash

# This script builds packages for the debian os

set -e

REPO_ROOT=$(realpath "$1")
DIST_CODENAME=$2
BUILD_DIR=$(realpath "$3")

checkout() {
  if [ -z "$PACKAGE_URL" ]; then
    echo "Package model is invalid.  Model field 'source' undefined, aborting."
    exit 1
  fi

  if [ -d "$BUILD_DIR/$PACKAGE_NAME" ]; then
    echo "Deleting existing repo, $PACKAGE_NAME"
    rm -Rfv "${BUILD_DIR:?}/$PACKAGE_NAME"
  fi

  if [ ! -d "$BUILD_DIR" ]; then
    echo "Creating build directory $BUILD_DIR"
    mkdir -p "$BUILD_DIR" || {
      echo "Failed to create build dir $BUILD_DIR, aborting."
      exit 1
    }
  fi

  cd "$BUILD_DIR" || exit
  git clone --recursive "$PACKAGE_URL" -b "$PACKAGE_REF" "$PACKAGE_NAME"

  cd - >/dev/null 2>&1 || exit
}

# Update the changelog to specify the target distribution codename
update_changelog() {
  cd "${BUILD_DIR:?}/$PACKAGE_NAME"
  version=$(dpkg-parsechangelog --show-field Version)
  dch --distribution "$DIST_CODENAME" --newversion "${version}-1regolith-$(date +%s)" "Automated release."

  cd - >/dev/null 2>&1 || exit
}

# Determine if the changelog has the correct distribution codename
dist_valid() {
  cd "${BUILD_DIR:?}/$PACKAGE_NAME"

  TOP_CHANGELOG_LINE=$(head -n 1 debian/changelog)
  CHANGELOG_DIST=$(echo "$TOP_CHANGELOG_LINE" | cut -d' ' -f3)

  cd - >/dev/null 2>&1
  # echo "Checking $DIST_CODENAME and $CHANGELOG_DIST"
  if [[ "$CHANGELOG_DIST" == *"$DIST_CODENAME"* ]]; then
    return 0
  else
    return 1
  fi
}

stage_source() {
  pushd

  print_banner "Preparing source for $PACKAGE_NAME"
  cd "$BUILD_DIR/$PACKAGE_NAME" || exit
  full_version=$(dpkg-parsechangelog --show-field Version)
  debian_version="${full_version%-*}"
  cd "$BUILD_DIR" || exit

  echo "Generating source tarball from git repo."
  tar cfzv $PACKAGE_NAME\_${debian_version}.orig.tar.gz --exclude .git\* --exclude debian $PACKAGE_NAME/../$PACKAGE_NAME}

  popd
}

sanitize_git() {
  if [ -d ".github" ]; then
    rm -Rf .github
    echo "Removed $(pwd).github directory before building to appease debuild."
  fi
  if [ -d ".git" ]; then
    rm -Rf .git
    echo "Removed $(pwd).git directory before building to appease debuild."
  fi
}

build_src_package() {
  pushd
  print_banner "Building source package $PACKAGE_NAME"
  cd "$BUILD_DIR/$PACKAGE_NAME" || exit

  sanitize_git
  # sudo apt build-dep -y .
  debuild -S -sa

  popd
}

build_bin_package() {
  pushd
  print_banner "Building binary package $PACKAGE_NAME"
  cd "$BUILD_DIR/$PACKAGE_NAME" || exit

  debuild -sa -b
  popd
}

publish_deb() {
  set -x
  cd "${BUILD_DIR:?}/$PACKAGE_NAME"
  version=$(dpkg-parsechangelog --show-field Version)
  cd "$BUILD_DIR"

  DEB_SRC_PKG_PATH="$BUILD_DIR/${PACKAGE_NAME}_${version}_source.changes"

  if [ ! -f "$DEB_SRC_PKG_PATH" ]; then
    echo "Failed to find changes file."
  fi

  # if source_pkg_exists "$PACKAGE_NAME" "$version"; then
  #     echo "Ignoring source package, already exists in target repository"
  # else
  #     print_banner "Ingesting source package $PACKAGE_NAME into $REPO_PATH"
  #     reprepro --basedir "$REPO_PATH" include "$DIST_CODENAME" "$DEB_SRC_PKG_PATH"
  # fi
  #
  # DEB_CONTROL_FILE="$BUILD_DIR/$PACKAGE_NAME/debian/control"
  #
  # for target_arch in $(echo $PKG_ARCH | sed "s/,/ /g"); do
  #     cat "$DEB_CONTROL_FILE" | grep ^Package: | cut -d' ' -f2 | while read -r bin_pkg; do
  #         DEB_BIN_PKG_PATH="$(pwd)/${bin_pkg}_${version}_${target_arch}.deb"
  #         if [ -f "$DEB_BIN_PKG_PATH" ]; then
  #             print_banner "Ingesting binary package ${bin_pkg} into $REPO_PATH"
  #             reprepro --basedir "$REPO_PATH" includedeb "$DIST_CODENAME" "$DEB_BIN_PKG_PATH"
  #         else
  #             echo "Package $DEB_BIN_PKG_PATH does not exist for $target_arch"
  #         fi
  #     done
  # done
}

# Start of script
PACKAGE_CHANGES=$(git diff --diff-filter=AM | grep '^[+|-][^+|-]' | cut -c2- | uniq | sort)
while IFS= read -r PKG_LINE; do
  PACKAGE_NAME=$(echo $PKG_LINE | cut -d" " -f1)
  PACKAGE_URL=$(echo $PKG_LINE | cut -d" " -f2)
  PACKAGE_REF=$(echo $PKG_LINE | cut -d" " -f3)

  checkout
  update_changelog
  if dist_valid; then
    stage_source
    build_src_package
    build_bin_package
    publish_deb
  else
    echo "dist codename does not match in package changelog, ignoring $PACKAGE_NAME."
  fi
done <<<"$PACKAGE_CHANGES"
