#!/bin/bash


# --- Test Package Model Merging

../compute-package-changes.sh ../../../ unstable ubuntu focal amd64 /tmp/bt

T1_EXPECTED="$(cat unstable-ubuntu-focal-model.json)"
T1_ACTUAL="$(cat /tmp/bt/unstable-ubuntu-focal-model.json)"

if [[ $T1_EXPECTED == "$T1_ACTUAL" ]]; then
  echo "T1 Test pass"
else
  echo "T1 Test fail"
  exit 1
fi

# --- Test Manifest Generation

T2_ACTUAL=$(../compute-package-changes.sh ../../../ unstable ubuntu focal amd64 /tmp/bt)
T2_EXPECTED="root-thing"

if [[ $T2_EXPECTED == "$T2_ACTUAL" ]]; then
  echo "T2 Test pass"
else
  echo "T2 Test fail"
  exit 1
fi