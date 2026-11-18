#!/bin/bash

set -e
set -o errexit
# Extension for Debian repo and package support

#### Debian specific functions

# Stages that build branch heads instead of release tags (see handle_package()
# in main.sh). Packages built for them get a snapshot version, so that every
# new commit is published under a new, higher version instead of reusing the
# version of the last release.
is_snapshot_stage() {
  [ "$STAGE" == "experimental" ] || [ "$STAGE" == "unstable" ]
}

# Print the snapshot marker of the checked out commit: "+git" followed by the
# UTC committer date and time and the short commit hash, for example
# "+git20261026.185700.52ece7e".
#
# The marker only depends on the commit. Every job that builds the same commit
# (any codename or arch, from voulage or from the package's own workflow) gets
# the same version, and building a commit again does not change it.
#
# The marker goes right after "-1regolith". "+" sorts the snapshot above the
# release that debian/changelog names, and below any later release. If the
# changelog entry is UNRELEASED, that version is not released yet: "~" sorts its
# snapshots below it, and still above the previous release.
#
# Must run in the package's git checkout, before debian/changelog is updated.
snapshot_suffix() {
  local commit_time
  local commit_hash
  local separator="+"

  if ! commit_time=$(TZ=UTC0 git -c safe.directory='*' show -s --format=%cd --date=format-local:%Y%m%d.%H%M%S HEAD 2>/dev/null) ||
    ! commit_hash=$(git -c safe.directory='*' rev-parse HEAD 2>/dev/null); then
    return 1
  fi

  if [ "$(dpkg-parsechangelog --show-field Distribution)" == "UNRELEASED" ]; then
    separator="~"
  fi

  echo "${separator}git${commit_time}.${commit_hash:0:7}"
}

# Update the changelog to specify the target distribution codename
update_changelog() {
  # set -x
  echo "::group::Updating debian/changelog file"
  cd "${PKG_BUILD_PATH:?}/$PACKAGE_NAME"
  version=$(dpkg-parsechangelog --show-field Version)

  local snapshot=""
  if is_snapshot_stage && ! snapshot=$(snapshot_suffix); then
    echo "::warning::No git commit found for $PACKAGE_NAME, building it for $STAGE without a snapshot version."
    snapshot=""
  fi

  # The upstream version of the source package is "${version}-1regolith${snapshot}"
  # (one .orig.tar.gz shared by all codenames) and the Debian revision is the
  # codename.
  local new_version="${version}-1regolith${snapshot}-$CODENAME"

  echo -e "\033[0;34mUpdating changlog to ${new_version} for $CODENAME...\033[0m"
  dch --force-distribution --distribution "$CODENAME" --newversion "${new_version}" "Automated Voulage release"

  cd - >/dev/null 2>&1 || exit
  echo "::endgroup::"
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
  echo "::group::Preparing source for $PACKAGE_NAME"
  pushd .

  cd "$PKG_BUILD_PATH/$PACKAGE_NAME" || exit
  debian_package_name=$(dpkg-parsechangelog --show-field Source)
  full_version=$(dpkg-parsechangelog --show-field Version)
  # Debian file names never contain the epoch ("1:2.0-1" -> "2.0-1"), the
  # version in the package metadata keeps it.
  debian_version="${full_version#*:}"
  debian_version="${debian_version%-*}"
  cd "$PKG_BUILD_PATH" || exit

  echo -e "\033[0;34mGenerating source tarball from git repo\033[0m"
  tar --force-local -c -z -v -f  "${debian_package_name}_${debian_version}.orig.tar.gz" --exclude .git\* --exclude debian "$PACKAGE_NAME"

  if [ "$LOCAL_BUILD" == "false" ]; then
    debian_package_name_indicator="${debian_package_name:0:1}"
    if [ "${debian_package_name:0:3}" == "lib" ]; then
      debian_package_name_indicator="${debian_package_name:0:4}"
    fi

    echo -e "\033[0;34mDownloading existing .orig.tar.gz from archive\033[0m"

    # try to download the .orig.tar.gz from existing archive, and check if they are identical or not
    wget -O "${debian_package_name}_${debian_version}-existing.orig.tar.gz" "http://archive.regolith-desktop.com/$DISTRO/$SUITE/pool/main/${debian_package_name_indicator}/${debian_package_name}/${debian_package_name}_${debian_version}.orig.tar.gz" || true

    if [ -s "${debian_package_name}_${debian_version}-existing.orig.tar.gz" ]; then
      echo -e "\033[0;34mChecking if existing is the same as the one just built...\033[0m"

      tmp=$(mktemp -d)
      mkdir -p "${tmp}/current"
      mkdir -p "${tmp}/existing"

      tar -xzf "${debian_package_name}_${debian_version}.orig.tar.gz" -C "${tmp}/current"
      tar -xzf "${debian_package_name}_${debian_version}-existing.orig.tar.gz" -C "${tmp}/existing"

      if ! diff -r --no-dereference ${tmp}/current/*/ ${tmp}/existing/*/; then
        # existing .orig.tar.gz file is different that the one we just built
        # keep the one we just built and override push it to the repository.
        rm -f "${debian_package_name}_${debian_version}-existing.orig.tar.gz" || true

        echo "  They are different! Need to rebuild the source."
        echo "SRCLOG:$DISTRO=$CODENAME=$SUITE=${debian_package_name_indicator}=${debian_package_name}=${debian_package_name}_${debian_version}=${debian_package_name}_${debian_version}.orig.tar.gz"
        if [ "$SUITE" == "stable" ]; then
          echo "SRCLOG:$DISTRO=$CODENAME=$COMPONENT=${debian_package_name_indicator}=${debian_package_name}=${debian_package_name}_${debian_version}=${debian_package_name}_${debian_version}.orig.tar.gz"
        fi
      else
        # both .orig.tar.gz files are identical!
        # remove the one we just built and reuse the existing one.
        echo "  They are the same."
        rm -f "${debian_package_name}_${debian_version}.orig.tar.gz" || true
        mv "${debian_package_name}_${debian_version}-existing.orig.tar.gz" "${debian_package_name}_${debian_version}.orig.tar.gz"
      fi
      if [ -n "$tmp" ]; then
        rm -rf "$tmp" || true
      fi
    else
      # there's no existing .orig.tar.gz file! Clean up the empty downloaded file.
      echo "Existing .orig.tar.gz file not found in the archives. Using the one just built."
      rm -f "${debian_package_name}_${debian_version}-existing.orig.tar.gz" || true
      echo "SRCLOG:$DISTRO=$CODENAME=$SUITE=${debian_package_name_indicator}=${debian_package_name}=${debian_package_name}_${debian_version}=${debian_package_name}_${debian_version}.orig.tar.gz"
      if [ "$SUITE" == "stable" ]; then
        echo "SRCLOG:$DISTRO=$CODENAME=$COMPONENT=${debian_package_name_indicator}=${debian_package_name}=${debian_package_name}_${debian_version}=${debian_package_name}_${debian_version}.orig.tar.gz"
      fi
    fi
  fi

  popd
  echo "::endgroup::"
}

build_src_package() {
  set -e

  echo "::group::Building source package $PACKAGE_NAME"
  pushd .
  cd "$PKG_BUILD_PATH/$PACKAGE_NAME" || exit

  echo -e "\033[0;34mSanitizing package folder.\033[0m"
  sanitize_git

  echo -e "\033[0;34mBuilding source package.\033[0m"
  sudo apt update
  sudo apt build-dep -y .

  local deb_build_sign=""
  if [ "$LOCAL_BUILD" == "true" ]; then
    deb_build_sign="-us -uc"
  fi

  debuild -S -sa $deb_build_sign

  popd
  echo "::endgroup::"
}

build_bin_package() {
  set -e

  echo "::group::Building binary package $PACKAGE_NAME"
  pushd .
  cd "$PKG_BUILD_PATH/$PACKAGE_NAME" || exit

  echo -e "\033[0;34mBuilding binary package.\033[0m"

  local deb_build_sign=""
  if [ "$LOCAL_BUILD" == "true" ]; then
    deb_build_sign="-us -uc"
  fi

  debuild -b -sa $deb_build_sign

  popd
  echo "::endgroup::"
}

# Print the file name of each binary package to publish, one per line.
#
# The set is what the build itself says it produced: the .deb files listed in
# the binary .changes that dpkg-buildpackage writes from debian/files. Binary
# packages the build leaves out on purpose (Architecture, Build-Profiles,
# "dh -N" or a vendor condition in debian/rules) are not in it, so nothing
# has to be declared per target here.
#
# Only binary packages that debian/control declares are published, so the
# -dbgsym packages debhelper adds and udebs are left out. Each file has to
# exist with the size and SHA-256 sum the .changes records, and carry the
# version being published.
#
# The set also has to be installable as far as this source is concerned:
# when a published package depends (Depends or Pre-Depends) on another binary
# package of the same source, an alternative of that dependency has to be in
# the set or provided by it, or come from outside this source. Otherwise
# nothing is printed and the function fails, naming each missing package.
list_published_binaries() {
  local changes_file="$1"
  local control_file="$2"
  local version="$3"

  perl -MDpkg::Control -MDpkg::Control::Info -MDpkg::Deps -MDigest::SHA -e '
    use strict;
    use warnings;
    my ($changes_file, $control_file, $version) = @ARGV;
    (my $dir = $changes_file) =~ s{/[^/]*$}{};
    my $failed = 0;
    sub problem { print STDERR "$_[0]\n"; $failed = 1; }

    my %declared;
    foreach my $pkg (Dpkg::Control::Info->new($control_file)->get_packages()) {
      my $type = $pkg->{"Package-Type"} // $pkg->{"XC-Package-Type"} // "deb";
      $declared{$pkg->{Package}} = 1 if $type eq "deb";
    }

    my $changes = Dpkg::Control->new(type => CTRL_FILE_CHANGES);
    $changes->load($changes_file);
    if (($changes->{Version} // "") ne $version) {
      print STDERR "$changes_file is for version " . ($changes->{Version} // "?") . ", not $version.\n";
      exit 1;
    }

    my (%sha256, %size);
    foreach my $line (split /\n/, $changes->{"Checksums-Sha256"} // "") {
      my ($sum, $bytes, $file) = split " ", $line;
      next unless defined $file;
      ($sha256{$file}, $size{$file}) = ($sum, $bytes);
    }

    my (@files, %built, %provided);
    foreach my $file (sort keys %sha256) {
      next unless $file =~ /\.deb$/;
      my ($name) = split /_/, $file;
      next unless $declared{$name};

      my $path = "$dir/$file";
      if (! -f $path) {
        problem("$file is listed in $changes_file but not found!");
        next;
      }
      if (-s $path != $size{$file} || Digest::SHA->new(256)->addfile($path)->hexdigest ne $sha256{$file}) {
        problem("$file does not match the size and SHA-256 sum in $changes_file!");
        next;
      }

      open(my $fh, "-|", "dpkg-deb", "--field", $path) or die "dpkg-deb: $!\n";
      my $fields = Dpkg::Control->new(type => CTRL_PKG_DEB);
      $fields->parse($fh, $path);
      close($fh) or die "dpkg-deb --field $path failed\n";
      if ($fields->{Version} ne $version) {
        problem("$file has version $fields->{Version}, not $version!");
        next;
      }

      push @files, [ $file, $fields ];
      $built{$fields->{Package}} = 1;
      $provided{$fields->{Package}} = 1;
      if (defined $fields->{Provides}) {
        $provided{$_->{package}} = 1 foreach deps_parse($fields->{Provides}, union => 1)->get_deps();
      }
    }

    foreach my $entry (@files) {
      my ($file, $fields) = @$entry;
      foreach my $field ("Pre-Depends", "Depends") {
        next unless defined $fields->{$field};
        foreach my $group (deps_parse($fields->{$field})->get_deps()) {
          my @alternatives = $group->isa("Dpkg::Deps::OR") ? $group->get_deps() : ($group);
          next if grep { !$declared{$_->{package}} || $provided{$_->{package}} } @alternatives;
          problem("$fields->{Package} ($field: $group) needs " .
            join(" or ", map { $_->{package} } @alternatives) . ", which this build did not produce!");
        }
      }
    }

    exit 1 if $failed;
    if (!@files) {
      print STDERR "$changes_file lists no binary package declared in $control_file.\n";
      exit 1;
    }
    print "$_->[0]\n" foreach @files;
  ' "$changes_file" "$control_file" "$version"
}

publish() {
  echo "::group::Publishing binary and source packages"
  cd "${PKG_BUILD_PATH:?}/$PACKAGE_NAME"
  version=$(dpkg-parsechangelog --show-field Version)
  debian_package_name=$(dpkg-parsechangelog --show-field Source)
  cd "$PKG_BUILD_PATH"

  # Debian file names never contain the epoch ("1:2.0-1" -> "2.0-1").
  local file_version="${version#*:}"
  local short_version="${file_version%-*}"
  local suite_path="$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$SUITE"
  local component_path="$PKG_PUBLISH_PATH/$DISTRO/$CODENAME/$COMPONENT"
  local link_component="false"
  if [ "$LOCAL_BUILD" == "false" ] && [ "$SUITE" == "stable" ]; then
    link_component="true"
  fi

  local source_changes="${debian_package_name}_${file_version}_source.changes"
  local source_files=(
    "${debian_package_name}_${file_version}.dsc"
    "${debian_package_name}_${short_version}.orig.tar.gz"
  )
  local file
  local missing=0

  for file in "$source_changes" "${source_files[@]}"; do
    if [ ! -f "$PKG_BUILD_PATH/$file" ]; then
      echo -e "\033[0;31m$file not found!\033[0m" >&2
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    echo "Error: source package $debian_package_name $version is incomplete, not publishing it." >&2
    return 1
  fi

  for file in debian.tar.xz tar.xz diff.gz; do
    if [ -f "$PKG_BUILD_PATH/${debian_package_name}_${file_version}.$file" ]; then
      source_files+=("${debian_package_name}_${file_version}.$file")
    fi
  done

  # Publish the binary packages the build produced, or none: see
  # list_published_binaries for what makes the set complete.
  local binary_changes="${debian_package_name}_${file_version}_${ARCH}.changes"
  DEB_CONTROL_FILE="$PKG_BUILD_PATH/$PACKAGE_NAME/debian/control"
  local bin_list
  local bin_files=()
  if [ ! -f "$PKG_BUILD_PATH/$binary_changes" ]; then
    echo -e "\033[0;31m$binary_changes not found!\033[0m" >&2
    echo "Error: binary packages of $debian_package_name $version are missing, not publishing it." >&2
    return 1
  fi
  if ! bin_list=$(list_published_binaries "$PKG_BUILD_PATH/$binary_changes" "$DEB_CONTROL_FILE" "$version"); then
    echo "Error: binary packages of $debian_package_name $version are incomplete, not publishing it." >&2
    return 1
  fi
  mapfile -t bin_files <<< "$bin_list"

  echo -e "\033[0;34mPublishing source package $debian_package_name into $PKG_PUBLISH_PATH.\033[0m"
  mkdir -p "$suite_path"
  if [ "$link_component" == "true" ]; then
    mkdir -p "$component_path"
  fi

  for file in "${source_files[@]}"; do
    echo "  Copying $file"
    cp "$PKG_BUILD_PATH/$file" "$suite_path"
    if [ "$link_component" == "true" ]; then
      ln "$suite_path/$file" "$component_path/$file"
    fi
  done

  echo -e "\033[0;34mPublishing binary package $debian_package_name into $PKG_PUBLISH_PATH.\033[0m"

  for file in "${bin_files[@]}"; do
    echo "  Copying $file"
    cp "$PKG_BUILD_PATH/$file" "$suite_path"
    if [ "$link_component" == "true" ]; then
      ln "$suite_path/$file" "$component_path/$file"
    fi

    echo "CHLOG:Published $file in $DISTRO/$CODENAME/$STAGE from $PKG_LINE"
  done

  echo "::endgroup::"
}

archive_setup_scripts() {
  # Following allows for internal dependencies

  echo "::group::Setting up archive apt list"
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

    echo -e "\033[0;34mAdding repo to apt: $repo_line\033[0m"
    sudo mkdir -p /etc/apt/keyrings/
    wget -qO - http://archive.regolith-desktop.com/regolith.key | gpg --dearmor | sudo tee /etc/apt/keyrings/regolith.gpg >/dev/null
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/regolith.gpg] $repo_line" | sudo tee /etc/apt/sources.list.d/regolith.list

    sudo apt update
  fi

  if [ -f "/etc/apt/sources.list.d/regolith-local.list" ]; then
    sudo rm /etc/apt/sources.list.d/regolith-local.list
    echo "Cleaned up temp apt repo"
  fi
  echo "::endgroup::"
}

archive_cleanup_scripts() {
  # Remove regolith repo from build system apt config
  echo "::group::Cleaning up archive apt list"
  if [ -f "/etc/apt/sources.list.d/regolith.list" ]; then
    echo "Deleting /etc/apt/sources.list.d/regolith.list file"
    sudo rm -f /etc/apt/sources.list.d/regolith.list || true
  fi
  echo "::endgroup::"
}

# Setup debian repo
setup() {
  source_setup_scripts
  archive_setup_scripts
}
