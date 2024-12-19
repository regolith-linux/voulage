#!/bin/bash

# This script is not used by automation. It calls into the
# build functions as automation would to build and publish a
# package. It can be used to test that the build system builds a
# given package without having to commit changes in git.

set -e

# Unused for local build
source_setup_scripts() {
  echo nop
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
  --arch <name>              The arch to check or build
  --stage <name>             The stage to check or build

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
# STAGE=""             # TODO experimental, unstable, testing, stable
STAGE=""             # experimental, unstable, testing, release-x_y (different release stages from github action point-of-view)
SUITE=""             # experimental, unstable, testing, stable      (corresponding value from published arcvhies point-of-view)
COMPONENT=""         # e.g. main, 3.2, 3.1, etc.
ARCH=""              # amd64, arm64

LOCAL_BUILD="true"

while [[ $# -gt 0 ]]; do
  case $1 in
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
  echo "Error: required value for --suite is missing"
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
  publish
else
  echo "dist codename does not match in package changelog, ignoring $PACKAGE_NAME."
  exit 1
fi
