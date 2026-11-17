#!/usr/bin/env bash
#
# Cleanup Workspace folder.

set -e

is_allowed() {
  parent_path="$(dirname $WORKSPACE_PATH)"

  if [ ! -d "$parent_path/legacy" ]; then
    return 1
  fi
  if [ ! -d "$parent_path/packages" ]; then
    return 1
  fi
  if [ ! -d "$parent_path/published" ]; then
    return 1
  fi

  return 0
}

usage() {
cat << EOF
Cleanup Workspace folder

Usage: $0 --workspace-path <PATH>

Options:
  --workspace-path <path>    Path to clean up
  --workspace-folder <name>  Optional folder inside the workspace
  --help                     Show this message
EOF
}

parse_flag() {
  declare -n argument=$3

  if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
    argument=$2
    return
  fi

  echo "Error: argument for $1 is missing" >&2
  exit 1
}

WORKSPACE_PATH=""   # e.g. /opt/archives/workspace/
WORKSPACE_FOLDER="" # e.g. voulage/
WORKSPACE_RUN_ID="" # e.g. run-13218767379/

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

if [ -z "$WORKSPACE_PATH" ]; then
  echo "Error: required value for --workspace-path is missing"
  exit 1
fi
if [ -z "$WORKSPACE_FOLDER" ]; then
  echo "Error: required value for --workspace-folder is missing"
  exit 1
fi
WORKSPACE_PATH="${WORKSPACE_PATH%/}"
WORKSPACE_FOLDER="${WORKSPACE_FOLDER%/}"

# workspace path doesn't exist. exit without throwing an error
if [ ! -d "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/" ]; then
  echo "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/ not found"
  exit 0
fi

if [ -n "$WORKSPACE_RUN_ID" ]; then
  WORKSPACE_RUN_ID="${WORKSPACE_RUN_ID%/}"

  if [ ! -d "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/${WORKSPACE_RUN_ID}/" ]; then
    echo "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/${WORKSPACE_RUN_ID}/ not found"
    exit 0
  fi
fi

if ! is_allowed; then
  echo "Cleanup $FULL_WORKSPACE_PATH is not allowed"
  exit 1
fi

# delete the workspace directory only if it has additional folder
if [ -n "$WORKSPACE_RUN_ID" ]; then
  WORKSPACE_RUN_ID="${WORKSPACE_RUN_ID%/}"

  rm -rf "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/${WORKSPACE_RUN_ID}/"
  echo "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/${WORKSPACE_RUN_ID}/ cleaned up successfully"
fi

if [ -d "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/" ] && [ -z "$(ls -A "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/")" ]; then
  rm -rf "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/"
  echo "${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/ cleaned up successfully"
else
  echo "error: ${WORKSPACE_PATH}/${WORKSPACE_FOLDER}/ is not empty"
fi
