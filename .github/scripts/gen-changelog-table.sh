#!/bin/bash

set -e
set -o errexit
# Generates release notes for the website

PWD="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(realpath "$PWD/../../")"

skip_chore=true
skip_merge=true
verbose=false

usage() {
    echo "Usage: $0 [--include-chore] [--include-merge] [--verbose] <stage>"
    exit 1
}

vprint() {
    if $verbose; then
        echo "$@"
    fi
}

# parse flags and stage argument
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
            STAGE="$1"
            shift
            break
            ;;
    esac
done

[ -n "$STAGE" ] || usage

model_file="$REPO_ROOT/stage/$STAGE/package-model.json"
start_date="05/18/2025"
end_date="12/13/2025"

tmp_dir=$(mktemp -d /tmp/changelog-XXXXXX)
pushd "$tmp_dir" >/dev/null || exit 1
trap 'popd >/dev/null 2>&1; rm -rf "$tmp_dir"' EXIT

# start a new changelog header for this run
echo "# Changelog for stage \"$STAGE\" ($start_date - $end_date)"

while IFS='' read -r package; do
    package_name="$package"
    package_repo=$(jq -r ".packages.\"$package\".source" "$model_file" | sed -e 's/\.git$//g')

    vprint "processing $package_name ($package_repo)"

    git clone --filter=blob:none --no-checkout "${package_repo}.git" "$package_name" >/dev/null 2>&1 || {
        echo "failed to clone ${package_repo}.git"
        continue
    }
    pushd "$package_name" >/dev/null || continue

    printed_repo_header=false

    # iterate over all refs (branches/tags) and collect commit logs in the date window
    while IFS='' read -r ref_name; do
        [ "$ref_name" = "origin/HEAD" ] && continue
        [ "$ref_name" = "origin" ] && continue

        log_args=(log "$ref_name")
        $skip_merge && log_args+=(--no-merges)
        log_args+=(--since "$start_date" --until "$end_date" --pretty=format:'%H%x09%s')
        commit_log=$(git "${log_args[@]}")
        filtered_commit_log=""

        while IFS=$'\t' read -r commit_hash commit_subject; do
            # guard against malformed lines or empty data
            if [ -z "$commit_hash" ] || [ -z "$commit_subject" ]; then
                continue
            fi
            # ensure commit hash looks like a SHA to avoid blank links
            if ! [[ $commit_hash =~ ^[0-9a-fA-F]{7,40}$ ]]; then
                continue
            fi

            if $skip_chore && [[ $commit_subject == chore:* ]]; then
                continue
            fi
            if $skip_merge && [[ $commit_subject == Merge* ]]; then
                continue
            fi
            filtered_commit_log+="- [$commit_subject](${package_repo}/commit/${commit_hash})"$'\n'
        done <<< "$commit_log"

        if [ -n "$filtered_commit_log" ]; then
            if [ "$printed_repo_header" = false ]; then
                echo "## [$package_name](${package_repo})"
                printed_repo_header=true
            fi
            display_ref="$ref_name"
            link_ref="$ref_name"
            if [[ "$ref_name" == origin/* ]]; then
                display_ref="${ref_name#origin/}"
                link_ref="$display_ref"
            fi
            echo "### [$display_ref](${package_repo}/tree/${link_ref})"
            printf "%s" "$filtered_commit_log"
            echo ""
        fi
    # only consider remote branches (no local branches)
    done < <(git for-each-ref --format='%(refname:short)' refs/remotes/origin)

    # finished processing this repository clone
    popd >/dev/null

    done < <(jq -rc 'delpaths([path(.[][]| select(.==null))]) | .packages | keys | .[]' "$model_file")
