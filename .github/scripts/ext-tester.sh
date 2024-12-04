#!/bin/bash

# Extension template.  Use this as a starting point to implement a distro/package specific builder

# Update the changelog to specify the target distribution codename
update_changelog() {
  echo "Updating package ${PKG_BUILD_DIR:?}/$PACKAGE_NAME changelog"
}

# Determine if the changelog has the correct distribution codename
dist_valid() {
  echo "Verifying package $PACKAGE_NAME is valid"
}

# Extract the package source
stage_source() {
  echo "Staging $PACKAGE_NAME source in $PKG_BUILD_DIR"
}

# Build the source package
build_src_package() {
  echo "Building $PACKAGE_NAME source package"
}

# Build binary packages
build_bin_package() {
  echo "Building $PACKAGE_NAME binary package"
}

# return 0 if source package already exists in repo, otherwise 1
source_pkg_exists() {
  echo "Checking if $PACKAGE_NAME source package already exists"
}

# Commit source and bin packages to target repository
publish() {
  echo "Publishing $PACKAGE_NAME to repo"
}

archive_setup_scripts() {
  echo "Setting up local archive repo for internal dependencies"
}

archive_cleanup_scripts() {
  echo "Cleaning up local archive repo definition"
}

# Setup repo layout
setup() {
  echo "Setting up $PKG_REPO_PATH"
  
  source_setup_scripts
  archive_setup_scripts
}
