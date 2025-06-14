#!/bin/bash

set -e
set -o errexit
# Extension for Debian repo and package support

#### RPM specific functions

# Update the changelog to specify the target distribution codename
update_changelog() {
  :
}

# Determine if the changelog has the correct distribution codename
dist_valid() {
  return 0
}

stage_source() {
  :
}

build_src_package() {
  set -e

  pushd .
  echo "Building source package $PACKAGE_NAME"
  cd "$PKG_BUILD_DIR/$PACKAGE_NAME" || exit

  mock -r fedora-36-x86_64 --spec $PACKAGE_NAME.spec --sources . --resultdir $PKG_REPO_PATH

  popd
}

build_bin_package() {
  :
}

publish() {
  # Here we need something equivalent to reprepro...whatever is on the RPM side for generating package repositories
  : 
}

archive_setup_scripts() {
  # Setting up local archive repo for internal dependencies
  :
}

archive_cleanup_scripts() {
  # Cleaning up local archive repo definition
  :
}

# Setup debian repo
setup() {
  :
}
