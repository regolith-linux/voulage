#!/bin/bash

set -e

print_banner() {
    echo "***********************************************************"
    echo "** $1"
    echo "***********************************************************"
}

handle_package() {
    echo "${packageModel[source]}"
}

traverse_package_model() {
    jq -rc 'delpaths([path(.[][]| select(.==null))]) | .packages | keys | .[]' < "$PACKAGE_MODEL_FILE" | while IFS='' read -r package; do
        # Set the package name and model desc
        packageModel["name"]="$package"    
        packageModel["modelDescription"]=$(jq -r ".description.title" < "$PACKAGE_MODEL_FILE" )
        # Set all kvps on the associated object
        while IFS== read -r key value; do
            packageModel["$key"]="$value"
        done < <( jq -r ".packages.\"$package\" | to_entries | .[] | .key + \"=\" + .value" < "$PACKAGE_MODEL_FILE" )

        # If a package filter was specified, match filter.
        if [[ -n "$PACKAGE_FILTER" && "$PACKAGE_FILTER" != "${packageModel[name]}" ]]; then
            continue
        fi

        # Apply functions to package model
        print_banner "handle_package(${packageModel[name]})"
        handle_package
    done
}

REPO_ROOT=$(realpath "$1")
STAGE=$2
DISTRO=$3
CODENAME=$4
ARCH=$5
BUILD_DIR=$6
ROOT_MODEL_PATH="$REPO_ROOT/stage/package-model.json"

if [ ! -f "$ROOT_MODEL_PATH" ]; then
  echo "Invalid root model path: $ROOT_MODEL_PATH"
  exit 1
fi

if [ ! -d "$BUILD_DIR" ]; then
  mkdir -p "$BUILD_DIR"
fi

# Copy root model to build dir
WORKING_ROOT_MODEL="$BUILD_DIR/root-model.json"
cp "$ROOT_MODEL_PATH" "$WORKING_ROOT_MODEL"

# Optionally merge stage package model
STAGE_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/package-model.json"
WORKING_STAGE_MODEL="$BUILD_DIR/$STAGE-model.json"
if [ -f "$STAGE_PACKAGE_MODEL" ]; then
  jq -s '.[0] * .[1]' "$WORKING_ROOT_MODEL" "$STAGE_PACKAGE_MODEL" > "$WORKING_STAGE_MODEL"
else 
  cp "$WORKING_ROOT_MODEL" "$WORKING_STAGE_MODEL"
fi

# Optionally merge distro package model
DISTRO_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/$DISTRO/package-model.json"
WORKING_DISTRO_MODEL="$BUILD_DIR/$STAGE-$DISTRO-model.json"
if [ -f "$DISTRO_PACKAGE_MODEL" ]; then
  jq -s '.[0] * .[1]' "$WORKING_STAGE_MODEL" "$DISTRO_PACKAGE_MODEL" > "$WORKING_DISTRO_MODEL"
else 
  cp "$WORKING_STAGE_MODEL" "$WORKING_DISTRO_MODEL"
fi

# Optionally merge codename package model
CODENAME_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/package-model.json"
WORKING_CODENAME_MODEL="$BUILD_DIR/$STAGE-$DISTRO-$CODENAME-model.json"
if [ -f "$CODENAME_PACKAGE_MODEL" ]; then
  jq -s '.[0] * .[1]' "$WORKING_DISTRO_MODEL" "$CODENAME_PACKAGE_MODEL" > "$WORKING_CODENAME_MODEL"
else 
  cp "$WORKING_DISTRO_MODEL" "$WORKING_CODENAME_MODEL"
fi

# Optionally merge arch package model
ARCH_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/package-model.json"
WORKING_ARCH_MODEL="$BUILD_DIR/$STAGE-$DISTRO-$CODENAME-$ARCH-model.json"
if [ -f "$ARCH_PACKAGE_MODEL" ]; then
  jq -s '.[0] * .[1]' "$WORKING_CODENAME_MODEL" "$ARCH_PACKAGE_MODEL" > "$WORKING_ARCH_MODEL"
else 
  cp "$WORKING_CODENAME_MODEL" "$WORKING_ARCH_MODEL"
fi

PACKAGE_MODEL_FILE="$WORKING_ARCH_MODEL"

traverse_package_model
