#!/bin/bash


# --- Test Package Model Merging

../compute-package-changes.sh ../../../ unstable ubuntu focal amd64 /tmp/bt

EXPECTED="$(cat unstable-ubuntu-focal-model.json)"
ACTUAL="$(cat /tmp/bt/unstable-ubuntu-focal-model.json)"

if [[ $EXPECTED == "$ACTUAL" ]]; then
  echo "Test pass"
else
  echo "Test fail"
  exit 1
fi

# --- Test Manifest Generation

OUTPUT=$(../compute-package-changes.sh ../../../ unstable ubuntu focal amd64 /tmp/bt)

echo $OUTPUT