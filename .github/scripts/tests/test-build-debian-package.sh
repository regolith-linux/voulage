#!/bin/bash

set -e

# Setup

REPO_BASE_DIR=$(realpath "$1")

"$REPO_BASE_DIR/.github/scripts/compute-package-changes.sh" "$REPO_BASE_DIR" unstable ubuntu focal amd64 /tmp/bt

"$REPO_BASE_DIR/.github/scripts/build-debian-package.sh" unstable ubuntu focal amd64 /tmp/testrepo https://myrepo.com /tmp/pbt default

if [ -f "/tmp/testrepo/conf/distributions" ]; then
  echo "T1 pass ~ created distributions"
else
  echo "T1 Fail - /tmp/testrepo/conf/distributions doesn't exist"
fi

if [ -f "/tmp/testrepo/pool/main/x/xrescat/xrescat_1.2.1-1-1regolith_amd64.deb" ]; then
  echo "T2 pass ~ created binary package"
else
  echo "T2 Fail - /tmp/testrepo/pool/main/x/xrescat/xrescat_1.2.1-1-1regolith_amd64.deb doesn't exist"
fi