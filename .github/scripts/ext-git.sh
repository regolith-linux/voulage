#!/bin/bash

checkout() {
  set -e

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

  max_iteration=10

  for i in $(seq 1 $max_iteration)
  do
    git clone --recursive "$PACKAGE_URL" -b "$PACKAGE_REF" "$PACKAGE_NAME"
    result=$?
    if [[ $result -eq 0 ]]
    then
      echo "git clone successful on try $result"
      break
    else
      echo "git clone failed, retry $result"
      sleep 5
    fi
  done

  if [[ $result -ne 0 ]]
  then
    echo "All of the trials failed"
  fi

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