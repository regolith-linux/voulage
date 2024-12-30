#!/bin/bash

set -e
set -o errexit
# Extension for Debian repo and pacakge support

#### Debian specific functions

# Update the changelog to specify the target distribution codename
update_changelog() {
  set -x
  cd "${PKG_BUILD_PATH:?}/$PACKAGE_NAME"
  version=$(dpkg-parsechangelog --show-field Version)
  dch --force-distribution --distribution "$CODENAME" --newversion "${version}-1regolith-$CODENAME" "Automated Voulage release"

  cd - >/dev/null 2>&1 || exit
}

# Determine if the changelog has the correct distribution codename
dist_valid() {
  cd "${PKG_BUILD_PATH:?}/$PACKAGE_NAME"

  TOP_CHANGELOG_LINE=$(head -n 1 debian/changelog)
  CHANGELOG_DIST=$(echo "$TOP_CHANGELOG_LINE" | cut -d' ' -f3)

  cd - >/dev/null 2>&1

  # echo "Checking $CODENAME and $CHANGELOG_DIST"
  if [[ "$CHANGELOG_DIST" == *"$CODENAME"* ]]; then
    return 0
  else
    return 1
  fi
}

stage_source() {
  pushd .

  echo "Preparing source for $PACKAGE_NAME"
  cd "$PKG_BUILD_PATH/$PACKAGE_NAME" || exit
  debian_package_name=$(dpkg-parsechangelog --show-field Source)
  full_version=$(dpkg-parsechangelog --show-field Version)
  debian_version="${full_version%-*}"
  cd "$PKG_BUILD_PATH" || exit

  echo "Generating source tarball from git repo."
  tar --force-local -c -z -v -f  "${debian_package_name}_${debian_version}.orig.tar.gz" --exclude .git\* --exclude debian "$PACKAGE_NAME"

  if [ "$LOCAL_BUILD" == "false" ]; then
    debian_package_name_indicator="${debian_package_name:0:1}"
    if [ "${debian_package_name:0:3}" == "lib" ]; then
      debian_package_name_indicator="${debian_package_name:0:4}"
    fi

    # try to download the .orig.tar.gz from existing archive, and check if they are identical or not
    wget -O "${debian_package_name}_${debian_version}-existing.orig.tar.gz" "http://archive.regolith-desktop.com/$DISTRO/$SUITE/pool/main/${debian_package_name_indicator}/${debian_package_name}/${debian_package_name}_${debian_version}.orig.tar.gz" || true

    if [ -s "${debian_package_name}_${debian_version}-existing.orig.tar.gz" ]; then
      if ! diff <(tar -tvzf "${debian_package_name}_${debian_version}.orig.tar.gz" | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2 | sed 's|\./||') <(tar -tvzf "${debian_package_name}_${debian_version}-existing.orig.tar.gz" | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2 | sed 's|\./||') ; then
        # existing .orig.tar.gz file is different that the one we just built
        # keep the one we just built and override push it to the repository.
        rm -f "${debian_package_name}_${debian_version}-existing.orig.tar.gz" || true

        echo "SRCLOG:$DISTRO=$CODENAME=$SUITE=${debian_package_name:0:1}=${debian_package_name}=${debian_package_name}_${debian_version}=${debian_package_name}_${debian_version}.orig.tar.gz"
      else
        # both .orig.tar.gz files are identical!
        # remove the one we just built and reuse the existign one.
        rm -f "${debian_package_name}_${debian_version}.orig.tar.gz" || true
        mv "${debian_package_name}_${debian_version}-existing.orig.tar.gz" "${debian_package_name}_${debian_version}.orig.tar.gz"
      fi
    else
      # there's no existing .orig.tar.gz file! Clean up the empty downloaded file.
      rm -f "${debian_package_name}_${debian_version}-existing.orig.tar.gz" || true
    fi
  fi

  popd
}

build_src_package() {
  set -e

  pushd .
  echo "Building source package $PACKAGE_NAME"
  cd "$PKG_BUILD_PATH/$PACKAGE_NAME" || exit

  sanitize_git

  sudo apt update
  sudo apt build-dep -y .
  debuild -S -sa

  popd
}

build_bin_package() {
  set -e
  
  pushd .
  echo "Building binary package $PACKAGE_NAME"
  cd "$PKG_BUILD_PATH/$PACKAGE_NAME" || exit

  debuild -sa -b
  popd
}

publish() {
  cd "${PKG_BUILD_PATH:?}/$PACKAGE_NAME"
  version=$(dpkg-parsechangelog --show-field Version)
  debian_package_name=$(dpkg-parsechangelog --show-field Source)
  cd "$PKG_BUILD_PATH"

  DEB_SRC_PKG_PATH="$(pwd)/${debian_package_name}_${version}_source.changes"

  if [ ! -f "$DEB_SRC_PKG_PATH" ]; then
    echo "Failed to find changes file."
  else
    short_version="${version%-*}"

    mkdir -p $PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$SUITE

    cp "$(pwd)/${debian_package_name}_${version}.dsc" "$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$SUITE"
    cp "$(pwd)/${debian_package_name}_${short_version}.orig.tar.gz" "$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$SUITE"

    if [ -f "$(pwd)/${debian_package_name}_${version}.debian.tar.xz" ]; then
      cp "$(pwd)/${debian_package_name}_${version}.debian.tar.xz" "$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$SUITE"
    fi
    if [ -f "$(pwd)/${debian_package_name}_${version}.diff.gz" ]; then
      cp "$(pwd)/${debian_package_name}_${version}.diff.gz" "$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$SUITE"
    fi

    if [ "$LOCAL_BUILD" == "false" ] && [ "$SUITE" == "stable" ]; then
      mkdir -p "$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$COMPONENT"
      cd "$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$COMPONENT" >/dev/null 2>&1

      ln "../$SUITE/${debian_package_name}_${version}.dsc" .
      ln "../$SUITE/${debian_package_name}_${short_version}.orig.tar.gz" .

      if [ -f "../$SUITE/${debian_package_name}_${version}.debian.tar.xz" ]; then
        ln "../$SUITE/${debian_package_name}_${version}.debian.tar.xz" .
      fi
      if [ -f "../$SUITE/${debian_package_name}_${version}.diff.gz" ]; then
        ln "../$SUITE/${debian_package_name}_${version}.diff.gz" .
      fi

      cd - >/dev/null 2>&1
    fi

    echo "Publishing source package $debian_package_name into $PKG_PUBLISH_PATH"
  fi

  DEB_CONTROL_FILE="$PKG_BUILD_PATH/$PACKAGE_NAME/debian/control"
  ALL_ARCH="$ARCH,all"

  for target_arch in $(echo $ALL_ARCH | sed "s/,/ /g"); do
    cat "$DEB_CONTROL_FILE" | grep ^Package: | cut -d' ' -f2 | while read -r bin_pkg; do
      DEB_BIN_PKG_PATH="$(pwd)/${bin_pkg}_${version}_${target_arch}.deb"

      if [ -f "$DEB_BIN_PKG_PATH" ]; then
        mkdir -p $PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$SUITE
        cp "$DEB_BIN_PKG_PATH" "$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$SUITE"

        if [ "$LOCAL_BUILD" == "false" ] && [ "$SUITE" == "stable" ]; then
          mkdir -p "$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$COMPONENT"
          cd "$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$COMPONENT" >/dev/null 2>&1
          ln "../$SUITE/${bin_pkg}_${version}_${target_arch}.deb" .
          cd - >/dev/null 2>&1
        fi

        echo "Publishing deb package(s) $bin_pkg into $PKG_PUBLISH_PATH"
        echo "CHLOG:Published ${bin_pkg}_${version}_${target_arch}.deb in $DISTRO/$CODENAME/$STAGE from $PKG_LINE"
      else
        echo "Package $bin_pkg does not exist for $target_arch"
      fi
    done
  done
}

archive_setup_scripts() {
  # Following allows for internal dependencies
  rm /tmp/Release || true
  wget -P /tmp "http://archive.regolith-desktop.com/$DISTRO/$SUITE/dists/$CODENAME/Release" || true
  
  if [ -s /tmp/Release ]; then
    rm /tmp/Release

    local repo_line=""
    if [ "$LOCAL_BUILD" == "false" ] && [ "$SUITE" == "stable" ]; then
      # fixed version component
      repo_line="http://archive.regolith-desktop.com/$DISTRO/$SUITE $CODENAME v$COMPONENT"
    else
      # main component
      repo_line="http://archive.regolith-desktop.com/$DISTRO/$SUITE $CODENAME $COMPONENT"
    fi

    echo "Adding repo to apt: $repo_line"
    wget -qO - http://archive.regolith-desktop.com/regolith.key | sudo tee /etc/apt/keyrings/regolith.gpg
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/regolith.gpg] $repo_line" | sudo tee /etc/apt/sources.list.d/regolith.list

    sudo apt update
  fi
  
  if [ -f "/etc/apt/sources.list.d/regolith-local.list" ]; then
    sudo rm /etc/apt/sources.list.d/regolith-local.list
    echo "Cleaned up temp apt repo"
  fi
}

archive_cleanup_scripts() {
  # Remove regolith repo from build system apt config
  if [ -f /etc/apt/sources.list.d/regolith.list ]; then
    sudo rm -f /etc/apt/sources.list.d/regolith.list
  fi
}

# Setup debian repo
setup() {
  source_setup_scripts
  archive_setup_scripts
}
