#!/usr/bin/env bash
#
# Publish new repos out of merged legacy repositories.

set -e

# create repo if it doesn't exist
create_repo() {
  local distro=$1    # debian, ubuntu
  local codename=$2  # bookworm, noble, etc.
  local suite=$3     # experimental, unstable, testing, backports, stable
  local component=$4 # main, v3.2, v3.1, etc.

  echo "::group::Processing $codename-$component repository"

  if ! aptly repo show -config="/etc/aptly/$distro/$suite.conf" "$codename-$component" >/dev/null 2>&1; then
    echo "Creating local repository $codename-$component"
    aptly \
      repo \
      create \
      -config="/etc/aptly/$distro/$suite.conf" \
      -component="$component" \
      -distribution="$codename" \
      -comment="Regolith for $distro $codename" \
      "$codename-$component"
  else
    echo "Using existing repository $codename-$component"
    aptly repo show -config="/etc/aptly/$distro/$suite.conf" "$codename-$component"
  fi

  echo "::endgroup::"
}

# add files to the repo based on either of the following scenarios
#
# 1. add this directory, if there's no subdirectory
# 2. otherwise add all the files in the directory
add_files() {
  local distro=$1    # debian, ubuntu
  local codename=$2  # bookworm, noble, etc.
  local suite=$3     # experimental, unstable, testing, backports, stable
  local component=$4 # main, v3.2, v3.1, etc.

  local files=(.)

  echo "::group::Adding files to repository $codename-$component"

  local packages_path="$distro/$codename/$suite"
  if [ "$suite" == "stable" ] && [ "$component" != "main" ]; then
    packages_path="$distro/$codename/${component:1}"
  fi

  pushd "$packages_path" >/dev/null

  if [ "$(find . -maxdepth 1 -type d | wc -l)" != 1 ]; then
    # one argument per file, whatever the file names contain
    mapfile -d '' files < <(find . -maxdepth 1 \( -name "*.deb" -o -name "*.dsc" \) -print0)
  fi

  # only use -force-replace if adding to unstable or experimental
  local force_replace=""

  if [ "$suite" == "experimental" ] || [ "$suite" == "unstable" ]; then
    force_replace="-force-replace"
  fi

  aptly \
    repo \
    add \
    -config="/etc/aptly/$distro/$suite.conf" \
    -remove-files $force_replace \
    "$codename-$component" \
    "${files[@]}"

  popd >/dev/null
  echo "::endgroup::"
}

# publish or update any repo that's not 'stable'
publish_repo() {
  local distro=$1    # debian, ubuntu
  local codename=$2  # bookworm, noble, etc.
  local suite=$3     # experimental, unstable, testing, backports
  local component=$4 # main, v3.2, v3.1, etc.

  echo "::group::Publishing to $distro $codename repository"

  # only use -force-overwrite if publishing to unstable or experimental
  local force_overwrite=""

  if [ "$suite" == "experimental" ] || [ "$suite" == "unstable" ]; then
    force_overwrite="-force-overwrite"
  fi

  if aptly publish show -config="/etc/aptly/$distro/$suite.conf" "$codename" > /dev/null 2>&1; then            
    if [ "$suite" == "stable" ] && [ "$component" != "main" ]; then
      echo "Adding $component to existing $distro $codename published repository"
      aptly \
        publish \
        source \
        add \
        -config="/etc/aptly/$distro/$suite.conf" \
        -component="$component" \
        "$codename" \
        "$codename-$component" || true
    fi

    echo "Updating $distro $codename published repository"
    aptly \
      publish \
      update \
      -config="/etc/aptly/$distro/$suite.conf" $force_overwrite \
      "$codename"
  else
    echo "Publishing $distro $codename repository with $component component"
    aptly \
      publish \
      repo \
      -config="/etc/aptly/$distro/$suite.conf" $force_overwrite \
      -component="$component" \
      -distribution="$codename" \
      -origin="Regolith" \
      -label="Regolith" \
      -suite="$suite" \
      -acquire-by-hash \
      "$codename-$component"
  fi

  echo "::endgroup::"
}

publish_distro() {
  local distro="$1"
  local dir

  pushd "$PACKAGES_ROOT" >/dev/null

  # make sure we always create "main" component for stable releases first,
  # even if the fixed version component is called first in the sort.
  for dir in $(find "$distro/" -mindepth 1 -maxdepth 1 -type d | sort); do
    local codename=$(echo "$dir" | cut -d"/" -f2)

    for dir2 in $(find "$distro/$codename/" -mindepth 1 -maxdepth 1 -type d | sort -r); do
      local component=$(echo "$dir2" | cut -d"/" -f3)

      if [[ "${component:0:1}" == "v" ]]; then
        component="${component:1}"
      fi

      if [ -n "$ONLY_CODENAME" ] && [ "$ONLY_CODENAME" != "$codename" ]; then
        continue
      fi
      if [ -n "$ONLY_COMPONENT" ] && [ "$ONLY_COMPONENT" != "$component" ]; then
        continue
      fi

      local publish_suite
      local publish_component

      case $component in
        # not stable releases
        experimental | unstable | testing | backports)
          publish_suite="$component"
          publish_component="main"
          ;;

        # stable main releases (e.g. stable)
        stable)
          publish_suite="stable"
          publish_component="main"
          ;;

        # stable versioned releases (e.g. 3.1, 3.2, etc)
        *)
          publish_suite="stable"
          publish_component="v$component"
          ;;
      esac

      echo -e "\033[0;34mPublishing packages to $publish_suite $distro/$codename:\033[0m"

      # check if there's any package to publish; an empty suite must not
      # stop the remaining suites and codenames of this distro
      if [ -d "$distro/$codename/$publish_suite/" ] && [ -z "$(ls -A "$distro/$codename/$publish_suite/")" ]; then
        echo "No package found to publish."
        continue
      fi

      create_repo "$distro" "$codename" "$publish_suite" "$publish_component"
      add_files "$distro" "$codename" "$publish_suite" "$publish_component"
      publish_repo "$distro" "$codename" "$publish_suite" "$publish_component"

      # delete the package folder if it's empty
      if [ -d "$distro/$codename/$publish_suite/" ] && [ -z "$(ls -A "$distro/$codename/$publish_suite/")" ]; then
        rm -rf "$distro/$codename/$publish_suite/"
        echo "$distro/$codename/$publish_suite/ cleaned up successfully"
      else
        echo "warning: $distro/$codename/$publish_suite/ is not empty or not found"
      fi
    done

    # delete the package folder if it's empty
    if [ -d "$distro/$codename/" ] && [ -z "$(ls -A "$distro/$codename/")" ]; then
      rm -rf "$distro/$codename/"
      echo "$distro/$codename/ cleaned up successfully"
    else
      echo "warning: $distro/$codename/ is not empty or not found"
    fi
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
  local dir

  for dir in $(find "$PACKAGES_ROOT" -mindepth 1 -maxdepth 1 -type d | sort); do
    local distro="${dir##*/}"

    if ! is_supported "$distro"; then
      echo "Skipping $distro, it's not a supported distro."
      continue
    fi
    if [ -n "$ONLY_DISTRO" ] && [ "$ONLY_DISTRO" != "$distro" ]; then
      continue
    fi

    publish_distro "$distro"

    # delete the package folder if it's empty
    if [ -d "$dir/" ] && [ -z "$(ls -A "$dir/")" ]; then
      rm -rf "$dir/"
      echo "$dir/ cleaned up successfully"
    else
      echo "warning: $dir/ is not empty or not found"
    fi
  done

  # delete the package folder if it's empty
  if [ -d "$PACKAGES_ROOT" ] && [ -z "$(ls -A "$PACKAGES_ROOT")" ]; then
    rm -rf "$PACKAGES_ROOT"
    echo "$PACKAGES_ROOT/ cleaned up successfully"
  else
    echo "warning: $PACKAGES_ROOT/ is not empty or not found"
  fi
}

if [ -z "$1" ]; then
    echo "usage: publish-repos.sh </path/to/archives/packages>"
    exit 1
fi

PACKAGES_ROOT=$(realpath "$1") # e.g. /opt/archives/packages

if [ ! -d "$PACKAGES_ROOT" ]; then
    echo "error: $PACKAGES_ROOT not found"
    exit 1
fi

ONLY_DISTRO="$2"
ONLY_CODENAME="$3"
ONLY_COMPONENT="$4"

main
