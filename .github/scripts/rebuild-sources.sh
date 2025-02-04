#!/usr/bin/env bash
#
# Rebuild the source files.
#
# The following files will be rebuilt out of exisiting .orig.tar.gz file which
# is previously repacked without /debian folder in it.
#
# - .dsc
# - .debian.tar.xz
#
# This will ensure one single .orig.tar.gz file can be used for all the
# packages of the same version and same component of different codenames.

rebuild_packages() {
  local distro=$1
  local codename=$2
  local component=$3

  echo -e "\033[0;34mProcessing source packages in:\033[0m"

  echo "Distro   : $distro"
  echo "Codename : $codename"
  echo "Component: $component"

  pushd "$PKG_BUILD_PATH/$distro/$codename/$component" >/dev/null

  for f in $(find . -maxdepth 1 -type f -name "*.orig.tar.gz" | sort); do
    base_name=$(basename $f)

    pkg_full_name=$(echo $base_name | sed 's/.orig.tar.gz//g')
    pkg_name=$(echo $base_name | cut -d"_" -f1)

    # not the provided --only-package
    if [ -n "$ONLY_PACKAGE" ] && [ "$ONLY_PACKAGE" != "$pkg_name" ]; then
      continue
    fi

    echo "::group::Rebuilding $pkg_full_name.orig.tar.gz"

    tmp=$(mktemp -d)
    if [ -z "$tmp" ]; then
      continue
    fi
    if [ ! -d "$tmp" ]; then
      continue
    fi

    if [ ! -f "$pkg_full_name.orig.tar.gz" ]; then
      echo "$pkg_full_name.orig.tar.gz is missing"
      continue
    fi
    if [ ! -f "$pkg_full_name-$codename.debian.tar.xz" ]; then
      echo "$pkg_full_name-$codename.debian.tar.xz is missing"
      continue
    fi

    cp "$pkg_full_name.orig.tar.gz" "$tmp"
    cp "$pkg_full_name-$codename.debian.tar.xz" "$tmp"

    # entering /tmp/tmp.XXXXXXXXXX
    pushd $tmp >/dev/null

    tar -xzf "$pkg_full_name.orig.tar.gz"
    tar -xf "$pkg_full_name-$codename.debian.tar.xz"
    mv "debian/" "$pkg_name"

    if [ -d "$pkg_name" ]; then
      pushd $pkg_name >/dev/null

      sudo apt update
      sudo apt build-dep -y .
      debuild -S -sa

      popd >/dev/null
    fi

    # existing /tmp/tmp.XXXXXXXXXX
    popd >/dev/null

    # copy newly generated .dsc and .debian.tar.xz file back to the repo
    cp $tmp/$pkg_full_name-$codename.dsc .
    cp $tmp/$pkg_full_name-$codename.debian.tar.xz .

    rm -rf $tmp >/dev/null
    echo "::endgroup::"
  done

  popd >/dev/null
}

find_packages() {
  local distro="$1"

  pushd "$PKG_BUILD_PATH" >/dev/null

  for dir in $(find "$distro/" -mindepth 2 -maxdepth 2 -type d | sort); do
    codename=$(echo "$dir" | cut -d"/" -f2)
    component=$(echo "$dir" | cut -d"/" -f3)

    # not the provided --only-codename or --only-component
    if [ -n "$ONLY_CODENAME" ] && [ "$ONLY_CODENAME" != "$codename" ]; then
      continue
    fi
    if [ -n "$ONLY_COMPONENT" ] && [ "$ONLY_COMPONENT" != "$component" ]; then
      continue
    fi

    # skip named version folder (e.g. 3.x), the contents are symlinks
    if [[ $component == *"."* ]]; then
      continue
    fi

    rebuild_packages "$distro" "$codename" "$component"
  done

  popd >/dev/null
}

is_supported() {
  local distro="$1"

  if [ "$distro" == "ubuntu" ]; then
    return 0
  fi
  if [ "$distro" == "debian" ]; then
    return 0
  fi

  return 1
}

main() {
  for dir in $(find "$PKG_BUILD_PATH" -mindepth 1 -maxdepth 1 -type d); do
    distro="${dir##*/}"

    if ! is_supported "$distro"; then
      echo "Skipping $distro, it's not a supported distro."
      continue
    fi
    if [ -n "$ONLY_DISTRO" ] && [ "$ONLY_DISTRO" != "$distro" ]; then
      continue
    fi

    find_packages "$distro"
  done
}

usage() {
cat << EOF
Rebuild debian package sources

Usage: $0 --pkg-build-path <PATH> [options...]

Options:
  --pkg-build-path <path>    Path to build package folder

  --only-distro <name>       Only rebuild sources of this distro
  --only-codename <name>     Only rebuild sources of this codename
  --only-component <name>    Only rebuild sources of this component
  --only-package <name>      Only rebuild sources of this package

  --help                     Show this message
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

PKG_BUILD_PATH=""
ONLY_DISTRO=""
ONLY_CODENAME=""
ONLY_COMPONENT=""
ONLY_PACKAGE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --pkg-build-path)    parse_flag "$1" "$2" PKG_BUILD_PATH; shift 2 ;;

    --only-distro)       parse_flag "$1" "$2" ONLY_DISTRO; shift 2 ;;
    --only-codename)     parse_flag "$1" "$2" ONLY_CODENAME; shift 2 ;;
    --only-component)    parse_flag "$1" "$2" ONLY_COMPONENT; shift 2 ;;
    --only-package)      parse_flag "$1" "$2" ONLY_PACKAGE; shift 2 ;;

    -h|--help)           usage; exit 0; ;;
    -*|--*)              echo "Unknown option $1"; exit 1;  ;;
    *)                   echo "Unknown command $1"; exit 1; ;;
esac
done

if [ -z "$PKG_BUILD_PATH" ]; then
  echo "Error: required value for --pkg-build-path is missing"
  exit 1
fi
if [ ! -d "$PKG_BUILD_PATH" ]; then
  echo "Error: $PKG_BUILD_PATH not found"
  exit 1
fi
PKG_BUILD_PATH=$(realpath $PKG_BUILD_PATH)

main
