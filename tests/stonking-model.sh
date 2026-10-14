#!/bin/bash
# Check the merged ubuntu/stonking package models against ubuntu/resolute.
#
# The models are merged the way .github/scripts/main.sh merge_models does it
# (root -> stage -> distro -> codename, jq '.[0] * .[1]'). Stonking must match
# resolute except for the packages listed in DIFFERS, whose stonking values
# are checked explicitly below.
set -euo pipefail

cd "$(dirname "$0")/.."

DIFFERS='["sway-regolith", "regolith-control-center", "armesto"]'

merge() {
  local stage=$1 codename=$2 model f
  model=$(cat stage/package-model.json)
  for f in "stage/$stage/package-model.json" \
           "stage/$stage/ubuntu/package-model.json" \
           "stage/$stage/ubuntu/$codename/package-model.json"; do
    if [ -f "$f" ]; then
      model=$(jq -s '.[0] * .[1]' <(echo "$model") "$f")
    fi
  done
  echo "$model"
}

fail=0
for stage in unstable testing; do
  resolute=$(merge "$stage" resolute)
  stonking=$(merge "$stage" stonking)

  if ! diff <(echo "$resolute" | jq -S --argjson d "$DIFFERS" 'del(.packages[$d[]])') \
            <(echo "$stonking" | jq -S --argjson d "$DIFFERS" 'del(.packages[$d[]])'); then
    echo "FAIL: $stage: stonking differs from resolute outside $DIFFERS"
    fail=1
  fi

  sway_ref=$(echo "$stonking" | jq -r '.packages["sway-regolith"].ref')
  if [ "$sway_ref" != "package-sway-v1.12" ]; then
    echo "FAIL: $stage: sway-regolith ref is '$sway_ref', expected package-sway-v1.12"
    fail=1
  fi

  rcc=$(echo "$stonking" | jq -c '.packages["regolith-control-center"]')
  if [ "$rcc" != '{"ref":"regolith/51","source":"https://github.com/regolith-linux/regolith-control-center.git"}' ]; then
    echo "FAIL: $stage: regolith-control-center is $rcc, expected regolith/51 (GNOME 51)"
    fail=1
  fi

  [ $fail -eq 0 ] && echo "ok: $stage/ubuntu/stonking"
done

exit $fail
