#!/bin/bash

# This script is not used by automation. It calls into the 
# build functions as automation would to build and publish a
# package. It can be used to test that the build system builds a
# given package without having to commit changes in git.

set -e

REPO_ROOT=$(realpath "$1")
EXTENSION=$2
PACKAGE_NAME=$3
PACKAGE_URL=$4
PACKAGE_REF=$5
CODENAME=$6
PKG_BUILD_DIR="/tmp/pkgbuild"


if [ ! -f "$EXTENSION" ]; then
  echo "Extension $EXTENSION doesn't exist, aborting."
  exit 1
else 
  source $EXTENSION
fi

setup
checkout
update_changelog
if dist_valid; then
  stage_source
  build_src_package
  build_bin_package
  publish
else
  echo "dist codename does not match in package changelog, ignoring $PACKAGE_NAME."
fi