#!/bin/bash

set -e

handle_package() {
    local MANIFEST_PATH="$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/manifest.txt"

    # Get git hash
    local COMMIT_HASH=$(git ls-remote $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF | awk '{ print $1}')

    echo "$PACKAGE_NAME $PACKAGE_SOURCE_REF $COMMIT_HASH" >> "$MANIFEST_PATH"
}

compute_package_diff() {
    git diff --diff-filter=AM | grep '^[+|-][^+|-]' | cut -d" " -f1 | cut -c2- | uniq | sort
}

REPO_ROOT=$(realpath "$1")
STAGE=$2
DISTRO=$3
CODENAME=$4
ARCH=$5
BUILD_DIR=$6
ROOT_MODEL_PATH="$REPO_ROOT/stage/package-model.json"

source "$REPO_ROOT/.github/scripts/common.sh"

# Delete pre-existing manifest before generating new 
if [ -f "$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/manifest.txt" ]; then
  rm "$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/manifest.txt"
fi

# Program Start

# Merge models across stage, distro, codename, arch
merge_models
# Iterate over each package in the model and call handle_package
traverse_package_model
