#!/bin/bash
set -e

# Emit manifest entry line for package
handle_package() {
  local lookup_ref=""
  if [ "$STAGE" == "experimental" ] || [ "$STAGE" == "unstable" ]; then
    if git ls-remote --help | grep "\-\-branches" >/dev/null; then
      lookup_ref="--branches"
    else
      lookup_ref="--heads"
    fi
  else
    lookup_ref="--tags"
  fi

  # Get git hash
  local COMMIT_HASH=$(git ls-remote $lookup_ref $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF | awk '{ print $1}')

  echo "$PACKAGE_NAME $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF $COMMIT_HASH" >> "$NEXT_MANIFEST_FILE"

  echo "Updated manifest $NEXT_MANIFEST_FILE for package $PACKAGE_NAME"
}

# Traverse each package in the model and call handle_package
traverse_package_model() {
  echo "::group::Updating next manifest file"
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
  echo "::endgroup::"
}

# Generate a json file from a root and any additions in each level of the stage tree
merge_models() {
  echo "::group::Merging model files"
  if [ ! -f "$ROOT_MODEL_PATH" ]; then
    echo -e "\033[0;31mInvalid root model path: $ROOT_MODEL_PATH\033[0m"
    exit 1
  fi

  if [ ! -d "$MANIFEST_PATH" ]; then
    mkdir -p "$MANIFEST_PATH"
  fi

  # Copy root model to build dir
  WORKING_ROOT_MODEL="$MANIFEST_PATH/root-model.json"
  cp "$ROOT_MODEL_PATH" "$WORKING_ROOT_MODEL"

  # Optionally merge stage package model
  STAGE_PACKAGE_MODEL="$GIT_REPO_PATH/stage/$STAGE/package-model.json"
  WORKING_STAGE_MODEL="$MANIFEST_PATH/$STAGE-model.json"
  if [ -f "$STAGE_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_ROOT_MODEL" "$STAGE_PACKAGE_MODEL" > "$WORKING_STAGE_MODEL"
  else
    cp "$WORKING_ROOT_MODEL" "$WORKING_STAGE_MODEL"
  fi

  # Optionally merge distro package model
  DISTRO_PACKAGE_MODEL="$GIT_REPO_PATH/stage/$STAGE/$DISTRO/package-model.json"
  WORKING_DISTRO_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-model.json"
  if [ -f "$DISTRO_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_STAGE_MODEL" "$DISTRO_PACKAGE_MODEL" > "$WORKING_DISTRO_MODEL"
  else
    cp "$WORKING_STAGE_MODEL" "$WORKING_DISTRO_MODEL"
  fi

  # Optionally merge codename package model
  CODENAME_PACKAGE_MODEL="$GIT_REPO_PATH/stage/$STAGE/$DISTRO/$CODENAME/package-model.json"
  WORKING_CODENAME_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-$CODENAME-model.json"
  if [ -f "$CODENAME_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_DISTRO_MODEL" "$CODENAME_PACKAGE_MODEL" > "$WORKING_CODENAME_MODEL"
  else
    cp "$WORKING_DISTRO_MODEL" "$WORKING_CODENAME_MODEL"
  fi

  # Optionally merge arch package model
  ARCH_PACKAGE_MODEL="$GIT_REPO_PATH/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/package-model.json"
  WORKING_ARCH_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-$CODENAME-$ARCH-model.json"
  if [ -f "$ARCH_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_CODENAME_MODEL" "$ARCH_PACKAGE_MODEL" > "$WORKING_ARCH_MODEL"
  else
    cp "$WORKING_CODENAME_MODEL" "$WORKING_ARCH_MODEL"
  fi

  PACKAGE_MODEL_FILE="$WORKING_ARCH_MODEL"

  echo -e "\033[0;34mMerged package model:\033[0m"
  cat "$PACKAGE_MODEL_FILE"
  echo "::endgroup::"
}

# Traverse the stage tree and execute any found setup.sh scripts
source_setup_scripts() {
  local setup_script_locations=(
    "$GIT_REPO_PATH/stage/setup.sh"
    "$GIT_REPO_PATH/stage/$STAGE/setup.sh"
    "$GIT_REPO_PATH/stage/$STAGE/$DISTRO/setup.sh"
    "$GIT_REPO_PATH/stage/$STAGE/$DISTRO/$CODENAME/setup.sh"
    "$GIT_REPO_PATH/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/setup.sh"
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
  echo "::group::Package set to build"
  echo -e "$PACKAGE_CHANGES"  
  echo "::endgroup::"

  while IFS= read -r PKG_LINE; do
    # echo "Debug line is $PKG_LINE"

    PACKAGE_NAME=$(echo "$PKG_LINE" | cut -d" " -f1)
    PACKAGE_URL=$(echo "$PKG_LINE" | cut -d" " -f2)
    PACKAGE_REF=$(echo "$PKG_LINE" | cut -d" " -f3)

    echo -e "\033[0;34mBuilding package $PACKAGE_NAME from $PACKAGE_URL with ref $PACKAGE_REF\033[0m"

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

  echo "Completed building packages: $PACKAGE_CHANGES"
}

#### Init input params

usage() {
cat << EOF
Build debian and source packages for given combination of: distro, codename, stage and arch

Usage: $0 [options...] COMMAND

Commands:                                                                                                           
  build    Build the requested debian and source packages
  check    Check the manifests if anything needs to be built

Options:
  --extension <path>         Path to extenstion file (e.g. /path/to/ext-debian.sh)

  --git-repo-path <path>     Path to repo folder (e.g. /path/to/git/repo/voulage)
  --manifests-path <path>    Path to manifests folder (e.g. /path/to/manifests)
  --pkg-build-path <path>    Path to folder to build packages in (e.g. /path/to/packages)
  --pkg-publish-path <path>  Path to folder to publish packages in (e.g. /path/to/publish)

  --distro <name>            The distro to check or build (e.g. ubuntu, debian)
  --codename <name>          The codename to check or build (e.g. jammy, noble, bookworm, etc.)
  --stage <name>             The stage to check or build (e.g. experimental, unstable, testing, backports, release-x_Y) # different release stages from github action point-of-view
  --suite <name>             The suite to check or build (e.g. experimental, unstable, testing, backports, stable)      # corresponding value from published arcvhies point-of-view
  --component <name>         The component to check or build (e.g. main, 3_2, 3_1, etc.)
  --arch <name>              The arch to check or build (e.g. amd64, arm64)

  --help                     Show this message

Note: all the options are required when using $0
EOF
}

parse_flag() {
  declare -n argument=$3

  if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
    argument=$2
    return
  fi

  echo "Error: argument for $1 is missing" >&2
  exit 1
}

MODE=""              # build, check
EXTENSION=""         # e.g. /path/to/ext-debian.sh

GIT_REPO_PATH=""     # e.g. /path/to/git/repo/voulage
MANIFEST_PATH=""     # e.g. /path/to/manifests
PKG_BUILD_PATH=""    # e.g. /path/to/packages
PKG_PUBLISH_PATH=""  # e.g. /path/to/publish

DISTRO=""            # ubuntu, debian
CODENAME=""          # e.g. jammy, noble, bookworm, etc
STAGE=""             # experimental, unstable, testing, backports, release-x_y (different release stages from github action point-of-view)
SUITE=""             # experimental, unstable, testing, backports, stable      (corresponding value from published arcvhies point-of-view)
COMPONENT=""         # e.g. main, 3.2, 3.1, etc.
ARCH=""              # amd64, arm64

LOCAL_BUILD="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    build|check)         MODE="$1"; shift; ;;
    --extension)         parse_flag "$1" "$2" EXTENSION; shift 2 ;;

    --git-repo-path)     parse_flag "$1" "$2" GIT_REPO_PATH; shift 2 ;;
    --manifest-path)     parse_flag "$1" "$2" MANIFEST_PATH; shift 2 ;;
    --pkg-build-path)    parse_flag "$1" "$2" PKG_BUILD_PATH; shift 2 ;;
    --pkg-publish-path)  parse_flag "$1" "$2" PKG_PUBLISH_PATH; shift 2 ;;

    --distro)            parse_flag "$1" "$2" DISTRO; shift 2 ;;
    --codename)          parse_flag "$1" "$2" CODENAME; shift 2 ;;
    --stage)             parse_flag "$1" "$2" STAGE; shift 2 ;;
    --suite)             parse_flag "$1" "$2" SUITE; shift 2 ;;
    --component)         parse_flag "$1" "$2" COMPONENT; shift 2 ;;
    --arch)              parse_flag "$1" "$2" ARCH; shift 2 ;;

    -h|--help)           usage; exit 0; ;;
    -*|--*)              echo "Unknown option $1"; exit 1;  ;;
    *)                   echo "Unknown command $1"; exit 1; ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Error: command is missing"
  exit 1
fi
if [ -z "$EXTENSION" ]; then
  echo "Error: required value for --extension is missing"
  exit 1
fi

if [ -z "$GIT_REPO_PATH" ]; then
  echo "Error: required value for --git-repo-path is missing"
  exit 1
else
  GIT_REPO_PATH=$(realpath "$GIT_REPO_PATH")
fi
if [ -z "$MANIFEST_PATH" ]; then
  echo "Error: required value for --manifest-path is missing"
  exit 1
fi
if [ -z "$PKG_BUILD_PATH" ]; then
  echo "Error: required value for --pkg-build-path is missing"
  exit 1
fi
if [ -z "$PKG_PUBLISH_PATH" ]; then
  echo "Error: required value for --pkg-publish-path is missing"
  exit 1
fi

if [ -z "$DISTRO" ]; then
  echo "Error: required value for --distro is missing"
  exit 1
fi
if [ -z "$CODENAME" ]; then
  echo "Error: required value for --codename is missing"
  exit 1
fi
if [ -z "$STAGE" ]; then
  echo "Error: required value for --stage is missing"
  exit 1
fi
if [ -z "$SUITE" ]; then
  echo "Error: required value for --suite is missing"
  exit 1
fi
if [ -z "$COMPONENT" ]; then
  echo "Error: required value for --component is missing"
  exit 1
fi
if [ -z "$ARCH" ]; then
  echo "Error: required value for --arch is missing"
  exit 1
fi

#### Get extensions

GIT_EXT="$GIT_REPO_PATH/.github/scripts/ext-git.sh"
if [ ! -f "$GIT_EXT" ]; then
  echo "Error: extension $GIT_EXT doesn't exist, aborting."
  exit 1
else 
  source $GIT_EXT
fi

if [ ! -f "$EXTENSION" ]; then
  echo "Error: extension $EXTENSION doesn't exist, aborting."
  exit 1
else 
  source $EXTENSION
fi

#### Init globals

ROOT_MODEL_PATH="$GIT_REPO_PATH/stage/package-model.json"

#### Setup files

if [ -d "$PKG_BUILD_PATH" ]; then
  echo -e "\033[0;34mDeleting pre-existing package build dir $PKG_BUILD_PATH\033[0m"
  rm -Rf "$PKG_BUILD_PATH"
fi

if [ -d "$PKG_PUBLISH_PATH" ]; then
  echo -e "\033[0;34mDeleting pre-existing package publish dir $PKG_PUBLISH_PATH\033[0m"
  rm -Rf "$PKG_PUBLISH_PATH"
fi

if [ ! -d "$MANIFEST_PATH" ]; then
  mkdir -p $MANIFEST_PATH
fi

if [ ! -d "$PKG_PUBLISH_PATH" ]; then
  mkdir -p $PKG_PUBLISH_PATH
fi

#### Generate Manifest from package model tree and git repo state

PREV_MANIFEST_FILE="$MANIFEST_PATH/manifest.txt"
NEXT_MANIFEST_FILE="$MANIFEST_PATH/next-manifest.txt"

# Create prev manifest if doesn't exist (first run)
if [ ! -f "$PREV_MANIFEST_FILE" ]; then
  touch "$PREV_MANIFEST_FILE"
fi

# Delete pre-existing manifest before generating new
if [ -f "$NEXT_MANIFEST_FILE" ]; then
  mv "$NEXT_MANIFEST_FILE" "$MANIFEST_PATH/prev-manifest.txt"
  echo -e "\033[0;34mMoved pre-existing manifest file $NEXT_MANIFEST_FILE to $MANIFEST_PATH/prev-manifest.txt\033[0m"
fi

# Merge models across stage, distro, codename, arch
merge_models

# Iterate over each package in the model and call handle_package
traverse_package_model

#### Find packages that need to be built
echo "::group::Looking for changed package"
echo -e "\033[0;34mDiffing $PREV_MANIFEST_FILE $NEXT_MANIFEST_FILE\033[0m"
PACKAGE_CHANGES=$(diff "$PREV_MANIFEST_FILE" "$NEXT_MANIFEST_FILE" | grep '^[>][^>]' | cut -c3- | uniq | sort)
echo "$PACKAGE_CHANGES"
echo "::endgroup::"

if [ -z "$PACKAGE_CHANGES" ]; then
  echo "No package changes found, exiting."
  exit 0
fi

if [ "$MODE" == "build" ]; then
  #### Build packages

  setup
  build_packages

  #### Cleanup

  archive_cleanup_scripts

  rm "$PREV_MANIFEST_FILE"
  mv "$NEXT_MANIFEST_FILE" "$PREV_MANIFEST_FILE"
else
  echo "$PACKAGE_CHANGES"
fi
