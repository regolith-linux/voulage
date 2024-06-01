#!/bin/bash
#
# This script creates tags in repos based on a truth table contained within.
# Usage of this script is for tagging repos with a tag scheme suitable for
# usage in package models that is obvious and intuitive.
# See handle_package() function for specific mappings.
#
set -e

tag_package() {
  TAG=$1
  if [ $(git tag -l "$TAG") ]; then
    : # echo "# ignoring, $TAG already exists for $PACKAGE_NAME"
  else
    # echo "# Creating new tag $TAG for $PACKAGE_NAME"
    # echo "~~ git tag $TAG"
    # git tag $TAG
    # echo "# Pushing tag $TAG for $PACKAGE_NAME"
    # echo "~~ git push origin $TAG"
    # git push origin $TAG
    if [ "$TAG" == "$DEFAULT_DEST_TAG" ]; then
      : # echo "$STAGE-$DISTRO-$CODENAME $PACKAGE_NAME $TAG DEFAULT"
    else
      echo "$STAGE-$DISTRO-$CODENAME $PACKAGE_NAME $TAG SPECIAL ($PACKAGE_SOURCE_REF)"
    fi
  fi
}

# This script is used to create new tags from existing tags on source refs from the package model
# Usage: 
#   tag-cp.sh <repo root> <source stage> <baseline tag> [package filter]
# Example:
#   .github/scripts/tag-stage.sh . unstable r3_2

handle_package() {
  # echo "# --- $PACKAGE_NAME $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF $STAGE-$DISTRO-$CODENAME"
  PKG_WORK_DIR=$PKG_STAGE_ROOT/$PACKAGE_NAME

  mkdir -p $PKG_WORK_DIR
  
  pushd $PKG_WORK_DIR > /dev/null

  if [ -d "$PACKAGE_NAME" ]; then  
    pushd "$PACKAGE_NAME" > /dev/null
    git fetch
    git checkout --quiet "$PACKAGE_SOURCE_REF" > /dev/null || { echo "# checkout of $PACAKGE_SOURCE_URL ref $PACKAGE_SOURCE_REF failed" ; popd > /dev/null ; popd > /dev/null ; return ; }
    # echo "# checked out $PACKAGE_SOURCE_REF ref $PACKAGE_SOURCE_REF"
  else
    git clone --quiet --no-checkout "$PACAKGE_SOURCE_URL" -b "$PACKAGE_SOURCE_REF" "$PACKAGE_NAME" > /dev/null
    pushd "$PACKAGE_NAME" > /dev/null
    # echo "# cloned $PACKAGE_SOURCE_REF ref $PACKAGE_SOURCE_REF"
  fi


  # Here lies a mapping for how all the various branch naming strategies over the years
  # collapse into tags of this form:
  # r<major version>[_<non-zero minor version>[-beta<1-based index>[-VARIANT]]]  (ex: "r4", "r3_1", "r3_2-beta7")
  # where "VARIANT" is of the form: <distro>-<codename> OR <library>-<library version>  (ex: "ubuntu-jammy", "gnome-43")
  # complete examples: "r4-ubuntu-jammy", "r3_1-beta2-debian-bullseye"
  if [ "$PACKAGE_SOURCE_REF" == "main" ]; then
    tag_package "$DEFAULT_DEST_TAG"
  elif [ "$PACKAGE_SOURCE_REF" == "master" ]; then
    tag_package "$DEFAULT_DEST_TAG"
  elif [[ "$PACKAGE_SOURCE_REF" == "ubuntu-jammy" || "$PACKAGE_SOURCE_REF" == "ubuntu/jammy" ]]; then
    tag_package "$DEFAULT_DEST_TAG-ubuntu-jammy"
  elif [[ "$PACKAGE_SOURCE_REF" == "ubuntu-focal" || "$PACKAGE_SOURCE_REF" == "ubuntu/focal" ]]; then
    tag_package "$DEFAULT_DEST_TAG-ubuntu-focal"
  elif [ "$PACKAGE_SOURCE_REF" == "debian-bullseye" ]; then
    tag_package "$DEFAULT_DEST_TAG-debian-bullseye"
  elif [[ "$PACKAGE_SOURCE_REF" == "debian-testing" || "$PACKAGE_SOURCE_REF" == "debian/testing" ]]; then
    tag_package "$DEFAULT_DEST_TAG-debian-testing"
  elif [[ "$PACKAGE_SOURCE_REF" == "debian-bookworm" || "$PACKAGE_SOURCE_REF" == "debian-bookworm-compat" ]]; then
    tag_package "$DEFAULT_DEST_TAG-debian-bookworm"
  elif [ "$PACKAGE_SOURCE_REF" == "regolith/1%43.0-1" ]; then
    tag_package "$DEFAULT_DEST_TAG-gnome-43"
  elif [ "$PACKAGE_SOURCE_REF" == "regolith/46" ]; then
    tag_package "$DEFAULT_DEST_TAG-gnome-46"
  elif [[ "$PACKAGE_SOURCE_REF" == "debian-v9" && "$PACKAGE_NAME" == "picom" ]]; then
    tag_package "$DEFAULT_DEST_TAG"
  elif [[ "$PACKAGE_SOURCE_REF" == "debian" && "$PACKAGE_NAME" == "whitesur-gtk-theme" ]]; then
    tag_package "$DEFAULT_DEST_TAG"
  elif [[ "$PACKAGE_SOURCE_REF" == "applied/ubuntu/groovy" && "$PACKAGE_NAME" == "xcb-util" ]]; then
    : # this package is exceptional, is not built from a regoolith repo.  cannot push tags.  deprecated.
  elif [[ "$PACKAGE_SOURCE_REF" == "ubuntu/v0.32.1" && "$PACKAGE_NAME" == "i3status-rs" ]]; then
    tag_package "$DEFAULT_DEST_TAG"
  elif [[ "$PACKAGE_SOURCE_REF" == "ubuntu/v0.22.0" && "$PACKAGE_NAME" == "i3status-rs" ]]; then
    tag_package "$DEFAULT_DEST_TAG-ubuntu-jammy"
  elif [[ "$PACKAGE_SOURCE_REF" == "i3cp" && "$PACKAGE_NAME" == "regolith-rofi-config" ]]; then
    tag_package "$DEFAULT_DEST_TAG"
  elif [[ "$PACKAGE_SOURCE_REF" == "packaging/v1.7-regolith" && "$PACKAGE_NAME" == "sway-regolith" ]]; then
    tag_package "$DEFAULT_DEST_TAG-ubuntu-jammy"
  elif [[ "$PACKAGE_SOURCE_REF" == "packaging/v1.8-regolith" && "$PACKAGE_NAME" == "sway-regolith" ]]; then
    tag_package "$DEFAULT_DEST_TAG-debian-testing"
  elif [[ "$PACKAGE_SOURCE_REF" == "packaging/v1.9-regolith" && "$PACKAGE_NAME" == "sway-regolith" ]]; then
    tag_package "$DEFAULT_DEST_TAG"
  elif [[ "$PACKAGE_SOURCE_REF" == "debian" && "$PACKAGE_NAME" == "fonts-nerd-fonts" ]]; then
    tag_package "$DEFAULT_DEST_TAG"
  else
    echo "### Ignoring unhandled variant: $PACKAGE_NAME on $STAGE-$DISTRO-$CODENAME with tag $PACKAGE_SOURCE_REF"
  fi

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
        
        # Apply functions to package model
        handle_package        
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
DEFAULT_DEST_TAG=$3 # base tag to create, w varations. ex: r3_2-beta1
PACKAGE_FILTER=$4 # Filter only package name (optional)

if [[ -z "$STAGE" || -z "$DEFAULT_DEST_TAG" ]]; then
  echo "usage: tag-stage.sh <repo root> <source stage> <baseline tag> [package filter]"
  exit 1
fi

#### Init globals
ROOT_MODEL_PATH="$REPO_ROOT/stage/$STAGE/package-model.json"
PKG_STAGE_ROOT="/tmp/voulage-stage-tool"

# if [ -d "$PKG_STAGE_ROOT" ]; then
#   rm -Rf "$PKG_STAGE_ROOT"
# fi

# Walk across stage, distro, codename, arch
walk_package_models
