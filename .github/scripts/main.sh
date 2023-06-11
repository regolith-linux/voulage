#!/bin/bash
set -e

# Emit manifest entry line for package
handle_package() {
    # Get git hash
    local COMMIT_HASH=$(git ls-remote $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF | awk '{ print $1}')

    echo "$PACKAGE_NAME $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF $COMMIT_HASH" >> "$NEXT_MANIFEST_FILE"

    echo "Updated manifest $NEXT_MANIFEST_FILE for package $PACKAGE_NAME"
}

# Traverse each package in the model and call handle_package
traverse_package_model() {
    jq -rc 'delpaths([path(.[][]| select(.==null))]) | .packages | keys | .[]' < "$PACKAGE_MODEL_FILE" | while IFS='' read -r package; do
        # Set the package name and model desc
        PACKAGE_NAME="$package"

        # If a package filter was specified, match filter.
        if [[ -n "$PACKAGE_FILTER" && "$PACKAGE_FILTER" != "$PACKAGE_NAME" ]]; then
            continue
        fi

        PACAKGE_SOURCE_URL=$(jq -r ".packages.\"$package\".source" < "$PACKAGE_MODEL_FILE")
        PACKAGE_SOURCE_REF=$(jq -r ".packages.\"$package\".ref" < "$PACKAGE_MODEL_FILE")

        # Apply functions to package model
        handle_package
    done
}

# Generate a json file from a root and any additions in each level of the stage tree
merge_models() {
  if [ ! -f "$ROOT_MODEL_PATH" ]; then
    echo "Invalid root model path: $ROOT_MODEL_PATH"
    exit 1
  fi

  if [ ! -d "$MANIFEST_PATH" ]; then
    mkdir -p "$MANIFEST_PATH"
  fi

  # Copy root model to build dir
  WORKING_ROOT_MODEL="$MANIFEST_PATH/root-model.json"
  cp "$ROOT_MODEL_PATH" "$WORKING_ROOT_MODEL"

  # Optionally merge stage package model
  STAGE_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/package-model.json"
  WORKING_STAGE_MODEL="$MANIFEST_PATH/$STAGE-model.json"
  if [ -f "$STAGE_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_ROOT_MODEL" "$STAGE_PACKAGE_MODEL" > "$WORKING_STAGE_MODEL"
  else
    cp "$WORKING_ROOT_MODEL" "$WORKING_STAGE_MODEL"
  fi

  # Optionally merge distro package model
  DISTRO_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/$DISTRO/package-model.json"
  WORKING_DISTRO_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-model.json"
  if [ -f "$DISTRO_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_STAGE_MODEL" "$DISTRO_PACKAGE_MODEL" > "$WORKING_DISTRO_MODEL"
  else
    cp "$WORKING_STAGE_MODEL" "$WORKING_DISTRO_MODEL"
  fi

  # Optionally merge codename package model
  CODENAME_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/package-model.json"
  WORKING_CODENAME_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-$CODENAME-model.json"
  if [ -f "$CODENAME_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_DISTRO_MODEL" "$CODENAME_PACKAGE_MODEL" > "$WORKING_CODENAME_MODEL"
  else
    cp "$WORKING_DISTRO_MODEL" "$WORKING_CODENAME_MODEL"
  fi

  # Optionally merge arch package model
  ARCH_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/package-model.json"
  WORKING_ARCH_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-$CODENAME-$ARCH-model.json"
  if [ -f "$ARCH_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_CODENAME_MODEL" "$ARCH_PACKAGE_MODEL" > "$WORKING_ARCH_MODEL"
  else
    cp "$WORKING_CODENAME_MODEL" "$WORKING_ARCH_MODEL"
  fi

  PACKAGE_MODEL_FILE="$WORKING_ARCH_MODEL"

  echo "Merged package model: "
  cat "$PACKAGE_MODEL_FILE"
}

# Traverse the stage tree and execute any found setup.sh scripts
source_setup_scripts() {
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
      source "$setup_file"
    fi
  done
}

build_packages() {
  echo -e "Package set to build: $PACKAGE_CHANGES"  
  set -x

  while IFS= read -r PKG_LINE; do
    PACKAGE_NAME=$(echo "$PKG_LINE" | cut -d" " -f1)
    PACKAGE_URL=$(echo "$PKG_LINE" | cut -d" " -f2)
    PACKAGE_REF=$(echo "$PKG_LINE" | cut -d" " -f3)

    echo "Finding package $PACKAGE_NAME from $PACKAGE_URL with ref $PACKAGE_REF"
  done <<< "$PACKAGE_CHANGES"

  while IFS= read -r PKG_LINE; do
    PACKAGE_NAME=$(echo "$PKG_LINE" | cut -d" " -f1)
    PACKAGE_URL=$(echo "$PKG_LINE" | cut -d" " -f2)
    PACKAGE_REF=$(echo "$PKG_LINE" | cut -d" " -f3)

    echo "Building package $PACKAGE_NAME from $PACKAGE_URL with ref $PACKAGE_REF"

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
  done <<< "$PACKAGE_CHANGES"

  echo "Completed building packages"
}

#### Init input params

REPO_ROOT=$(realpath "$1")
EXTENSION=$2
STAGE=$3
DISTRO=$4
CODENAME=$5
ARCH=$6
PACKAGE_REPO_URL=$7
APT_KEY=$8
MODE=$9
MANIFEST_PATH=${10}
PKG_REPO_PATH=${11}
PKG_BUILD_DIR=${12}


GIT_EXT="$REPO_ROOT/.github/scripts/ext-git.sh"
if [ ! -f "$GIT_EXT" ]; then
  echo "Extension $GIT_EXT doesn't exist, aborting."
  exit 1
else 
  source $GIT_EXT
fi

if [ ! -f "$EXTENSION" ]; then
  echo "Extension $EXTENSION doesn't exist, aborting."
  exit 1
else 
  source $EXTENSION
fi

#### Init globals

ROOT_MODEL_PATH="$REPO_ROOT/stage/package-model.json"

#### Setup files

if [ -d "$MANIFEST_PATH" ]; then
  echo "Deleting pre-existing manifest dir $MANIFEST_PATH"
  rm -Rf "$MANIFEST_PATH"
fi

if [ -d "$PKG_BUILD_DIR" ]; then
  echo "Deleting pre-existing package build dir $PKG_BUILD_DIR"
  rm -Rf "$PKG_BUILD_DIR"
fi

if [ ! -d "$MANIFEST_PATH" ]; then
  mkdir -p $MANIFEST_PATH
fi

if [ ! -d "$PKG_REPO_PATH" ]; then
  mkdir -p $PKG_REPO_PATH
fi

#### Generate Manifest from package model tree and git repo state

PREV_MANIFEST_FILE="$PKG_REPO_PATH/manifest.txt"
NEXT_MANIFEST_FILE="$MANIFEST_PATH/next-manifest.txt"

# Create prev manifest if doesn't exist (first run)
if [ ! -f "$PREV_MANIFEST_FILE" ]; then
  touch "$PREV_MANIFEST_FILE"
fi

# Delete pre-existing manifest before generating new
if [ -f "$NEXT_MANIFEST_FILE" ]; then
  mv "$NEXT_MANIFEST_FILE" "$MANIFEST_PATH/prev-manifest.txt"
  echo "Moved pre-existing manifest file $NEXT_MANIFEST_FILE to $MANIFEST_PATH/prev-manifest.txt"
fi

# Merge models across stage, distro, codename, arch
merge_models
# Iterate over each package in the model and call handle_package
traverse_package_model

#### Find packages that need to be built
echo Diffing "$PREV_MANIFEST_FILE" "$NEXT_MANIFEST_FILE"
PACKAGE_CHANGES=$(diff "$PREV_MANIFEST_FILE" "$NEXT_MANIFEST_FILE" | grep '^[>][^>]' | cut -c3- | uniq | sort)
echo "Package diff: $PACKAGE_CHANGES"

if [ -z "$PACKAGE_CHANGES" ]; then
  echo "No package changes found, exiting."
  exit 0
fi

if [ "$MODE" == "build" ]; then
  #### Build packages

  setup
  build_packages

  #### Cleanup

  rm "$PREV_MANIFEST_FILE"
  mv "$NEXT_MANIFEST_FILE" "$PREV_MANIFEST_FILE"
else
  echo "$PACKAGE_CHANGES"
fi
