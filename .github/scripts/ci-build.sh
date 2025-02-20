#!/bin/bash
#
# This script is alsot identical to local-build with a big difference
# that ci-build.sh will be used in automation in each package repository.
# It calls into the build functions as automation would to build and publish a
# package.

set -e

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

#### Init input params

usage() {
cat << EOF
Build single deb and source package

Usage: $0 [options...]

Options:
  --package-name <name>      Package name to build
  --extension <path>         Path to extenstion file

  --git-repo-path <path>     Path to repo folder
  --pkg-build-path <path>    Path to folder to build packages in (e.g. /path/to/packages)
  --pkg-publish-path <path>  Path to folder to publish packages in (e.g. /path/to/publish)

  --distro <name>            The distro to check or build
  --codename <name>          The codename to check or build
  --stage <name>             The stage to check or build (e.g. experimental, unstable, testing, release-x_Y) # different release stages from github action point-of-view
  --suite <name>             The suite to check or build (e.g. experimental, unstable, testing, stable)      # corresponding value from published arcvhies point-of-view
  --component <name>         The component to check or build (e.g. main, 3_2, 3_1, etc.)
  --arch <name>              The arch to check or build

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

PACKAGE_NAME=""
EXTENSION=""         # e.g. /path/to/ext-debian.sh

PKG_BUILD_PATH=""
PKG_PUBLISH_PATH=""

DISTRO=""            # ubuntu, debian
CODENAME=""          # e.g. jammy, noble, bookworm, etc
STAGE=""             # experimental, unstable, testing, release-x_y (different release stages from github action point-of-view)
SUITE=""             # experimental, unstable, testing, stable      (corresponding value from published arcvhies point-of-view)
COMPONENT=""         # e.g. main, 3.2, 3.1, etc.
ARCH=""              # amd64, arm64

LOCAL_BUILD=""       # true: only build, false: download source, build and sign, publish

while [[ $# -gt 0 ]]; do
  case $1 in
    --build-only)        parse_flag "$1" "$2" LOCAL_BUILD; shift 2 ;;

    --package-name)      parse_flag "$1" "$2" PACKAGE_NAME; shift 2 ;;
    --extension)         parse_flag "$1" "$2" EXTENSION; shift 2 ;;

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

PWD="$(dirname "$(readlink -f "$0")")"
GIT_REPO_PATH=$(realpath "$(realpath "$PWD")/../../")

if [ -z "$PACKAGE_NAME" ]; then
  echo "Error: required value for --package-name is missing"
  exit 1
fi
if [ -z "$EXTENSION" ]; then
  echo "Error: required value for --extension is missing"
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

GIT_EXT="$PWD/ext-git.sh"
if [ ! -f "$GIT_EXT" ]; then
  echo "Error: extension $GIT_EXT doesn't exist, aborting."
  exit 1
fi
source $GIT_EXT

EXTENSION="$PWD/$EXTENSION"
if [ ! -f "$EXTENSION" ]; then
  echo "Error: extension $EXTENSION doesn't exist, aborting."
  exit 1
fi
source $EXTENSION

#### Setup files

if [ ! -d "$PKG_BUILD_PATH" ]; then
  mkdir -p "$PKG_BUILD_PATH"
fi

if [ ! -d "$PKG_PUBLISH_PATH" ]; then
  mkdir -p $PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$STAGE
fi

#### Build package

setup
update_changelog

if dist_valid; then
  stage_source
  build_src_package
  build_bin_package

  if [ "$LOCAL_BUILD" == "false" ]; then
    publish
  fi
else
  echo -e "\033[0;31mdist codename does not match in package changelog, ignoring $PACKAGE_NAME.\033[0m"
  exit 1
fi
