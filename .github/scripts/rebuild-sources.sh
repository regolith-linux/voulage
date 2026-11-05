#!/usr/bin/env bash
#
# Rebuild the source files.
#
# The following files will be rebuilt out of existing .orig.tar.gz file which
# is previously repacked without /debian folder in it.
#
# - .dsc
# - .debian.tar.xz
# - .tar.xz
#
# This will ensure one single .orig.tar.gz file can be used for all the
# packages of the same version and same component of different codenames.

# Rebuild one source package in the current component directory. Runs in a
# subshell, so its working directory changes and its temp dir cleanup never
# leak into the loop over the remaining sources. Fails if the source has no
# debian archive for the codename, if any step fails, or if the expected .dsc
# is not produced.
rebuild_source() (
  local codename=$1
  local pkg_full_name=$2
  local pkg_name=$3
  local component_dir
  local tmp
  local src_dir
  local file

  component_dir=$(pwd)

  if [ ! -f "$pkg_full_name-$codename.tar.xz" ] && [ ! -f "$pkg_full_name-$codename.debian.tar.xz" ]; then
    echo "Error: no debian archive found for $pkg_full_name in $codename." >&2
    return 1
  fi

  tmp=$(mktemp -d) || return 1
  if [ -z "$tmp" ] || [ ! -d "$tmp" ]; then
    return 1
  fi
  trap 'rm -rf "$tmp"' EXIT

  cp "$pkg_full_name.orig.tar.gz" "$tmp" || return 1
  for file in "$pkg_full_name-$codename.tar.xz" "$pkg_full_name-$codename.debian.tar.xz"; do
    if [ -f "$file" ]; then
      cp "$file" "$tmp" || return 1
    fi
  done

  # entering /tmp/tmp.XXXXXXXXXX
  cd "$tmp" || return 1

  tar -xzf "$pkg_full_name.orig.tar.gz" || return 1

  if [ -f "$pkg_full_name-$codename.tar.xz" ]; then
    mkdir temp || return 1
    tar -xf "$pkg_full_name-$codename.tar.xz" -C temp || return 1

    if [ -d "temp/$pkg_full_name/debian" ]; then
      mv "temp/$pkg_full_name/debian" . || return 1
    fi

    rm -rf temp
  fi
  if [ -f "$pkg_full_name-$codename.debian.tar.xz" ]; then
    tar -xf "$pkg_full_name-$codename.debian.tar.xz" || return 1
  fi

  if [ ! -d "debian/" ]; then
    echo "debian/ folder not found. cannot continue." >&2
    return 1
  fi

  # The unpacked source tree: the package's directory, or else the single
  # top-level directory of the .orig.tar.gz.
  src_dir="$pkg_name"
  if [ ! -d "$src_dir" ]; then
    src_dir=$(tar -tzf "$pkg_full_name.orig.tar.gz" | sed -n 's|^\./||; s|/.*||; /./p' | sort -u)
    if [ -z "$src_dir" ] || [ "$(printf '%s\n' "$src_dir" | wc -l)" -ne 1 ] || [ ! -d "$src_dir" ]; then
      src_dir="$pkg_name"
    fi
  fi

  mv "debian/" "$src_dir" || return 1

  cd "$src_dir" || return 1
  sudo apt update || return 1
  sudo apt build-dep -y . || return 1
  debuild -S -sa || return 1

  # leaving the source tree, back in /tmp/tmp.XXXXXXXXXX
  cd "$tmp" || return 1

  if [ ! -f "$pkg_full_name-$codename.dsc" ]; then
    echo "Error: debuild did not produce $pkg_full_name-$codename.dsc." >&2
    return 1
  fi

  # copy newly generated .dsc and, .debian.tar.xz or .tar.xz file back to the repo
  cp "$pkg_full_name-$codename.dsc" "$component_dir" || return 1
  for file in "$pkg_full_name-$codename.tar.xz" "$pkg_full_name-$codename.debian.tar.xz"; do
    if [ -f "$file" ]; then
      cp "$file" "$component_dir" || return 1
    fi
  done
)

rebuild_packages() {
  local distro=$1
  local codename=$2
  local component=$3
  local f
  local base_name
  local pkg_full_name
  local pkg_name

  echo -e "\033[0;34mProcessing source packages for $component $distro/$codename:\033[0m"

  pushd "$PKG_BUILD_PATH/$distro/$codename/$component" >/dev/null || {
    echo "Error: cannot enter $PKG_BUILD_PATH/$distro/$codename/$component." >&2
    FAILED_PACKAGES+=("$distro/$codename/$component")
    return
  }

  for f in $(find . -maxdepth 1 -type f -name "*.orig.tar.gz" | sort); do
    base_name=$(basename "$f")

    pkg_full_name="${base_name%.orig.tar.gz}"
    pkg_name=$(echo "$base_name" | cut -d"_" -f1)

    # not the provided --only-package
    if [ -n "$ONLY_PACKAGE" ] && [ "$ONLY_PACKAGE" != "$pkg_name" ]; then
      continue
    fi

    echo "::group::Rebuilding $pkg_full_name.orig.tar.gz"
    if ! rebuild_source "$codename" "$pkg_full_name" "$pkg_name"; then
      echo -e "\033[0;31mError: could not rebuild the source of $pkg_name ($pkg_full_name) for $distro/$codename/$component.\033[0m" >&2
      FAILED_PACKAGES+=("$pkg_name ($distro/$codename/$component)")
    fi
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
PKG_BUILD_PATH=$(realpath "$PKG_BUILD_PATH")

FAILED_PACKAGES=()

main

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
  echo -e "\033[0;31mError: could not rebuild the sources of:\033[0m" >&2
  printf '  %s\n' "${FAILED_PACKAGES[@]}" >&2
  exit 1
fi
