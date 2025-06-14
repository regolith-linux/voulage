#!/bin/bash

PWD="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(realpath "$PWD/../../")"

model_file="$REPO_ROOT/stage/unstable/package-model.json"

echo "| Package⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀| Unstable | Testing |" >> tmp.md
echo "|-------------------------------|----------|---------|" >> tmp.md

while IFS='' read -r package; do
    package_name="$package"
    package_repo=$(jq -r ".packages.\"$package\".source" "$model_file" | sed -e 's/\.git$//g')
    package_ref=$(jq -r ".packages.\"$package\".ref" "$model_file")

    unstable_status="[![Publish to Unstable]($package_repo/actions/workflows/publish-unstable.yml/badge.svg)]($package_repo/actions/workflows/publish-unstable.yml)"
    testing_status="[![Publish to Unstable]($package_repo/actions/workflows/publish-testing.yml/badge.svg)]($package_repo/actions/workflows/publish-testing.yml)"

    # append table row to repository temp file
    echo "| $package_name | $unstable_status | $testing_status |" >> tmp.md
done < <(jq -rc 'delpaths([path(.[][]| select(.==null))]) | .packages | keys | .[]' "$model_file")

# update repository README
sed -i -ne '/<!-- AUTO_GENERATE_START -->/ {p; r tmp.md' -e ':a; n; /<!-- AUTO_GENERATE_END -->/ {p; b}; ba}; p' "$REPO_ROOT/README.md"

# cleanup repository temp file
rm -f tmp.md