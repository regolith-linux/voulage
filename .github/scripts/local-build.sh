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
  --extension <path>         Path to extenstion file
  --git-repo-path <path>     Path to repo folder

  --package-name <name>      Package name to build
  --package-url <url>        Git URL to use to clone
  --package-ref <name>       Git ref to use to clone

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

EXTENSION=""         # e.g. /path/to/ext-debian.sh
GIT_REPO_PATH=""     # e.g. /path/to/git/repo/voulage

PKG_BUILD_PATH=""    # it will be: <GIT_REPO_PATH>/pkgbuild
PKG_PUBLISH_PATH=""  # it will be: <GIT_REPO_PATH>/pkgpublish

PACKAGE_NAME=""
PACKAGE_URL=""
PACKAGE_REF=""

DISTRO=""            # ubuntu, debian
CODENAME=""          # e.g. jammy, noble, bookworm, etc
STAGE=""             # experimental, unstable, testing, stable
SUITE="$STAGE"       # experimental, unstable, testing, stable
COMPONENT="main"     # e.g. main, 3_2, 3_1, etc.
ARCH="amd64"

LOCAL_BUILD="true"

while [[ $# -gt 0 ]]; do
  case $1 in
    --extension)     parse_flag "$1" "$2" EXTENSION; shift 2 ;;
    --git-repo-path) parse_flag "$1" "$2" GIT_REPO_PATH; shift 2 ;;

    --package-name)  parse_flag "$1" "$2" PACKAGE_NAME; shift 2 ;;
    --package-url)   parse_flag "$1" "$2" PACKAGE_URL; shift 2 ;;
    --package-ref)   parse_flag "$1" "$2" PACKAGE_REF; shift 2 ;;

    --distro)        parse_flag "$1" "$2" DISTRO; shift 2 ;;
    --codename)      parse_flag "$1" "$2" CODENAME; shift 2 ;;
    --stage)         parse_flag "$1" "$2" STAGE; shift 2 ;;

    -h|--help)       usage; exit 0; ;;
    -*|--*)          echo "Unknown option $1"; exit 1;  ;;
    *)               echo "Unknown command $1"; exit 1; ;;
  esac
done

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

if [ -z "$PACKAGE_NAME" ]; then
  echo "Error: required value for --package-name is missing"
  exit 1
fi
if [ -z "$PACKAGE_URL" ]; then
  echo "Error: required value for --package-url is missing"
  exit 1
fi
if [ -z "$PACKAGE_REF" ]; then
  echo "Error: required value for --package-ref is missing"
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

#### Get extensions

GIT_EXT="$GIT_REPO_PATH/.github/scripts/ext-git.sh"
if [ ! -f "$GIT_EXT" ]; then
  echo "Error: extension $GIT_EXT doesn't exist, aborting."
  exit 1
fi
source $GIT_EXT

if [ ! -f "$EXTENSION" ]; then
  echo "Error: extension $EXTENSION doesn't exist, aborting."
  exit 1
fi
source $EXTENSION

#### Setup files

PKG_BUILD_PATH="$GIT_REPO_PATH/pkgbuild"

if [ ! -d "$PKG_BUILD_PATH" ]; then
  mkdir -p "$PKG_BUILD_PATH"
fi

PKG_PUBLISH_PATH="$GIT_REPO_PATH/pkgpublish"

if [ ! -d "$PKG_PUBLISH_PATH" ]; then
  mkdir -p $PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$STAGE
fi

#### Build package

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
