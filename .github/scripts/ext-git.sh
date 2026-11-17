#!/bin/bash

checkout() {
  set -e

  echo "::group::Cloning $PACKAGE_NAME on ref: $PACKAGE_REF"

  if [ -z "$PACKAGE_URL" ]; then
    echo "Error: package model is invalid. Model field 'source' undefined, aborting."
    exit 1
  fi

  if [ -d "$PKG_BUILD_PATH/$PACKAGE_NAME" ]; then
    echo "Deleting existing repo, $PACKAGE_NAME"
    rm -Rfv "${PKG_BUILD_PATH:?}/$PACKAGE_NAME"
  fi

  if [ ! -d "$PKG_BUILD_PATH" ]; then
    echo "Creating build directory $PKG_BUILD_PATH"

    mkdir -p "$PKG_BUILD_PATH" || {
      echo "Error: failed to create build dir $PKG_BUILD_PATH, aborting."
      exit 1
    }
  fi

  # The commit to build: the one the manifest records for the package (see
  # build_packages() in main.sh), whatever its ref names by now. Without a
  # manifest (local-build.sh) the ref is built, which may itself be a commit
  # id (see resolve_package_ref() in main.sh).
  local commit="${PACKAGE_COMMIT:-}"

  cd "$PKG_BUILD_PATH" || exit
  if [ -z "$commit" ] && [[ "$PACKAGE_REF" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] &&
    ! git ls-remote --exit-code "$PACKAGE_URL" "refs/heads/$PACKAGE_REF" "refs/tags/$PACKAGE_REF" >/dev/null; then
    commit="$PACKAGE_REF"
  fi

  if [ -n "$commit" ]; then
    # "git clone -b" doesn't take a commit id, and the commit may not be on
    # any branch or tag anymore: check it out after cloning, fetching it by
    # its id if the clone doesn't have it.
    echo "Checking out commit $commit"
    git clone --no-checkout "$PACKAGE_URL" "$PACKAGE_NAME"
    if ! git -C "$PACKAGE_NAME" cat-file -e "$commit^{commit}" 2>/dev/null; then
      git -C "$PACKAGE_NAME" fetch origin "$commit"
    fi
    git -C "$PACKAGE_NAME" checkout -q --detach "$commit"
    git -C "$PACKAGE_NAME" submodule update --init --recursive
  else
    git clone --recursive "$PACKAGE_URL" -b "$PACKAGE_REF" "$PACKAGE_NAME"
  fi

  cd - >/dev/null 2>&1 || exit
  echo "::endgroup::"
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
