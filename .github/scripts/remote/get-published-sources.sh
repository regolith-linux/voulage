#!/usr/bin/env bash
#
# Get debian.tar.xz source files from published folder from generated sourcelog

set -e

main() {
  for sourcelog in $(find "$FULL_WORKSPACE_PATH" -mindepth 1 -maxdepth 1 -type f -name "SOURCELOG_*.txt" | sort); do
    process_dist=$(echo "$sourcelog" | cut -d"_" -f3)
    process_code=$(echo "$sourcelog" | cut -d"_" -f4)
    process_comp=$(echo "$sourcelog" | cut -d"_" -f2)

    echo -e "\033[0;34mFind published sources in $process_comp $process_dist/$process_code:\033[0m"

    while IFS= read -r line; do
      distro=$(echo "$line" | cut -d"=" -f1)        # debian, ubuntu
      codename=$(echo "$line" | cut -d"=" -f2)      # jammy, noble, bookworm, etc
      component=$(echo "$line" | cut -d"=" -f3)     # 3.2, 3.1, experimental, unstable, testing, backports, stable, etc
      first_letter=$(echo "$line" | cut -d"=" -f4)
      package_name=$(echo "$line" | cut -d"=" -f5)
      full_version=$(echo "$line" | cut -d"=" -f6)
      orig_tar_file=$(echo "$line" | cut -d"=" -f7)

      echo "::group::Processing $orig_tar_file"

      if [ ! -f "$FULL_PACKAGES_PATH/$distro/$codename/$component/$orig_tar_file" ]; then
        echo "Skipping. $distro/$codename/$component/$orig_tar_file not found in packages folder."
        echo "::endgroup::"

        continue
      fi

      if [ -d "$FULL_WORKSPACE_PATH/$distro/$codename/$component" ]; then
        if [ -s "$FULL_WORKSPACE_PATH/$distro/$codename/$component/$orig_tar_file" ]; then
          echo "Skipping. $distro/$codename/$component/$orig_tar_file is already processed via another codename."
          echo "::endgroup::"

          continue
        fi
      fi

      publish_suite=""     # experimental, unstable, testing, backports
      publish_component="" # main, 3.2, 3.1, etc.

      if [[ $component == *"."* ]]; then
        publish_suite="stable"
        publish_component="v$component"
      else
        publish_suite="$component"
        publish_component="main"
      fi

      # copy .debian.tar.xz file from published/ to packages/ folder (we have to rebuild them)
      echo "Looking for existing .debian.tar.xz files in $distro/$publish_suite/public/pool/$publish_component/$first_letter/$package_name/ ..."
      lookup_folder="$PUBLISHED_PATH/$distro/$publish_suite/public/pool/$publish_component/$first_letter/$package_name/"

      new_version_detected="true"

      for existing_file in $(find "$lookup_folder" -name "$full_version-*.debian.tar.xz"); do
        new_version_detected="false"

        filename=$(basename "$existing_file")
        target_codename=$(echo "$filename" | sed "s/"$full_version"//g" | sed "s/-//g" | cut -d"." -f1)

        echo ""
        echo "Found $filename"

        mkdir -p "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component"

        # copy .debian.tar.xz from published to package folder to be rebuilt
        if [ ! -f "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component/$filename" ]; then
          echo "Copying $filename to $distro/$target_codename/$component to be rebuilt"
          cp "$existing_file" "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component"
        else
          echo "File $filename already copied to $distro/$target_codename/$component"
        fi

        # copy this .orig.tar.gz file to package folder to be used for rebuilding
        if [ ! -f "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component/$orig_tar_file" ]; then
          # always copy from publish_suite (i.e. for versions, this is always copying from stable)
          echo "Copying $orig_tar_file to $distro/$target_codename/$publish_suite for reference"
          cp "$FULL_PACKAGES_PATH/$distro/$codename/$publish_suite/$orig_tar_file" "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component"
        else
          echo "file $orig_tar_file already copied to $distro/$target_codename/$component"
        fi
      done

      # this means it's a new package and we have to rebuild it for all codenames anyway
      if [ "$new_version_detected" == "true" ]; then
        pushd "$FULL_PACKAGES_PATH/$distro" >/dev/null

        for new_file in $(find . -name "$full_version-*.debian.tar.xz" | grep "$component" | grep -v "$codename" | sort); do
          filename=$(basename "$new_file")
          target_codename=$(echo "$filename" | sed "s/"$full_version"//g" | sed "s/-//g" | cut -d"." -f1)

          echo ""
          echo "Found $filename"

          mkdir -p "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component"

          # copy .debian.tar.xz from published to package folder to be rebuilt
          if [ ! -f "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component/$filename" ]; then
            echo "Copying $filename to $distro/$target_codename/$component to be rebuilt"
            cp "$new_file" "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component"
          else
            echo "File $filename already copied to $distro/$target_codename/$component"
          fi

          # copy this .orig.tar.gz file to package folder to be used for rebuilding
          if [ ! -f "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component/$orig_tar_file" ]; then
            # always copy from publish_suite (i.e. for versions, this is always copying from stable)
            echo "Copying $orig_tar_file to $distro/$target_codename/$publish_suite for reference"
            cp "$FULL_PACKAGES_PATH/$distro/$codename/$publish_suite/$orig_tar_file" "$FULL_WORKSPACE_PATH/$distro/$target_codename/$component"
          else
            echo "File $orig_tar_file already copied to $distro/$target_codename/$component"
          fi
        done

        popd >/dev/null
      fi

      echo "::endgroup::"
    done < "$sourcelog"
  done
}

usage() {
cat << EOF
Get debian.tar.xz source files from published folder from generated sourcelog

Usage: $0 --workspace-path <PATH>

Options:
  --workspace-path <path>    Path to build package folder
  --workspace-folder <name>  Optional folder inside the workspace
  --help                     Show this message
EOF
}

parse_flag() {
  declare -n argument=$3

  if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
    #shellcheck disable=SC2086
    argument=$2
    return
  fi

  echo "Error: argument for $1 is missing" >&2
  exit 1
}

WORKSPACE_PATH=""   # e.g. /opt/archives/workspace/
WORKSPACE_FOLDER="" # e.g. voulage/
WORKSPACE_RUN_ID="" # e.g. run-13218767379/
PACKAGES_PATH=""
PUBLISHED_PATH=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --workspace-path)    parse_flag "$1" "$2" WORKSPACE_PATH; shift 2 ;;
    --workspace-folder)  parse_flag "$1" "$2" WORKSPACE_FOLDER; shift 2 ;;
    --workspace-run-id)  parse_flag "$1" "$2" WORKSPACE_RUN_ID; shift 2 ;;

    -h|--help)           usage; exit 0; ;;
    -*|--*)              echo "Unknown option $1"; exit 1;  ;;
    *)                   echo "Unknown command $1"; exit 1; ;;
esac
done

# workspace path
if [ -z "$WORKSPACE_PATH" ]; then
  echo "Error: required value for --workspace-path is missing"
  exit 1
fi
if [ -z "$WORKSPACE_FOLDER" ]; then
  echo "Error: required value for --workspace-folder is missing"
  exit 1
fi

if [ ! -d "$WORKSPACE_PATH" ]; then
  echo "Error: $WORKSPACE_PATH not found"
  exit 1
fi
WORKSPACE_PATH=$(realpath "$WORKSPACE_PATH")

# additional folder path inside workspace
FULL_WORKSPACE_PATH="${WORKSPACE_PATH%/}/${WORKSPACE_FOLDER%/}"

if [ -n "$WORKSPACE_RUN_ID" ]; then
  if [ ! -d "$FULL_WORKSPACE_PATH/$WORKSPACE_RUN_ID" ]; then
    echo "Error: $FULL_WORKSPACE_PATH/$WORKSPACE_RUN_ID not found"
    exit 1
  fi

  FULL_WORKSPACE_PATH+="/$WORKSPACE_RUN_ID"
fi

# packages path
PACKAGES_PATH="$(dirname "$WORKSPACE_PATH")/packages"
if [ ! -d "$PACKAGES_PATH" ]; then
  echo "Error: $PACKAGES_PATH not found"
  exit 1
fi

# additional folder path inside packages
FULL_PACKAGES_PATH="${PACKAGES_PATH%/}/${WORKSPACE_FOLDER%/}"
if [ -n "$WORKSPACE_RUN_ID" ]; then
  if [ ! -d "$FULL_PACKAGES_PATH/$WORKSPACE_RUN_ID" ]; then
    echo "Error: $FULL_PACKAGES_PATH/$WORKSPACE_RUN_ID not found"
    exit 1
  fi

  FULL_PACKAGES_PATH+="/$WORKSPACE_RUN_ID"
fi

# published path
PUBLISHED_PATH="$(dirname "$WORKSPACE_PATH")/published"
if [ ! -d "$PUBLISHED_PATH" ]; then
  echo "Error: $PUBLISHED_PATH not found"
  exit 1
fi

main
