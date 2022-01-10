#!/bin/bash
set -e

# Emit manifest entry line for package
handle_package() {
    # Get git hash
    local COMMIT_HASH=$(git ls-remote $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF | awk '{ print $1}')

    echo "$PACKAGE_NAME $PACAKGE_SOURCE_URL $PACKAGE_SOURCE_REF $COMMIT_HASH" >> "$NEXT_MANIFEST_FILE"

    echo "Updated manifest $NEXT_MANIFEST_FILE for package $PACKAGE_NAME"
}

# Traverse each package in the model and call handle_package
traverse_package_model() {
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
merge_models() {
  if [ ! -f "$ROOT_MODEL_PATH" ]; then
    echo "Invalid root model path: $ROOT_MODEL_PATH"
    exit 1
  fi

  if [ ! -d "$MANIFEST_PATH" ]; then
    mkdir -p "$MANIFEST_PATH"
  fi

  # Copy root model to build dir
  WORKING_ROOT_MODEL="$MANIFEST_PATH/root-model.json"
  cp "$ROOT_MODEL_PATH" "$WORKING_ROOT_MODEL"

  # Optionally merge stage package model
  STAGE_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/package-model.json"
  WORKING_STAGE_MODEL="$MANIFEST_PATH/$STAGE-model.json"
  if [ -f "$STAGE_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_ROOT_MODEL" "$STAGE_PACKAGE_MODEL" > "$WORKING_STAGE_MODEL"
  else
    cp "$WORKING_ROOT_MODEL" "$WORKING_STAGE_MODEL"
  fi

  # Optionally merge distro package model
  DISTRO_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/$DISTRO/package-model.json"
  WORKING_DISTRO_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-model.json"
  if [ -f "$DISTRO_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_STAGE_MODEL" "$DISTRO_PACKAGE_MODEL" > "$WORKING_DISTRO_MODEL"
  else
    cp "$WORKING_STAGE_MODEL" "$WORKING_DISTRO_MODEL"
  fi

  # Optionally merge codename package model
  CODENAME_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/package-model.json"
  WORKING_CODENAME_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-$CODENAME-model.json"
  if [ -f "$CODENAME_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_DISTRO_MODEL" "$CODENAME_PACKAGE_MODEL" > "$WORKING_CODENAME_MODEL"
  else
    cp "$WORKING_DISTRO_MODEL" "$WORKING_CODENAME_MODEL"
  fi

  # Optionally merge arch package model
  ARCH_PACKAGE_MODEL="$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/package-model.json"
  WORKING_ARCH_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-$CODENAME-$ARCH-model.json"
  if [ -f "$ARCH_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_CODENAME_MODEL" "$ARCH_PACKAGE_MODEL" > "$WORKING_ARCH_MODEL"
  else
    cp "$WORKING_CODENAME_MODEL" "$WORKING_ARCH_MODEL"
  fi

  PACKAGE_MODEL_FILE="$WORKING_ARCH_MODEL"
}

checkout() {
  if [ -z "$PACKAGE_URL" ]; then
    echo "Package model is invalid.  Model field 'source' undefined, aborting."
    exit 1
  fi

  if [ -d "$PKG_BUILD_DIR/$PACKAGE_NAME" ]; then
    echo "Deleting existing repo, $PACKAGE_NAME"
    rm -Rfv "${PKG_BUILD_DIR:?}/$PACKAGE_NAME"
  fi

  if [ ! -d "$PKG_BUILD_DIR" ]; then
    echo "Creating build directory $PKG_BUILD_DIR"
    mkdir -p "$PKG_BUILD_DIR" || {
      echo "Failed to create build dir $PKG_BUILD_DIR, aborting."
      exit 1
    }
  fi

  cd "$PKG_BUILD_DIR" || exit
  git clone --recursive "$PACKAGE_URL" -b "$PACKAGE_REF" "$PACKAGE_NAME"

  cd - >/dev/null 2>&1 || exit
}

sanitize_git() {
  if [ -d ".github" ]; then
    rm -Rf .github
    echo "Removed $(pwd).github directory before building to appease debuild."
  fi
  if [ -d ".git" ]; then
    rm -Rf .git
    echo "Removed $(pwd).git directory before building to appease debuild."
  fi
}

#### Debian specific functions

# Update the changelog to specify the target distribution codename
update_changelog() {
  cd "${PKG_BUILD_DIR:?}/$PACKAGE_NAME"
  version=$(dpkg-parsechangelog --show-field Version)
  dch --distribution "$CODENAME" --newversion "${version}-1regolith" "Automated release."

  cd - >/dev/null 2>&1 || exit
}

# Determine if the changelog has the correct distribution codename
dist_valid() {
  cd "${PKG_BUILD_DIR:?}/$PACKAGE_NAME"

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
  cd "$PKG_BUILD_DIR/$PACKAGE_NAME" || exit
  debian_package_name=$(dpkg-parsechangelog --show-field Source)
  full_version=$(dpkg-parsechangelog --show-field Version)
  debian_version="${full_version%-*}"
  cd "$PKG_BUILD_DIR" || exit

  echo "Generating source tarball from git repo."
  tar cfzv $debian_package_name\_${debian_version}.orig.tar.gz --exclude .git\* --exclude debian $PACKAGE_NAME/../$PACKAGE_NAME

  popd
}

build_src_package() {
  pushd .
  echo "Building source package $PACKAGE_NAME"
  cd "$PKG_BUILD_DIR/$PACKAGE_NAME" || exit

  sanitize_git
  sudo apt build-dep -y .
  debuild -S -sa

  popd
}

build_bin_package() {
  pushd .
  echo "Building binary package $PACKAGE_NAME"
  cd "$PKG_BUILD_DIR/$PACKAGE_NAME" || exit

  debuild -sa -b
  popd
}

source_pkg_exists() {
    SRC_PKG_VERSION=$(reprepro --basedir "$PKG_REPO_PATH" list "$CODENAME" "$1" | cut -d' ' -f3)

    SRC_PKG_BUILD_VERSION=$(echo $2 | cut -d'-' -f1)
    SRC_PKG_REPO_VERSION=$(echo $SRC_PKG_VERSION | cut -d'-' -f1)

    if [ "$SRC_PKG_REPO_VERSION" == "$SRC_PKG_BUILD_VERSION" ]; then
        return 0
    else
        return 1
    fi
}

publish_deb() {
  cd "${PKG_BUILD_DIR:?}/$PACKAGE_NAME"
  version=$(dpkg-parsechangelog --show-field Version)
  debian_package_name=$(dpkg-parsechangelog --show-field Source)
  cd "$PKG_BUILD_DIR"

  DEB_SRC_PKG_PATH="$PKG_BUILD_DIR/${debian_package_name}_${version}_source.changes"

  if [ ! -f "$DEB_SRC_PKG_PATH" ]; then
    echo "Failed to find changes file."
  fi

  if source_pkg_exists "$debian_package_name" "$version"; then
      echo "Ignoring source package, already exists in target repository"
  else
      echo "Ingesting source package $debian_package_name into $PKG_REPO_PATH"
      reprepro --basedir "$PKG_REPO_PATH" include "$CODENAME" "$DEB_SRC_PKG_PATH"
  fi

  DEB_CONTROL_FILE="$PKG_BUILD_DIR/$PACKAGE_NAME/debian/control"
  ALL_ARCH="$ARCH,all"

  for target_arch in $(echo $ALL_ARCH | sed "s/,/ /g"); do
      cat "$DEB_CONTROL_FILE" | grep ^Package: | cut -d' ' -f2 | while read -r bin_pkg; do
          DEB_BIN_PKG_PATH="$(pwd)/${bin_pkg}_${version}_${target_arch}.deb"
          if [ -f "$DEB_BIN_PKG_PATH" ]; then
              echo "Ingesting binary package $DEB_BIN_PKG_PATH into $PKG_REPO_PATH"
              reprepro --basedir "$PKG_REPO_PATH" includedeb "$CODENAME" "$DEB_BIN_PKG_PATH"
          else
              echo "Package $bin_pkg does not exist for $target_arch"
          fi
      done
  done
}

# Create repo dist file
generate_reprepro_dist() {
    

    echo "Origin: $PACKAGE_REPO_URL" > "$PKG_REPO_PATH/conf/distributions"
    echo "Label: $PACKAGE_REPO_URL" >> "$PKG_REPO_PATH/conf/distributions"
    echo "Codename: $CODENAME" >> "$PKG_REPO_PATH/conf/distributions"
    echo "Architectures: $ARCH source" >> "$PKG_REPO_PATH/conf/distributions"
    echo "Components: main" >> "$PKG_REPO_PATH/conf/distributions"
    echo "Description: $STAGE $DISTRO $CODENAME $ARCH" >> "$PKG_REPO_PATH/conf/distributions"
    echo "SignWith: $APT_KEY" >> "$PKG_REPO_PATH/conf/distributions"
}

# Setup debian repo
setup() {
  if [ ! -d "$PKG_REPO_PATH/conf" ]; then
    echo "Creating conf dir"
    mkdir -p "$PKG_REPO_PATH/conf"    
  fi

  if [ ! -f "$PKG_REPO_PATH/conf/distributions" ]; then
    echo "Package metadata not found, creating conf dir"
    generate_reprepro_dist
    cat "$PKG_REPO_PATH/conf/distributions"
  else
    echo "Existing metadata:"
    cat "$PKG_REPO_PATH/conf/distributions"
  fi

  source_setup_scripts
}

#### END Debian specific functions

# Traverse the stage tree and execute any found setup.sh scripts
source_setup_scripts() {
  local setup_script_locations=(
    "$REPO_ROOT/stage/setup.sh"
    "$REPO_ROOT/stage/$STAGE/setup.sh"
    "$REPO_ROOT/stage/$STAGE/$DISTRO/setup.sh"
    "$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/setup.sh"
    "$REPO_ROOT/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/setup.sh"
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
  while IFS= read -r PKG_LINE; do
    PACKAGE_NAME=$(echo "$PKG_LINE" | cut -d" " -f1)
    PACKAGE_URL=$(echo "$PKG_LINE" | cut -d" " -f2)
    PACKAGE_REF=$(echo "$PKG_LINE" | cut -d" " -f3)

    checkout
    update_changelog
    if dist_valid; then
      stage_source
      build_src_package
      build_bin_package
      publish_deb
    else
      echo "dist codename does not match in package changelog, ignoring $PACKAGE_NAME."
    fi
  done <<<"$PACKAGE_CHANGES"
}

#### Init input params

REPO_ROOT=$(realpath "$1")
STAGE=$2
DISTRO=$3
CODENAME=$4
ARCH=$5
PACKAGE_REPO_URL=$6
APT_KEY=$7
MODE=$8

#### Init globals

ROOT_MODEL_PATH="$REPO_ROOT/stage/package-model.json"
MANIFEST_PATH="/tmp/manifests"
PKG_REPO_PATH="/tmp/repo"
PKG_BUILD_DIR="/tmp/packages"

#### Setup files

if [ -d "$MANIFEST_PATH" ]; then
  echo "Deleting pre-existing manifest dir $MANIFEST_PATH"
  rm -Rf "$MANIFEST_PATH"
fi

if [ -d "$PKG_BUILD_DIR" ]; then
  echo "Deleting pre-existing package build dir $PKG_BUILD_DIR"
  rm -Rf "$PKG_BUILD_DIR"
fi

if [ ! -d "$MANIFEST_PATH" ]; then
  mkdir -p $MANIFEST_PATH
fi

if [ ! -d "$PKG_REPO_PATH" ]; then
  mkdir -p $PKG_REPO_PATH
fi

#### Generate Manifest from package model tree and git repo state

PREV_MANIFEST_FILE="$PKG_REPO_PATH/manifest.txt"
NEXT_MANIFEST_FILE="$MANIFEST_PATH/next-manifest.txt"

# Create prev manifest if doesn't exist (first run)
if [ ! -f "$PREV_MANIFEST_FILE" ]; then
  touch "$PREV_MANIFEST_FILE"
fi

# Delete pre-existing manifest before generating new
if [ -f "$NEXT_MANIFEST_FILE" ]; then
  rm "$NEXT_MANIFEST_FILE"
  echo "Deleted pre-existing manifest file $NEXT_MANIFEST_FILE"
fi

# Merge models across stage, distro, codename, arch
merge_models
# Iterate over each package in the model and call handle_package
traverse_package_model

#### Find packages that need to be built
echo Diffing "$PREV_MANIFEST_FILE" "$NEXT_MANIFEST_FILE"
PACKAGE_CHANGES=$(diff "$PREV_MANIFEST_FILE" "$NEXT_MANIFEST_FILE" | grep '^[>][^>]' | cut -c3- | uniq | sort)

if [ -z "$PACKAGE_CHANGES" ]; then
  echo "No package changes found, exiting."
  exit 0
fi

if [ "$MODE" == "build" ]; then
  #### Build packages

  setup
  build_packages

  #### Cleanup

  rm "$PREV_MANIFEST_FILE"
  mv "$NEXT_MANIFEST_FILE" "$PREV_MANIFEST_FILE"
else
  echo "$PACKAGE_CHANGES"
fi