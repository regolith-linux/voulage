#!/bin/bash
set -e

# This script is used to create new tags from existing tags on source refs from the package model
# Usage: 
#         tag-cp.sh <repo root path> <package model stage id> <source ref> <target tag id> [package filter]

handle_package() {
  echo
  echo "# --- $PACKAGE_NAME $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF $DST_TAG"
  PKG_WORK_DIR=$PKG_STAGE_ROOT/$PACKAGE_NAME

  mkdir -p $PKG_WORK_DIR

  pushd $PKG_WORK_DIR > /dev/null

  if [ -d "$PACKAGE_NAME" ]; then  
    pushd "$PACKAGE_NAME" > /dev/null
    git checkout --quiet "$PACKAGE_SOURCE_REF" > /dev/null || { echo "# checkout of $PACAKGE_SOURCE_URL ref $PACKAGE_SOURCE_REF failed" ; popd > /dev/null ; popd > /dev/null ; return ; }
    echo "# checked out $PACKAGE_SOURCE_REF ref $PACKAGE_SOURCE_REF"
  else
    git clone --quiet --no-checkout "$PACAKGE_SOURCE_URL" -b "$PACKAGE_SOURCE_REF" "$PACKAGE_NAME" > /dev/null
    pushd "$PACKAGE_NAME" > /dev/null
    echo "# cloned $PACKAGE_SOURCE_REF ref $PACKAGE_SOURCE_REF"
  fi

  if [ $(git tag -l "$PACKAGE_SOURCE_REF") ]; then
    if [ $(git tag -l "$DST_TAG") ]; then
      echo "# ignoring, $DST_TAG already exists for $PACKAGE_NAME"
    else
      echo "# Creating new tag $DST_TAG for $PACKAGE_NAME"
      # echo "git tag $DST_TAG"
      git tag $DST_TAG
      echo "# Pushing tag $DST_TAG for $PACKAGE_NAME"
      # echo "git push origin $DST_TAG"
      git push origin $DST_TAG
    fi
  else
      echo "# ignoring, $PACKAGE_NAME does not have source ref $PACKAGE_SOURCE_REF"
  fi
  
  popd > /dev/null
  popd > /dev/null
}

# Traverse each package in the model and call handle_package
process_model() {
    jq -rc 'delpaths([path(.[][]| select(.==null))]) | .packages | keys | .[]' < "$PACKAGE_MODEL_FILE" | while IFS='' read -r package; do
        # Set the package name and model desc
        PACKAGE_NAME="$package"

        # If a package filter was specified, match filter.
        if [[ -n "$PACKAGE_FILTER" && "$PACKAGE_FILTER" != "$PACKAGE_NAME" ]]; then
            continue
        fi

        PACAKGE_SOURCE_URL=$(jq -r ".packages.\"$package\".source" < "$PACKAGE_MODEL_FILE")
        PACKAGE_SOURCE_REF=$(jq -r ".packages.\"$package\".ref" < "$PACKAGE_MODEL_FILE")
        
        if [ "$PACKAGE_SOURCE_REF" == "$SRC_TAG" ]; then
          # Apply functions to package model
          handle_package
        else
          echo "# --- $PACKAGE_NAME $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF $DST_TAG"
          echo "# ignoring $PACKAGE_NAME, does not match $SRC_TAG"
        fi
    done
}

# Generate a json file from a root and any additions in each level of the stage tree
walk_package_models() {
  if [ ! -f "$ROOT_MODEL_PATH" ]; then
    echo "Invalid root model path: $ROOT_MODEL_PATH"
    exit 1
  fi

  # Copy root model to build dir
  WORKING_ROOT_MODEL="/tmp/root-model.json"
  cp "$ROOT_MODEL_PATH" "$WORKING_ROOT_MODEL"

  STAGE_PATH=$REPO_ROOT/stage/$STAGE

  STAGE_PACKAGE_MODEL="$STAGE_PATH/package-model.json"
  WORKING_STAGE_MODEL="/tmp/$STAGE-model.json"
  if [ -f "$STAGE_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_ROOT_MODEL" "$STAGE_PACKAGE_MODEL" > "$WORKING_STAGE_MODEL"
  else
    cp "$WORKING_ROOT_MODEL" "$WORKING_STAGE_MODEL"
  fi

  for DISTRO_PATH in $STAGE_PATH/*/; do
    DISTRO=$(basename $DISTRO_PATH)
    DISTRO_PACKAGE_MODEL="$DISTRO_PATH/package-model.json"
    WORKING_DISTRO_MODEL="/tmp/$STAGE-$DISTRO-model.json"
    if [ -f "$DISTRO_PACKAGE_MODEL" ]; then
      jq -s '.[0] * .[1]' "$WORKING_STAGE_MODEL" "$DISTRO_PACKAGE_MODEL" > "$WORKING_DISTRO_MODEL"
    else
      cp "$WORKING_STAGE_MODEL" "$WORKING_DISTRO_MODEL"
    fi

    for CODENAME_PATH in $DISTRO_PATH/*/; do
      CODENAME=$(basename $CODENAME_PATH)
      CODENAME_PACKAGE_MODEL="$CODENAME_PATH/package-model.json"
      WORKING_CODENAME_MODEL="/tmp/$STAGE-$DISTRO-$CODENAME-model.json"
      if [ -f "$CODENAME_PACKAGE_MODEL" ]; then
        jq -s '.[0] * .[1]' "$WORKING_DISTRO_MODEL" "$CODENAME_PACKAGE_MODEL" > "$WORKING_CODENAME_MODEL"
      else
        cp "$WORKING_DISTRO_MODEL" "$WORKING_CODENAME_MODEL"
      fi

      # ignore arch, will need to update if need to refactor 
      # if some packages only exist in a given arch

      PACKAGE_MODEL_FILE="$WORKING_CODENAME_MODEL"
      process_model
    done
  done
}

#### Init input params
#### USAGE:
REPO_ROOT=$(realpath "$1")
STAGE=$2   # this tool only works within a single stage
SRC_TAG=$3 # Filter only these source refs
DST_TAG=$4 # the name of the new tag
PACKAGE_FILTER=$5 # Filter only package name (optional)

#### Init globals
ROOT_MODEL_PATH="$REPO_ROOT/stage/$STAGE/package-model.json"
PKG_STAGE_ROOT="/tmp/voulage-stage-tool"

# if [ -d "$PKG_STAGE_ROOT" ]; then
#   rm -Rf "$PKG_STAGE_ROOT"
# fi

# Walk across stage, distro, codename, arch
walk_package_models
