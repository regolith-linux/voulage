#!/bin/bash

set -e
set -o errexit

PWD="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(realpath "$PWD/../../")"
CHANGELOG_SCRIPT="$PWD/gen-changelog-table.sh"

usage() {
    cat <<'USAGE'
Usage: gen-next-release-changelog.sh [gen-changelog-table flags]

Generates changelogs for every leaf target in stage/testing compared to the
latest release-* stage.

Examples:
  gen-next-release-changelog.sh --include-merge
  gen-next-release-changelog.sh --verbose
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

if [ ! -x "$CHANGELOG_SCRIPT" ]; then
    echo "error: missing $CHANGELOG_SCRIPT"
    exit 1
fi

latest_release=$(
    find "$REPO_ROOT/stage" -maxdepth 1 -type d -name 'release-*' -printf '%f\n' |
        awk '{ver=$0; sub(/^release-/, "", ver); gsub(/_/, ".", ver); printf "%s %s\n", $0, ver }' |
        sort -k2,2V |
        tail -n1 |
        awk '{print $1}'
)

if [ -z "$latest_release" ]; then
    echo "error: no release-* stages found under $REPO_ROOT/stage"
    exit 1
fi

targets=()
while IFS= read -r model_file; do
    target_dir="$(dirname "$model_file")"
    if ! find "$target_dir" -mindepth 2 -type f -name package-model.json -print -quit | grep -q .; then
        target_rel="${target_dir#$REPO_ROOT/stage/}"
        targets+=("$target_rel")
    fi
done < <(find "$REPO_ROOT/stage/testing" -type f -name package-model.json | sort)

if [ "${#targets[@]}" -eq 0 ]; then
    echo "error: no leaf targets found under $REPO_ROOT/stage/testing"
    exit 1
fi

for target in "${targets[@]}"; do
    from_stage="$latest_release/${target#testing/}"
    from_dir="$REPO_ROOT/stage/$from_stage"
    to_dir="$REPO_ROOT/stage/$target"
    if [ ! -d "$from_dir" ] || [ ! -d "$to_dir" ]; then
        continue
    fi
    "$CHANGELOG_SCRIPT" "$@" "$from_stage" "$target"
    echo ""
done
