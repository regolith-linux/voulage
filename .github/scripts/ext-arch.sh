#!/bin/bash

# Extension template.  Use this as a starting point to implement a distro/package specific builder

# Update the changelog to specify the target distribution codename
update_changelog() {
  echo "function called: ${FUNCNAME[0]}"
}

# Determine if the changelog has the correct distribution codename
dist_valid() {
  echo "function called: ${FUNCNAME[0]}"
}

# Extract the package source
stage_source() {
  echo "function called: ${FUNCNAME[0]}"
}

# Build the source package
build_src_package() {
  set -e
  echo "function called: ${FUNCNAME[0]}"

  echo "Package Name: $PACKAGE_NAME"
  echo "Package Build Dir: $PKG_BUILD_DIR"
  echo "Target Repo Dir: $PKG_REPO_PATH"
  echo "Manifest path: $MANIFEST_PATH"
  echo ""
  echo "Distro: $DISTRO"
  echo "Distro Version: $CODENAME"
  echo "Target architecture: $ARCH"
  echo ""
  echo "Contents of package source:"
  ls -l $PKG_BUILD_DIR/$PACKAGE_NAME
  if [ -f $PKG_BUILD_DIR/$PACKAGE_NAME/debian/control ]; then 
    echo ""
    echo "Package metadata (dependencies in deb form, etc):"
    cat $PKG_BUILD_DIR/$PACKAGE_NAME/debian/control
  fi
}

# Build binary packages
build_bin_package() {
  echo "function called: ${FUNCNAME[0]}"
}

# return 0 if source package already exists in repo, otherwise 1
source_pkg_exists() {
  echo "function called: ${FUNCNAME[0]}"
}

# Commit source and bin packages to target repository
publish() {
  echo "function called: ${FUNCNAME[0]}"
}

# Create repo dist file - for new repository
generate_reprepro_dist() {
    echo "function called: ${FUNCNAME[0]}"
}

# Setup repo layout
setup() {
  echo "function called: ${FUNCNAME[0]}"

  source_setup_scripts
}
