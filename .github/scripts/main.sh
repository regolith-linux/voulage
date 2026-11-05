#!/bin/bash
set -e

# Succeeds if commit_id, a full commit id, is the id of a commit in source.
# The commit is fetched by its id into a scratch repository, so that a commit
# no branch or tag points to directly is found too, and a tree, a blob or a tag
# object with that id is told apart from a commit.
source_has_commit() {
  local source="$1"
  local commit_id="$2"
  local object_format="sha1"
  local scratch
  local object_type=""

  if [ ${#commit_id} -eq 64 ]; then
    object_format="sha256"
  fi

  scratch=$(mktemp -d) || return 1
  if git init -q --bare --template= --object-format="$object_format" "$scratch" >/dev/null 2>&1 &&
    git --git-dir="$scratch" -c protocol.version=2 fetch -q --depth=1 --no-tags "$source" "$commit_id" >/dev/null 2>&1; then
    object_type=$(git --git-dir="$scratch" cat-file -t "$commit_id" 2>/dev/null) || object_type=""
  fi
  rm -rf "$scratch"

  [ "$object_type" == "commit" ]
}

# Print the commit id that ref names in source. ref is the exact full name of
# a branch (refs/heads/<ref>) or a tag (refs/tags/<ref>); an annotated tag is
# followed to its commit. Otherwise ref may be the full id of a commit of
# source, which is printed as is. Fails, with an error on stderr, if the source
# can't be listed, if both a branch and a tag have that name, if no branch,
# tag or commit has it, or if the tag leads to a tree or a blob, not a commit.
resolve_package_ref() {
  local name="$1"
  local source="$2"
  local ref="$3"
  local remote_refs
  local result

  # ls-remote matches its patterns against the tail of each ref name, so it
  # may also list e.g. refs/heads/feature/<ref>. Only exact names are kept below.
  # "<tag>^{}" lists the object an annotated tag (or a tag of a tag) leads to.
  if ! remote_refs=$(git ls-remote "$source" "refs/heads/$ref" "refs/tags/$ref" "refs/tags/$ref^{}"); then
    echo "Error: package $name: cannot list refs of source $source to resolve ref $ref" >&2
    return 1
  fi

  result=$(printf '%s\n' "$remote_refs" | REF="$ref" awk '
    BEGIN { head = "refs/heads/" ENVIRON["REF"]; tag = "refs/tags/" ENVIRON["REF"] }
    $2 == head { branch_commit = $1 }
    $2 == tag { tag_object = $1 }
    $2 == tag "^{}" { tag_commit = $1 }
    END {
      if (branch_commit != "" && tag_object != "") { print "ambiguous"; exit }
      if (branch_commit != "") { print "commit " branch_commit; exit }
      if (tag_commit != "") { print "tag " tag_commit; exit }
      if (tag_object != "") { print "tag " tag_object; exit }
      print "missing"
    }')

  # Not a branch or tag name: a full commit id (abbreviated ids are not) of
  # the source is its own commit.
  if [ "$result" == "missing" ] && [[ "$ref" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] &&
    source_has_commit "$source" "$ref"; then
    result="commit $ref"
  fi

  # A tag may point to a tree or a blob: only a commit is a valid result.
  if [[ "$result" == "tag "* ]]; then
    if source_has_commit "$source" "${result#tag }"; then
      result="commit ${result#tag }"
    else
      echo "Error: package $name: tag $ref in $source does not point to a commit" >&2
      return 1
    fi
  fi

  case "$result" in
    "commit "*)
      echo "${result#commit }"
      ;;
    ambiguous)
      echo "Error: package $name: ref $ref names both a branch and a tag in $source" >&2
      return 1
      ;;
    *)
      echo "Error: package $name: no branch, tag or commit $ref in $source" >&2
      return 1
      ;;
  esac
}

# Emit manifest entry line for package
handle_package() {
  local commit_hash

  if ! commit_hash=$(resolve_package_ref "$PACKAGE_NAME" "$PACKAGE_SOURCE_URL" "$PACKAGE_SOURCE_REF"); then
    return 1
  fi

  echo "$PACKAGE_NAME $PACKAGE_SOURCE_URL $PACKAGE_SOURCE_REF $commit_hash" >> "$NEXT_MANIFEST_FILE"

  echo "Updated manifest $NEXT_MANIFEST_FILE for package $PACKAGE_NAME"
}

# Traverse each package in the model and call handle_package
traverse_package_model() {
  local package_names
  local package
  local failed_packages=()

  echo "::group::Updating next manifest file"
  package_names=$(jq -rc 'delpaths([path(.[][]| select(.==null))]) | .packages | keys | .[]' < "$PACKAGE_MODEL_FILE")

  # Not a pipeline: a failure has to reach this shell, not a subshell.
  while IFS='' read -r package; do
    if [ -z "$package" ]; then
      continue
    fi

    # Set the package name and model desc
    PACKAGE_NAME="$package"

    # If a package filter was specified, match filter.
    if [[ -n "$PACKAGE_FILTER" && "$PACKAGE_FILTER" != "$PACKAGE_NAME" ]]; then
        continue
    fi

    if [ -n "$ONLY_PACKAGE" ] && [ "$PACKAGE_NAME" != "$ONLY_PACKAGE" ]; then
      continue
    fi

    PACKAGE_SOURCE_URL=$(jq -r --arg package "$package" '.packages[$package].source' < "$PACKAGE_MODEL_FILE")
    PACKAGE_SOURCE_REF=$(jq -r --arg package "$package" '.packages[$package].ref' < "$PACKAGE_MODEL_FILE")

    # Apply functions to package model
    if ! handle_package; then
      failed_packages+=("$PACKAGE_NAME")
    fi
  done <<< "$package_names"
  echo "::endgroup::"

  if [ ${#failed_packages[@]} -gt 0 ]; then
    rm -f "$NEXT_MANIFEST_FILE"
    echo -e "\033[0;31mError: could not resolve the ref of package(s): ${failed_packages[*]}, aborting.\033[0m" >&2
    exit 1
  fi
}

# Generate a json file from a root and any additions in each level of the stage tree
merge_models() {
  echo "::group::Merging model files"
  if [ ! -f "$ROOT_MODEL_PATH" ]; then
    echo -e "\033[0;31mInvalid root model path: $ROOT_MODEL_PATH\033[0m"
    exit 1
  fi

  if [ ! -d "$MANIFEST_PATH" ]; then
    mkdir -p "$MANIFEST_PATH"
  fi

  # Copy root model to build dir
  WORKING_ROOT_MODEL="$MANIFEST_PATH/root-model.json"
  cp "$ROOT_MODEL_PATH" "$WORKING_ROOT_MODEL"

  # Optionally merge stage package model
  STAGE_PACKAGE_MODEL="$GIT_REPO_PATH/stage/$STAGE/package-model.json"
  WORKING_STAGE_MODEL="$MANIFEST_PATH/$STAGE-model.json"
  if [ -f "$STAGE_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_ROOT_MODEL" "$STAGE_PACKAGE_MODEL" > "$WORKING_STAGE_MODEL"
  else
    cp "$WORKING_ROOT_MODEL" "$WORKING_STAGE_MODEL"
  fi

  # Optionally merge distro package model
  DISTRO_PACKAGE_MODEL="$GIT_REPO_PATH/stage/$STAGE/$DISTRO/package-model.json"
  WORKING_DISTRO_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-model.json"
  if [ -f "$DISTRO_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_STAGE_MODEL" "$DISTRO_PACKAGE_MODEL" > "$WORKING_DISTRO_MODEL"
  else
    cp "$WORKING_STAGE_MODEL" "$WORKING_DISTRO_MODEL"
  fi

  # Optionally merge codename package model
  CODENAME_PACKAGE_MODEL="$GIT_REPO_PATH/stage/$STAGE/$DISTRO/$CODENAME/package-model.json"
  WORKING_CODENAME_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-$CODENAME-model.json"
  if [ -f "$CODENAME_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_DISTRO_MODEL" "$CODENAME_PACKAGE_MODEL" > "$WORKING_CODENAME_MODEL"
  else
    cp "$WORKING_DISTRO_MODEL" "$WORKING_CODENAME_MODEL"
  fi

  # Optionally merge arch package model
  ARCH_PACKAGE_MODEL="$GIT_REPO_PATH/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/package-model.json"
  WORKING_ARCH_MODEL="$MANIFEST_PATH/$STAGE-$DISTRO-$CODENAME-$ARCH-model.json"
  if [ -f "$ARCH_PACKAGE_MODEL" ]; then
    jq -s '.[0] * .[1]' "$WORKING_CODENAME_MODEL" "$ARCH_PACKAGE_MODEL" > "$WORKING_ARCH_MODEL"
  else
    cp "$WORKING_CODENAME_MODEL" "$WORKING_ARCH_MODEL"
  fi

  PACKAGE_MODEL_FILE="$WORKING_ARCH_MODEL"

  echo -e "\033[0;34mMerged package model:\033[0m"
  cat "$PACKAGE_MODEL_FILE"
  echo "::endgroup::"
}

# Traverse the stage tree and execute any found setup.sh scripts
source_setup_scripts() {
  local setup_script_locations=(
    "$GIT_REPO_PATH/stage/setup.sh"
    "$GIT_REPO_PATH/stage/$STAGE/setup.sh"
    "$GIT_REPO_PATH/stage/$STAGE/$DISTRO/setup.sh"
    "$GIT_REPO_PATH/stage/$STAGE/$DISTRO/$CODENAME/setup.sh"
    "$GIT_REPO_PATH/stage/$STAGE/$DISTRO/$CODENAME/$ARCH/setup.sh"
  )

  for setup_file in "${setup_script_locations[@]}"
  do
    if [ -f "$setup_file" ]; then
      echo "Executing setup file $setup_file..."
      source "$setup_file"
    fi
  done
}

build_packages() {
  echo "::group::Package set to build"
  echo -e "$PACKAGE_CHANGES"  
  echo "::endgroup::"

  while IFS= read -r PKG_LINE; do
    # echo "Debug line is $PKG_LINE"

    PACKAGE_NAME=$(echo "$PKG_LINE" | cut -d" " -f1)
    PACKAGE_URL=$(echo "$PKG_LINE" | cut -d" " -f2)
    PACKAGE_REF=$(echo "$PKG_LINE" | cut -d" " -f3)

    if [ -n "$ONLY_PACKAGE" ] && [ "$PACKAGE_NAME" != "$ONLY_PACKAGE" ]; then
      continue
    fi

    echo -e "\033[0;34mBuilding package $PACKAGE_NAME from $PACKAGE_URL with ref $PACKAGE_REF\033[0m"

    checkout
    update_changelog
    if dist_valid; then
      stage_source
      build_src_package
      build_bin_package
      publish
    else
      echo "dist codename does not match in package changelog, ignoring $PACKAGE_NAME."
    fi
  done <<< "$PACKAGE_CHANGES"

  echo "Completed building packages: $PACKAGE_CHANGES"
}

update_manifest_file() {
  while IFS= read -r line; do
    pkg_name=$(echo "$line" | cut -d" " -f1)
    pkg_repo=$(echo "$line" | cut -d" " -f2)
    pkg_ref=$(echo "$line" | cut -d" " -f3)
    pkg_sha=$(echo "$line" | cut -d" " -f4)

    if ! grep "^${pkg_name} " "$PREV_MANIFEST_FILE" >/dev/null; then
      echo "${pkg_name} ${pkg_repo} ${pkg_ref} ${pkg_sha}" >> "$PREV_MANIFEST_FILE"
    fi
    sed -i -E "s|^${pkg_name}[[:space:]](.*)$|${pkg_name} ${pkg_repo} ${pkg_ref} ${pkg_sha}|g" "$PREV_MANIFEST_FILE"
  done < "$NEXT_MANIFEST_FILE"

  # always sort the file
  sort -o "$PREV_MANIFEST_FILE" "$PREV_MANIFEST_FILE"

  # cleanup temporary manifest tile
  rm "$NEXT_MANIFEST_FILE"
}

#### Init input params

usage() {
cat << EOF
Build debian and source packages for given combination of: distro, codename, stage and arch

Usage: $0 [options...] COMMAND

Commands:                                                                                                           
  build    Build the requested debian and source packages
  check    Check the manifests if anything needs to be built

Options:
  --extension <path>         Path to extension file (e.g. /path/to/ext-debian.sh)

  --git-repo-path <path>     Path to repo folder (e.g. /path/to/git/repo/voulage)
  --manifest-path <path>     Path to manifests folder (e.g. /path/to/manifests)
  --pkg-build-path <path>    Path to folder to build packages in (e.g. /path/to/packages)
  --pkg-publish-path <path>  Path to folder to publish packages in (e.g. /path/to/publish)

  --distro <name>            The distro to check or build (e.g. ubuntu, debian)
  --codename <name>          The codename to check or build (e.g. jammy, noble, bookworm, etc.)
  --stage <name>             The stage to check or build (e.g. experimental, unstable, testing, backports, release-x_Y) # different release stages from github action point-of-view
  --suite <name>             The suite to check or build (e.g. experimental, unstable, testing, backports, stable)      # corresponding value from published archives point-of-view
  --component <name>         The component to check or build (e.g. main, 3.2, 3.1, etc.)
  --arch <name>              The arch to check or build (e.g. amd64, arm64)

  --only-package <name>      Only check or build this package (optional)

  --help                     Show this message

Note: all the options except --only-package are required when using $0
EOF
}

parse_flag() {
  declare -n argument=$3

  if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
    argument=$2
    return
  fi

  if [ "$1" == "--only-package" ]; then
    return
  fi

  echo "Error: argument for $1 is missing" >&2
  exit 1
}

MODE=""              # build, check
EXTENSION=""         # e.g. /path/to/ext-debian.sh

GIT_REPO_PATH=""     # e.g. /path/to/git/repo/voulage
MANIFEST_PATH=""     # e.g. /path/to/manifests
PKG_BUILD_PATH=""    # e.g. /path/to/packages
PKG_PUBLISH_PATH=""  # e.g. /path/to/publish

DISTRO=""            # ubuntu, debian
CODENAME=""          # e.g. jammy, noble, bookworm, etc
STAGE=""             # experimental, unstable, testing, backports, release-x_y (different release stages from github action point-of-view)
SUITE=""             # experimental, unstable, testing, backports, stable      (corresponding value from published archives point-of-view)
COMPONENT=""         # e.g. main, 3.2, 3.1, etc.
ARCH=""              # amd64, arm64

ONLY_PACKAGE=""      # only build this package

LOCAL_BUILD="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    build|check)         MODE="$1"; shift; ;;
    --extension)         parse_flag "$1" "$2" EXTENSION; shift 2 ;;

    --git-repo-path)     parse_flag "$1" "$2" GIT_REPO_PATH; shift 2 ;;
    --manifest-path)     parse_flag "$1" "$2" MANIFEST_PATH; shift 2 ;;
    --pkg-build-path)    parse_flag "$1" "$2" PKG_BUILD_PATH; shift 2 ;;
    --pkg-publish-path)  parse_flag "$1" "$2" PKG_PUBLISH_PATH; shift 2 ;;

    --distro)            parse_flag "$1" "$2" DISTRO; shift 2 ;;
    --codename)          parse_flag "$1" "$2" CODENAME; shift 2 ;;
    --stage)             parse_flag "$1" "$2" STAGE; shift 2 ;;
    --suite)             parse_flag "$1" "$2" SUITE; shift 2 ;;
    --component)         parse_flag "$1" "$2" COMPONENT; shift 2 ;;
    --arch)              parse_flag "$1" "$2" ARCH; shift 2 ;;

    --only-package)
      parse_flag "$1" "$2" ONLY_PACKAGE
      if [ -z "$2" ]; then
        shift 2
      else
        if [ ${2:0:1} != "-" ]; then
          shift 2
        else
          shift 1
        fi
      fi
      ;;

    -h|--help)           usage; exit 0; ;;
    -*|--*)              echo "Unknown option $1"; exit 1;  ;;
    *)                   echo "Unknown command $1"; exit 1; ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Error: command is missing"
  exit 1
fi
if [ -z "$EXTENSION" ]; then
  echo "Error: required value for --extension is missing"
  exit 1
fi

if [ -z "$GIT_REPO_PATH" ]; then
  echo "Error: required value for --git-repo-path is missing"
  exit 1
else
  GIT_REPO_PATH=$(realpath "$GIT_REPO_PATH")
fi
if [ -z "$MANIFEST_PATH" ]; then
  echo "Error: required value for --manifest-path is missing"
  exit 1
fi
if [ -z "$PKG_BUILD_PATH" ]; then
  echo "Error: required value for --pkg-build-path is missing"
  exit 1
fi
if [ -z "$PKG_PUBLISH_PATH" ]; then
  echo "Error: required value for --pkg-publish-path is missing"
  exit 1
fi

if [ -z "$DISTRO" ]; then
  echo "Error: required value for --distro is missing"
  exit 1
fi
if [ -z "$CODENAME" ]; then
  echo "Error: required value for --codename is missing"
  exit 1
fi
if [ -z "$STAGE" ]; then
  echo "Error: required value for --stage is missing"
  exit 1
fi
if [ -z "$SUITE" ]; then
  echo "Error: required value for --suite is missing"
  exit 1
fi
if [ -z "$COMPONENT" ]; then
  echo "Error: required value for --component is missing"
  exit 1
fi
if [[ "${COMPONENT:0:1}" == "v" ]]; then
  COMPONENT="${COMPONENT:1}"
fi
if [ -z "$ARCH" ]; then
  echo "Error: required value for --arch is missing"
  exit 1
fi

#### Get extensions

GIT_EXT="$GIT_REPO_PATH/.github/scripts/ext-git.sh"
if [ ! -f "$GIT_EXT" ]; then
  echo "Error: extension $GIT_EXT doesn't exist, aborting."
  exit 1
else 
  source $GIT_EXT
fi

if [ ! -f "$EXTENSION" ]; then
  echo "Error: extension $EXTENSION doesn't exist, aborting."
  exit 1
else 
  source $EXTENSION
fi

#### Init globals

ROOT_MODEL_PATH="$GIT_REPO_PATH/stage/package-model.json"

#### Setup files

# Only build mode works in the package build and publish dirs. Check mode
# leaves them as they are, and doesn't create them.
if [ "$MODE" == "build" ]; then
  if [ -d "$PKG_BUILD_PATH" ]; then
    echo -e "\033[0;34mDeleting pre-existing package build dir $PKG_BUILD_PATH\033[0m"
    rm -Rf "$PKG_BUILD_PATH"
  fi

  if [ -d "$PKG_PUBLISH_PATH" ]; then
    echo -e "\033[0;34mDeleting pre-existing package publish dir $PKG_PUBLISH_PATH\033[0m"
    rm -Rf "$PKG_PUBLISH_PATH"
  fi

  if [ ! -d "$PKG_PUBLISH_PATH" ]; then
    mkdir -p "$PKG_PUBLISH_PATH"
  fi
fi

if [ ! -d "$MANIFEST_PATH" ]; then
  mkdir -p "$MANIFEST_PATH"
fi

#### Generate Manifest from package model tree and git repo state

PREV_MANIFEST_FILE="$MANIFEST_PATH/manifest.txt"
NEXT_MANIFEST_FILE="$MANIFEST_PATH/next-manifest.txt"

# Create prev manifest if doesn't exist (first run)
if [ ! -f "$PREV_MANIFEST_FILE" ]; then
  touch "$PREV_MANIFEST_FILE"
fi

# Delete pre-existing manifest before generating new
if [ -f "$NEXT_MANIFEST_FILE" ]; then
  mv "$NEXT_MANIFEST_FILE" "$MANIFEST_PATH/prev-manifest.txt"
  echo -e "\033[0;34mMoved pre-existing manifest file $NEXT_MANIFEST_FILE to $MANIFEST_PATH/prev-manifest.txt\033[0m"
fi

# Merge models across stage, distro, codename, arch
merge_models

# Iterate over each package in the model and call handle_package
traverse_package_model

#### Find packages that need to be built
echo "::group::Looking for changed package"
# make sure these two files are always sorted
sort -o "$PREV_MANIFEST_FILE" "$PREV_MANIFEST_FILE"
sort -o "$NEXT_MANIFEST_FILE" "$NEXT_MANIFEST_FILE"

echo -e "\033[0;34mDiffing $PREV_MANIFEST_FILE $NEXT_MANIFEST_FILE\033[0m"
PACKAGE_CHANGES=$(diff "$PREV_MANIFEST_FILE" "$NEXT_MANIFEST_FILE" | grep '^[>][^>]' | cut -c3- | uniq | sort)
echo "$PACKAGE_CHANGES"
echo "::endgroup::"

if [ -z "$PACKAGE_CHANGES" ]; then
  echo "No package changes found, exiting."
  exit 0
fi

if [ "$MODE" == "build" ]; then
  #### Build packages

  setup
  build_packages

  #### Cleanup

  archive_cleanup_scripts

  #### Update Manifests

  update_manifest_file
else
  echo "$PACKAGE_CHANGES"
fi
