#!/bin/bash

set -e
set -o errexit

PWD="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(realpath "$PWD/../../")"

skip_chore=true
skip_merge=true
verbose=false

usage() {
    echo "Usage: $0 [--include-chore] [--include-merge] [--verbose] <from-stage> <to-stage>"
    echo "  Stage format: stage/distro/codename (e.g. testing/debian/bookworm)"
    exit 1
}

vprint() {
    if $verbose; then
        echo "$@"
    fi
}

# parse flags and stage arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-chore)
            # retained for backward compatibility; chores are skipped by default
            skip_chore=true
            shift
            ;;
        --skip-merge)
            # retained for backward compatibility; merges are skipped by default
            skip_merge=true
            shift
            ;;
        --include-chore)
            skip_chore=false
            shift
            ;;
        --include-merge)
            skip_merge=false
            shift
            ;;
        --verbose|-v)
            verbose=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            FROM_STAGE="$1"
            shift
            break
            ;;
    esac
done

[ -n "${FROM_STAGE:-}" ] || usage

TO_STAGE="${1:-}"
shift || true
[ -n "$TO_STAGE" ] || usage

[ $# -eq 0 ] || usage

FROM_STAGE="${FROM_STAGE%/}"
TO_STAGE="${TO_STAGE%/}"

if [[ "$FROM_STAGE" == /* || "$FROM_STAGE" == *".."* || "$FROM_STAGE" == *"//"* ]]; then
    echo "error: invalid from-stage path \"$FROM_STAGE\""
    exit 1
fi
if [[ "$TO_STAGE" == /* || "$TO_STAGE" == *".."* || "$TO_STAGE" == *"//"* ]]; then
    echo "error: invalid to-stage path \"$TO_STAGE\""
    exit 1
fi

to_stage_name="${TO_STAGE%%/*}"

if [ "$to_stage_name" = "unstable" ]; then
    echo "error: cannot generate changelog for unstable stage"
    exit 1
fi

if [ "$to_stage_name" = "testing" ]; then
    :
elif [[ "$to_stage_name" == release-* ]]; then
    :
else
    echo "error: stage must be testing or a release-* stage"
    exit 1
fi

resolve_ref() {
    local ref="$1"
    if git rev-parse --quiet --verify "$ref" >/dev/null; then
        echo "$ref"
        return 0
    fi
    if git rev-parse --quiet --verify "origin/$ref" >/dev/null; then
        echo "origin/$ref"
        return 0
    fi
    return 1
}

tmp_dir=$(mktemp -d /tmp/changelog-XXXXXX)
pushd "$tmp_dir" >/dev/null || exit 1
trap 'popd >/dev/null 2>&1; rm -rf "$tmp_dir"' EXIT

merge_model_tree() {
    local stage_path="$1"
    local output_file="$2"
    local stage_root="$REPO_ROOT/stage"
    local target_dir="$stage_root/$stage_path"

    if [ ! -d "$target_dir" ]; then
        echo "error: missing stage directory $target_dir"
        exit 1
    fi
    if [ ! -f "$target_dir/package-model.json" ]; then
        echo "error: missing model file $target_dir/package-model.json"
        exit 1
    fi

    if [ -f "$target_dir/package-model.json" ]; then
        local model_file="${target_dir}/package-model.json"
        cp "$model_file" "$output_file"
        jq -s '.[0] * .[1]' "$output_file" "$model_file" > "${output_file}.tmp"
        mv "${output_file}.tmp" "$output_file"
    fi
}

from_model_file="$tmp_dir/from-model.json"
to_model_file="$tmp_dir/to-model.json"

merge_model_tree "$FROM_STAGE" "$from_model_file"
merge_model_tree "$TO_STAGE" "$to_model_file"

output_target="stdout"
if [ -t 1 ]; then
    output_target="stdout"
else
    output_target="$(readlink -f "/proc/$$/fd/1" 2>/dev/null || echo "stdout")"
fi
vprint "writing changelog to $output_target"

target_label="${TO_STAGE#*/}"
target_label="${target_label//\// }"
from_label="${FROM_STAGE%%/*}"
echo "## Changes in \`$target_label\` since Regolith \`$from_label\`"
echo ""

while IFS='' read -r package; do
    package_name="$package"
    package_repo=$(jq -r ".packages.\"$package\".source" "$to_model_file" | sed -e 's/\.git$//g')
    to_ref=$(jq -r ".packages.\"$package\".ref" "$to_model_file")
    from_ref=$(jq -r ".packages.\"$package\".ref // empty" "$from_model_file")

    if [ -z "$from_ref" ] || [ "$from_ref" = "null" ]; then
        vprint "skipping $package_name: no ref in stage $FROM_STAGE"
        continue
    fi

    vprint "processing $package_name ($package_repo): $from_ref -> $to_ref"

    git clone --filter=blob:none --no-checkout "${package_repo}.git" "$package_name" >/dev/null 2>&1 || {
        echo "failed to clone ${package_repo}.git"
        continue
    }
    pushd "$package_name" >/dev/null || continue

    resolved_from_ref="$(resolve_ref "$from_ref" || true)"
    resolved_to_ref="$(resolve_ref "$to_ref" || true)"

    if [ -z "$resolved_from_ref" ] || [ -z "$resolved_to_ref" ]; then
        vprint "skipping $package_name: unable to resolve refs ($from_ref -> $to_ref)"
        popd >/dev/null
        continue
    fi

    log_args=(log "${resolved_from_ref}..${resolved_to_ref}")
    $skip_merge && log_args+=(--no-merges)
    log_args+=(--pretty=format:'%h%x09%s')
    commit_log=$(git "${log_args[@]}")
    filtered_commit_log=""

    while IFS=$'\t' read -r commit_hash commit_subject; do
        if [ -z "$commit_hash" ] || [ -z "$commit_subject" ]; then
            continue
        fi
        if ! [[ $commit_hash =~ ^[0-9a-fA-F]{7,40}$ ]]; then
            continue
        fi
        if $skip_chore && [[ $commit_subject == chore:* ]]; then
            continue
        fi
        if $skip_merge && [[ $commit_subject == Merge* ]]; then
            continue
        fi
        filtered_commit_log+="$commit_hash $commit_subject"$'\n'
    done <<< "$commit_log"

    if [ -n "$filtered_commit_log" ]; then
        compare_ref="${from_ref}...${to_ref}"
        echo "### Changes in [\`$package_name\`](${package_repo}/releases/${to_ref})"
        echo ""
        echo "\`\`\`text"
        printf "%s" "$filtered_commit_log"
        echo "\`\`\`"
        echo ""
    fi

    popd >/dev/null
done < <(jq -rc 'delpaths([path(.[][]| select(.==null))]) | .packages | keys | .[]' "$to_model_file")
