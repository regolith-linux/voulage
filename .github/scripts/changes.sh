#!/bin/bash
set -e

#### Init input params

REPO_ROOT=$(realpath "$1")
STAGE=$2
DISTRO=$3
CODENAME=$4
ARCH=$5
PACKAGE_REPO_URL=$6
APT_KEY=$7

#### Init globals

ROOT_MODEL_PATH="$REPO_ROOT/stage/package-model.json"
MANIFEST_PATH="/tmp/manifests"
PKG_REPO_PATH="/tmp/repo"
PKG_BUILD_DIR="/tmp/packages"