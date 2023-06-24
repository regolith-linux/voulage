#!/bin/bash

# Extension template.  Use this as a starting point to implement a distro/package specific builder

# Update the changelog to specify the target distribution codename
update_changelog() {
  echo ${FUNCNAME[0]}
}

# Determine if the changelog has the correct distribution codename
dist_valid() {
  echo ${FUNCNAME[0]}
}

# Extract the package source
stage_source() {
  echo ${FUNCNAME[0]}
}

# Build the source package
build_src_package() {
  echo ${FUNCNAME[0]}
}

# Build binary packages
build_bin_package() {
  echo ${FUNCNAME[0]}
}

# return 0 if source package already exists in repo, otherwise 1
source_pkg_exists() {
  echo ${FUNCNAME[0]}
}

# Commit source and bin packages to target repository
publish() {
  echo ${FUNCNAME[0]}
}

# Create repo dist file - for new repository
generate_reprepro_dist() {
    echo ${FUNCNAME[0]}
}

# Setup repo layout
setup() {
  echo ${FUNCNAME[0]}

  source_setup_scripts
}
