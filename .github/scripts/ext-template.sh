#!/bin/bash

# Extension template.  Use this as a starting point to implement a distro/package specific builder

# Update the changelog to specify the target distribution codename
update_changelog() {
  echo todo
}

# Determine if the changelog has the correct distribution codename
dist_valid() {
  echo todo
}

# Extract the package source
stage_source() {
  echo todo
}

# Build the source package
build_src_package() {
  echo todo
}

# Build binary packages
build_bin_package() {
  echo todo
}

# return 0 if source package already exists in repo, otherwise 1
source_pkg_exists() {
  echo todo
}

# Commit source and bin packages to target repository
publish() {
  echo todo
}

archive_setup_scripts() {
  echo todo
}

archive_cleanup_scripts() {
  echo todo
}

# Setup repo layout
setup() {
  echo todo

  source_setup_scripts
  archive_setup_scripts
}
