#!/bin/bash
# This script builds packages for Debian-based systems
set -e

REPO_ROOT=$(realpath "$1")
STAGE=$2
DISTRO=$3
CODENAME=$4
ARCH=$5
PACKAGE_REPO_ROOT=$(realpath "$6") # Path to the local directory which is the package repo
PACKAGE_REPO_URL=$7  # The public URL that users will use to access the repo
BUILD_DIR=$(realpath "$8")
APT_KEY=$9

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
  dch --distribution "$CODENAME" --newversion "${version}-1regolith" "Automated release."

  cd - >/dev/null 2>&1 || exit
}

# Determine if the changelog has the correct distribution codename
dist_valid() {
  cd "${BUILD_DIR:?}/$PACKAGE_NAME"

  TOP_CHANGELOG_LINE=$(head -n 1 debian/changelog)
  CHANGELOG_DIST=$(echo "$TOP_CHANGELOG_LINE" | cut -d' ' -f3)

  cd - >/dev/null 2>&1
  # echo "Checking $CODENAME and $CHANGELOG_DIST"
  if [[ "$CHANGELOG_DIST" == *"$CODENAME"* ]]; then
    return 0
  else
    return 1
  fi
}

stage_source() {
  pushd .

  echo "Preparing source for $PACKAGE_NAME"
  cd "$BUILD_DIR/$PACKAGE_NAME" || exit
  debian_package_name=$(dpkg-parsechangelog --show-field Source)
  full_version=$(dpkg-parsechangelog --show-field Version)
  debian_version="${full_version%-*}"
  cd "$BUILD_DIR" || exit

  echo "Generating source tarball from git repo."
  tar cfzv $debian_package_name\_${debian_version}.orig.tar.gz --exclude .git\* --exclude debian $PACKAGE_NAME/../$PACKAGE_NAME

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
  pushd .
  echo "Building source package $PACKAGE_NAME"
  cd "$BUILD_DIR/$PACKAGE_NAME" || exit

  sanitize_git
  sudo apt build-dep -y .
  debuild -S -sa

  popd
}

build_bin_package() {
  pushd .
  echo "Building binary package $PACKAGE_NAME"
  cd "$BUILD_DIR/$PACKAGE_NAME" || exit

  debuild -sa -b
  popd
}

source_pkg_exists() {    
    SRC_PKG_VERSION=$(reprepro --basedir "$PACKAGE_REPO_ROOT" list "$CODENAME" "$1" | cut -d' ' -f3)

    SRC_PKG_BUILD_VERSION=$(echo $2 | cut -d'-' -f1)
    SRC_PKG_REPO_VERSION=$(echo $SRC_PKG_VERSION | cut -d'-' -f1)

    if [ "$SRC_PKG_REPO_VERSION" == "$SRC_PKG_BUILD_VERSION" ]; then
        return 0
    else
        return 1
    fi
}

publish_deb() {
  cd "${BUILD_DIR:?}/$PACKAGE_NAME"
  version=$(dpkg-parsechangelog --show-field Version)
  debian_package_name=$(dpkg-parsechangelog --show-field Source)
  cd "$BUILD_DIR"

  DEB_SRC_PKG_PATH="$BUILD_DIR/${debian_package_name}_${version}_source.changes"

  if [ ! -f "$DEB_SRC_PKG_PATH" ]; then
    echo "Failed to find changes file."
  fi

  if source_pkg_exists "$debian_package_name" "$version"; then
      echo "Ignoring source package, already exists in target repository"
  else
      echo "Ingesting source package $debian_package_name into $PACKAGE_REPO_ROOT"
      reprepro --basedir "$PACKAGE_REPO_ROOT" include "$CODENAME" "$DEB_SRC_PKG_PATH"
  fi
 
  DEB_CONTROL_FILE="$BUILD_DIR/$PACKAGE_NAME/debian/control"
 
  for target_arch in $(echo $ARCH | sed "s/,/ /g"); do
      cat "$DEB_CONTROL_FILE" | grep ^Package: | cut -d' ' -f2 | while read -r bin_pkg; do
          DEB_BIN_PKG_PATH="$(pwd)/${bin_pkg}_${version}_${target_arch}.deb"
          if [ -f "$DEB_BIN_PKG_PATH" ]; then
              echo "Ingesting binary package ${bin_pkg} into $PACKAGE_REPO_ROOT"
              reprepro --basedir "$PACKAGE_REPO_ROOT" includedeb "$CODENAME" "$DEB_BIN_PKG_PATH"
          else
              echo "Package $DEB_BIN_PKG_PATH does not exist for $target_arch"
          fi
      done
  done
}

generate_reprepro_dist() {      
    mkdir -p "$PACKAGE_REPO_ROOT/conf"

    echo "Origin: $PACKAGE_REPO_URL" > "$PACKAGE_REPO_ROOT/conf/distributions"
    echo "Label: $PACKAGE_REPO_URL" >> "$PACKAGE_REPO_ROOT/conf/distributions"
    echo "Codename: $CODENAME" >> "$PACKAGE_REPO_ROOT/conf/distributions"
    echo "Architectures: $ARCH source" >> "$PACKAGE_REPO_ROOT/conf/distributions"
    echo "Components: main" >> "$PACKAGE_REPO_ROOT/conf/distributions"
    echo "Description: $STAGE $DISTRO $CODENAME $ARCH" >> "$PACKAGE_REPO_ROOT/conf/distributions"
    echo "SignWith: $APT_KEY" >> "$PACKAGE_REPO_ROOT/conf/distributions"
}

# Traverse the stage tree and execute any found setup.sh scripts
source_setup_scripts() {
  set -x
  local setup_script_locations=(
    "$REPO_ROOT/stage/setup.sh"
    "$REPO_ROOT/stage/$STAGE/setup.sh"
    "$REPO_ROOT/stage/$STAGE/$DISTRO/setup.sh"
    "$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/setup.sh"
    "$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/setup.sh"
  )

  for setup_file in "${setup_script_locations[@]}"
  do
    if [ -f "$setup_file" ]; then 
      echo "Executing setup file $setup_file..."
      source $setup_file
    fi
  done
}

setup() {
  if [ ! -d "$PACKAGE_REPO_ROOT/conf" ]; then
    echo "Package metadata not found, creating.."
    generate_reprepro_dist
  fi

  source_setup_scripts
}

# Start of script
setup

PACKAGE_CHANGES=$(git diff --diff-filter=AM | grep '^[+|-][^+|-]' | cut -c2- | uniq | sort)

if [ -z "$PACKAGE_CHANGES" ]; then
  echo "No changes found, exiting."
  exit 0
fi

while IFS= read -r PKG_LINE; do
  PACKAGE_NAME=$(echo "$PKG_LINE" | cut -d" " -f1)
  PACKAGE_URL=$(echo "$PKG_LINE" | cut -d" " -f2)
  PACKAGE_REF=$(echo "$PKG_LINE" | cut -d" " -f3)

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
