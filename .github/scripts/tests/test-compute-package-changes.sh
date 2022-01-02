#!/bin/bash

REPO_BASE_DIR=$(realpath "$1")

# --- Test Package Model Merging

T2_ACTUAL=$("$REPO_BASE_DIR/.github/scripts/compute-package-changes.sh" "$REPO_BASE_DIR" unstable ubuntu focal amd64 /tmp/bt)

T1_EXPECTED="$(cat $REPO_BASE_DIR/.github/scripts/tests/unstable-ubuntu-focal-model.json)"
T1_ACTUAL="$(cat /tmp/bt/unstable-ubuntu-focal-model.json)"

if [[ $T1_EXPECTED == "$T1_ACTUAL" ]]; then
  echo "T1 Test pass"
else
  echo "T1 Test fail"
  exit 1
fi

# --- Test Manifest Generation
T2_EXPECTED="root-thing"

if [[ $T2_EXPECTED == "$T2_ACTUAL" ]]; then
  echo "T2 Test pass"
else
  echo "T2 Test fail.  Expected: $T2_EXPECTED  Actual: $T2_ACTUAL"
  exit 1
fi