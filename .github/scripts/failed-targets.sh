#!/usr/bin/env bash
#
# Print the targets of a build-deb-v5.yml run that must not be published, one
# "<stage> <distro> <codename>" per line, sorted.
#
# Every build leg that passes leaves a marker file named after its target
# ("<stage>-<distro>-<codename>-<arch>") in the marker folder. A target is
# held back when the leg of any of its architectures left no marker: it
# failed, or it never ran. The architectures are held together because they
# share one manifest and one source package, and a passing architecture has
# already uploaded its packages next to the failing one.
#
# The targets come from the matrix-builder job outputs, the same way the build
# matrix does: every stage, distro and codename combination, minus the
# excluded distro/codename pairs, plus any stage/distro/codename includes.
#
# Usage: STAGES=... DISTROS=... CODENAMES=... ARCHES=... EXCLUDES=... \
#          [INCLUDES=...] failed-targets.sh <marker folder>
#
# The variables hold the JSON arrays the matrix-builder job outputs.

set -eo pipefail

MARKERS="${1:?usage: failed-targets.sh <marker folder>}"
: "${STAGES:?}" "${DISTROS:?}" "${CODENAMES:?}" "${ARCHES:?}" "${EXCLUDES:?}"
INCLUDES="${INCLUDES:-[]}"

targets=$(jq -r -n \
  --argjson stages "$STAGES" \
  --argjson distros "$DISTROS" \
  --argjson codenames "$CODENAMES" \
  --argjson excludes "$EXCLUDES" \
  --argjson includes "$INCLUDES" \
  '[
     ($stages[] as $s | $distros[] as $d | $codenames[] as $c
       | select(any($excludes[]; .distro == $d and .codename == $c) | not)
       | [$s, $d, $c]),
     ($includes[] | select(.stage and .distro and .codename) | [.stage, .distro, .codename])
   ] | unique[] | join(" ")')

mapfile -t arches < <(jq -r '.[]' <<<"$ARCHES")

while read -r stage distro codename; do
  [ -n "$stage" ] || continue
  for arch in "${arches[@]}"; do
    if [ ! -f "$MARKERS/$stage-$distro-$codename-$arch" ]; then
      echo "$stage $distro $codename"
      break
    fi
  done
done <<<"$targets"
