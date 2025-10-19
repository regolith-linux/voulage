#!/bin/bash

PWD="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(realpath "$PWD/../../")"

TMP_PKG_FILE="$REPO_ROOT/tmp-packages.md"
TMP_SORTED_FILE="$REPO_ROOT/tmp-sorted.md"
TMP_RESULT_FILE="$REPO_ROOT/tmp-result.md"

rm -f "$TMP_PKG_FILE"
rm -f "$TMP_SORTED_FILE"
rm -f "$TMP_RESULT_FILE"

get_model() {
  # model_sub_path can be empty, or ends with a slash
  local model_sub_path=$1

  local unstable_stage_path="unstable/${model_sub_path}"
  local testing_stage_path="testing/${model_sub_path}"
  local unstable_model_file="stage/${unstable_stage_path%/}/package-model.json"
  local testing_model_file="stage/${testing_stage_path%/}/package-model.json"

  while IFS='' read -r package; do
    local package_name="$package"
    local package_repo=$(jq -r ".packages.\"$package\".source" "$unstable_model_file")
    local unstable_ref=$(jq -r ".packages.\"$package\".ref" "$unstable_model_file")
    local testing_ref=$(jq -rc 'delpaths([path(.[][]| select(.==null))]) | .packages["'$package_name'"].ref' "$testing_model_file")

    if [ "$testing_ref" == "null" ]; then
      testing_ref="n/a"
    fi
  
    echo "${package_name}!${package_repo}!${unstable_ref}!${testing_ref}" >> "$TMP_PKG_FILE"
  done < <(jq -rc 'delpaths([path(.[][]| select(.==null))]) | .packages | keys | .[]' "$unstable_model_file")
}

generate_table() {
  echo "| Package⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀| Unstable | Testing | Changelog | Need Release |" >> "$TMP_RESULT_FILE"
  echo "|:------------------------------|:---------|:--------|:----------|:-------------|" >> "$TMP_RESULT_FILE"

  while IFS='' read -r line; do
    package_name=$(echo "$line" | cut -d! -f1)
    package_repo=$(echo "$line" | cut -d! -f2 | sed -e 's/\.git$//g')
    unstable_ref=$(echo "$line" | cut -d! -f3)
    testing_ref=$(echo "$line" | cut -d! -f4)

    local tmp=$(mktemp -d)

    # entering /tmp/tmp.XXXXXXXXXX
    pushd $tmp >/dev/null
    git clone --recursive "${package_repo}.git" -b "$unstable_ref" "$package_name"
    cd "$package_name"

    local head_tag=$(git describe --tags --exact-match 2>&1>/dev/null || git describe --tags 2>&1>/dev/null | sed 's/'"$testing_ref"'//g')

    local release_needed="Yes"

    if [ -z "$head_tag" ]; then
      release_needed="No"
    fi

    if [ "$testing_ref" == "n/a" ]; then
      release_needed="No"
      head_tag="n/a"
    fi

    if [ "$release_needed" == "Yes" ]; then
      release_needed="[Yes](${package_repo}/compare/${testing_ref}...${unstable_ref})"
    fi

    if [ "$testing_ref" != "n/a" ]; then
      testing_ref="\`${testing_ref}\`"
    fi

    if [ -f "debian/changelog" ]; then
      changelog_distro=$(head -n 1 debian/changelog | cut -d' ' -f3 | sed 's/;//g')
    fi

    # existing /tmp/tmp.XXXXXXXXXX
    popd >/dev/null
    rm -rf "$tmp"

    # append table row to repository temp file
    echo "| [${package_name}](${package_repo}) | \`$unstable_ref\` | $testing_ref | \`$changelog_distro\` | $release_needed |" >> "$TMP_RESULT_FILE"
  done < <(cat "$TMP_SORTED_FILE")
}

main() {

  pushd "$REPO_ROOT" >/dev/null || exit 1

  # process package-models at stage root level
  get_model ""

  # process package-models at distro/codename level
  for dir in stage/unstable/*/*/; do
    distro=$(echo "$dir" | cut -d/ -f3)
    codename=$(echo "$dir" | cut -d/ -f4)

    get_model "$distro/$codename/"
  done

  cat "$TMP_PKG_FILE" | sort -V | uniq > "$TMP_SORTED_FILE"
  rm -f "$TMP_PKG_FILE"

  generate_table
  rm -f "$TMP_SORTED_FILE"

  popd >/dev/null || exit 1
}

main

# update repository README
sed -i -ne '/<!-- AUTO_GENERATE_START -->/ {p; r tmp-result.md' -e ':a; n; /<!-- AUTO_GENERATE_END -->/ {p; b}; ba}; p' "$REPO_ROOT/RELEASE_TRACKER.md"

# # cleanup repository temp file
rm -f "$TMP_RESULT_FILE"
