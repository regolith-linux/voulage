#!/bin/bash

set -e
set -o errexit
# Extension for Debian repo and pacakge support

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
  # Here we need something equivelent to reprepro...whatever is on the RPM side for generating package repositories
  : 
}

# Setup debian repo
setup() {
  :
}
