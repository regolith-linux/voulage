#!/bin/bash
#
# Test that a Regolith desktop installed from one archive line upgrades
# cleanly to another, e.g. from "stable <codename> v3.4" to
# "stable <codename> v3.5", the way users upgrade: change the sources line,
# then "apt full-upgrade".
#
# Runs as root in a clean <distro>:<codename> container (see
# .github/workflows/test-desktop-upgradable.yml):
#
#   1. install regolith-desktop and each session package the "from" line has
#      (regolith-session-flashback, regolith-session-sway),
#   2. replace the sources line with the "to" line and run
#      "apt-get full-upgrade",
#   3. check the result.
#
# With a <new codename> different from <codename>, step 2 also upgrades the
# OS the way users move to its next release together with Regolith (e.g.
# jammy to noble while moving from v3.4 to v3.5): the OS's own source entries
# (sources.list, sources.list.d/*.list and the deb822 sources.list.d/*.sources)
# switch their <codename> and <codename>-<pocket> suites to <new codename>,
# entries of third-party URIs with those suites are disabled, and the Regolith
# line names <new codename>. The full-upgrade then takes phased updates too,
# and maintainer scripts can't trip over the container's missing udev daemon.
# Step 3 also fails when an OS package is left behind its <new codename>
# version, or when a check command itself fails.
#
# The test fails when the upgrade fails, when a package it installed in
# step 1 is no longer installed, when a package is left not upgraded or in a
# broken state, or when an installed package is older than the "to" line's
# version. Packages that were removed, or that are still installed but no
# longer in any archive line (left over from the "from" line), are listed as
# warnings: they are expected when a release drops a package, and belong in
# the release notes.
#
# Usage: test-upgrade.sh <distro> <codename> <arch> <from: "suite component"> <to: "suite component"> [<new codename>]
#   e.g. test-upgrade.sh ubuntu noble amd64 "stable v3.4" "stable v3.5"
#        test-upgrade.sh ubuntu jammy amd64 "stable v3.4" "stable v3.5" noble

set -o errexit
set -o nounset
set -o pipefail

if [ $# -ne 5 ] && [ $# -ne 6 ]; then
  echo "Usage: $0 <distro> <codename> <arch> <from suite component> <to suite component> [<new codename>]" >&2
  exit 2
fi

DISTRO=$1
CODENAME=$2
ARCH=$3
read -r FROM_SUITE FROM_COMPONENT <<< "$4"
read -r TO_SUITE TO_COMPONENT <<< "$5"
NEW_CODENAME=${6:-$CODENAME}

ARCHIVE_URL=${ARCHIVE_URL:-http://archive.regolith-desktop.com}
KEY_URL="$ARCHIVE_URL/regolith.key"
KEYRING=/etc/apt/keyrings/regolith.gpg
SOURCES=/etc/apt/sources.list.d/regolith.list
SESSIONS=(regolith-session-flashback regolith-session-sway)
SUMMARY=${GITHUB_STEP_SUMMARY:-/dev/null}
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

export DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC LC_ALL=C
APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

FROM_LINE="deb [arch=$ARCH signed-by=$KEYRING] $ARCHIVE_URL/$DISTRO/$FROM_SUITE $CODENAME $FROM_COMPONENT"
TO_LINE="deb [arch=$ARCH signed-by=$KEYRING] $ARCHIVE_URL/$DISTRO/$TO_SUITE $NEW_CODENAME $TO_COMPONENT"

FAILED=0
fail() {
  echo "::error::$1"
  echo "- :x: $1" >> "$SUMMARY"
  FAILED=1
}
warn() {
  echo "::warning::$1"
  echo "- :warning: $1" >> "$SUMMARY"
}

installed_packages() {
  dpkg-query -W -f '${db:Status-Abbrev} ${Package} ${Version}\n' | awk '$1 == "ii" { print $2, $3 }' | sort
}

# Moving the OS's own source entries to the new codename. Entries name it in
# their suite: <codename>, or <codename>-<pocket> (jammy-security). Such an
# entry whose URI is a stock OS URI, one that an enabled entry of
# /etc/apt/sources.list or of the distribution's default deb822 file has, is
# switched: only its suites change, and types, options, URIs (even when they
# contain the codename), components, other fields, comments and whitespace
# stay byte for byte. Any other URI belongs to a third party (a vendor, another
# mirror, another path to the same tree), and the entry is disabled instead,
# as release upgrades do: commented out in a one-line file, "Enabled: no" in a
# deb822 stanza. Entries with other suites (a vendor's "stable") stay as they
# are.

OS_UPGRADE=0
[ "$NEW_CODENAME" == "$CODENAME" ] || OS_UPGRADE=1

# Options of the full-upgrade and of its simulation. Upgrading the OS:
# - they take Ubuntu's phased updates too: phasing holds an update back on
#   some machines while it rolls out, and a held back update would read as an
#   OS package left behind;
# - the maintainer scripts find a udevadm that makes control, trigger and
#   settle no-ops while no udev daemon listens, as in a container. Some
#   scripts reload the udev rules on upgrade without checking for the daemon
#   (light's, from noble to resolute), which works on a desktop only. APT runs
#   dpkg with the PATH of DPkg::Path, whose default this extends.
UPGRADE_OPTS=("${APT_OPTS[@]}")
if [ "$OS_UPGRADE" -eq 1 ]; then
  mkdir "$WORKDIR/bin"
  cat > "$WORKDIR/bin/udevadm" <<'EOF'
#!/bin/sh
case "$1" in
  control | trigger | settle) [ -S /run/udev/control ] || exit 0 ;;
esac
PATH=/usr/sbin:/usr/bin:/sbin:/bin exec udevadm "$@"
EOF
  chmod 755 "$WORKDIR/bin/udevadm"
  UPGRADE_OPTS+=(-o APT::Get::Always-Include-Phased-Updates=true
    -o "DPkg::Path=$WORKDIR/bin:/usr/sbin:/usr/bin:/sbin:/bin")
fi

case "$DISTRO" in
  ubuntu | debian) DEFAULT_SOURCES=/etc/apt/sources.list.d/$DISTRO.sources ;;
  *) DEFAULT_SOURCES= ;;
esac

declare -A STOCK_URIS=()  # stock OS URIs
OS_TARGETS=()             # "<URI>/ <suite>" of the switched enabled entries
DISABLED=()               # "<file>: <entry>" of the disabled entries
switched_files=()

# old_suite <suite>: whether <suite> is the codename or one of its pockets
old_suite() {
  [ "$1" == "$CODENAME" ] || [[ $1 == "$CODENAME"-?* ]]
}

# switch_suite <suite>: sets suite to <suite> on the new codename
switch_suite() {
  case "$1" in
    "$CODENAME") suite=$NEW_CODENAME ;;
    "$CODENAME"-?*) suite=$NEW_CODENAME-${1#"$CODENAME"-} ;;
    *) suite=$1 ;;
  esac
}

# switch_suites <words>: sets switched to <words> with each suite switched
switch_suites() {
  local rest=$1 word='^([[:space:]]*)([^[:space:]]+)(.*)$'
  switched=
  while [[ $rest =~ $word ]]; do
    switched+=${BASH_REMATCH[1]}
    rest=${BASH_REMATCH[3]}
    switch_suite "${BASH_REMATCH[2]}"
    switched+=$suite
  done
  switched+=$rest
}

# add_target <URI> <suite>: an enabled switched entry, with the URI the way
# APT's index targets report it (always ending in a slash)
add_target() {
  local uri=$1
  [[ $uri == */ ]] || uri+=/
  OS_TARGETS+=("$uri $2")
}

# read_lines <file>: sets lines to the lines of <file>, and final_newline to
# whether its last line ends with a newline
read_lines() {
  local line
  lines=()
  while IFS= read -r line; do
    lines+=("$line")
  done < "$1"
  final_newline=1
  if [ -n "$line" ]; then
    lines+=("$line")
    final_newline=0
  fi
}

# write_lines <file>: writes lines back to <file> in place (keeping its owner
# and mode)
write_lines() {
  local text
  text=$(printf '%s\n' "${lines[@]}"; echo .)
  text=${text%.}
  [ "$final_newline" -eq 1 ] || text=${text%$'\n'}
  printf '%s' "$text" > "$1"
}

# list_entry <line>: one-line format, "deb [options] <uri> <suite> ...". The
# options may hold spaces, and a "#" starts a comment. Sets entry_head (up to
# the URI), entry_type, entry_uri, entry_gap, entry_suite and entry_rest.
list_entry() {
  local entry='^([[:space:]]*(deb|deb-src)[[:space:]]+(\[[^]]*\][[:space:]]*)?)([^[:space:]]+)([[:space:]]+)([^[:space:]#]+)(.*)$'
  [[ $1 =~ $entry ]] || return 1
  entry_head=${BASH_REMATCH[1]}
  entry_type=${BASH_REMATCH[2]}
  entry_uri=${BASH_REMATCH[4]}
  entry_gap=${BASH_REMATCH[5]}
  entry_suite=${BASH_REMATCH[6]}
  entry_rest=${BASH_REMATCH[7]}
}

# deb822 format: a stanza is a run of non-empty lines; "#" lines are comments,
# also between a field's continuation lines. Field names are case-insensitive,
# and APT allows blanks before the colon ("Suites : noble").
FIELD='^([^#[:space:]:][^[:space:]:]*)([[:blank:]]*:)(.*)$'

# scan_stanza <first> <end>: reads the fields of the stanza in lines[first]
# to lines[end - 1]. Sets stanza_types, stanza_uris and stanza_suites to the
# words of those fields, stanza_enabled, stanza_suite_lines to the indexes of
# the Suites field's lines, and stanza_last to the index of the last field
# line (-1 when the stanza has no field).
scan_stanza() {
  local i field='' value
  stanza_types=() stanza_uris=() stanza_suites=() stanza_suite_lines=()
  stanza_enabled=1 stanza_last=-1
  for ((i = $1; i < $2; i++)); do
    if [[ ${lines[i]} == "#"* ]]; then
      continue
    elif [[ ${lines[i]} == [[:space:]]* ]]; then
      [ -n "$field" ] || continue
      value=${lines[i]}
    elif [[ ${lines[i]} =~ $FIELD ]]; then
      field=${BASH_REMATCH[1],,}
      value=${BASH_REMATCH[3]}
    else
      field=
      continue
    fi
    stanza_last=$i
    value=${value//$'\r'/ }
    case "$field" in
      types) read -r -a words <<< "$value"; stanza_types+=("${words[@]}") ;;
      uris) read -r -a words <<< "$value"; stanza_uris+=("${words[@]}") ;;
      suites)
        read -r -a words <<< "$value"
        stanza_suites+=("${words[@]}")
        stanza_suite_lines+=("$i")
        ;;
      enabled)
        read -r value <<< "$value"
        case "${value,,}" in
          no | false | without | off | disable | 0) stanza_enabled=0 ;;
          *) stanza_enabled=1 ;;
        esac
        ;;
    esac
  done
}

# stanzas <function>: calls <function> <first> <end> for each stanza in lines
stanzas() {
  local first=0 i
  for ((i = 0; i <= ${#lines[@]}; i++)); do
    if [ "$i" -eq "${#lines[@]}" ] || [ -z "${lines[i]%$'\r'}" ]; then
      [ "$first" -ge "$i" ] || "$1" "$first" "$i"
      first=$((i + 1))
    fi
  done
}

# add_stock_stanza <first> <end>: the URIs of an enabled stanza are stock
add_stock_stanza() {
  local uri
  scan_stanza "$1" "$2"
  if [ "$stanza_enabled" -eq 1 ]; then
    for uri in "${stanza_uris[@]}"; do
      STOCK_URIS[$uri]=1
    done
  fi
}

# find_stock_uris: the URIs of the enabled entries of /etc/apt/sources.list
# and of the distribution's default deb822 file
find_stock_uris() {
  local line
  if [ -f /etc/apt/sources.list ]; then
    read_lines /etc/apt/sources.list
    for line in "${lines[@]}"; do
      if list_entry "$line"; then
        STOCK_URIS[$entry_uri]=1
      fi
    done
  fi
  if [ -n "$DEFAULT_SOURCES" ] && [ -f "$DEFAULT_SOURCES" ]; then
    read_lines "$DEFAULT_SOURCES"
    stanzas add_stock_stanza
  fi
}

# disable <entry>: lists a disabled entry of the current file
disable() {
  DISABLED+=("$file: $1")
  echo "Disabled in $file (not a stock OS URI): $1"
}

# switch_list_file: one-line entries of the current file
switch_list_file() {
  local i
  for ((i = 0; i < ${#lines[@]}; i++)); do
    if ! list_entry "${lines[i]}" || ! old_suite "$entry_suite"; then
      continue
    fi
    if [ -n "${STOCK_URIS[$entry_uri]:-}" ]; then
      switch_suite "$entry_suite"
      lines[i]=$entry_head$entry_uri$entry_gap$suite$entry_rest
      [ "$entry_type" != deb ] || add_target "$entry_uri" "$suite"
      file_switched=1
    else
      disable "${lines[i]%$'\r'}"
      lines[i]="# ${lines[i]}"
      file_disabled=1
    fi
  done
}

# switch_stanza <first> <end>: one deb822 stanza of the current file
switch_stanza() {
  local i uri stock=1 names_old=0 ending=
  scan_stanza "$1" "$2"
  for suite in "${stanza_suites[@]}"; do
    old_suite "$suite" && names_old=1
  done
  [ "$names_old" -eq 1 ] || return 0
  [ ${#stanza_uris[@]} -gt 0 ] || stock=0
  for uri in "${stanza_uris[@]}"; do
    [ -n "${STOCK_URIS[$uri]:-}" ] || stock=0
  done
  if [ "$stock" -eq 1 ]; then
    for i in "${stanza_suite_lines[@]}"; do
      if [[ ${lines[i]} =~ $FIELD ]]; then
        local name=${BASH_REMATCH[1]}${BASH_REMATCH[2]}
        switch_suites "${BASH_REMATCH[3]}"
        lines[i]=$name$switched
      else
        switch_suites "${lines[i]}"
        lines[i]=$switched
      fi
    done
    if [ "$stanza_enabled" -eq 1 ] && [[ " ${stanza_types[*]} " == *" deb "* ]]; then
      for uri in "${stanza_uris[@]}"; do
        for suite in "${stanza_suites[@]}"; do
          if old_suite "$suite"; then
            switch_suite "$suite"
            add_target "$uri" "$suite"
          fi
        done
      done
    fi
    file_switched=1
  elif [ "$stanza_enabled" -eq 1 ]; then
    disable "Types: ${stanza_types[*]}; URIs: ${stanza_uris[*]}; Suites: ${stanza_suites[*]}"
    [[ ${lines[stanza_last]} != *$'\r' ]] || ending=$'\r'
    added[stanza_last]="Enabled: no$ending"
    file_disabled=1
  fi
}

# switch_deb822_file: deb822 stanzas of the current file; "Enabled: no" goes
# after the last field line of each disabled stanza
switch_deb822_file() {
  local i
  local -a added=() result=()
  stanzas switch_stanza
  [ ${#added[@]} -gt 0 ] || return 0
  for ((i = 0; i < ${#lines[@]}; i++)); do
    result+=("${lines[i]}")
    [ -z "${added[i]+set}" ] || result+=("${added[i]}")
  done
  lines=("${result[@]}")
}

# switch_source_file <file> <function>: switches or disables the entries of
# <file>, rewriting it in place only when something changed
switch_source_file() {
  local file=$1 file_switched=0 file_disabled=0
  read_lines "$file"
  "$2"
  if [ "$file_switched" -eq 1 ] || [ "$file_disabled" -eq 1 ]; then
    write_lines "$file"
  fi
  if [ "$file_switched" -eq 1 ]; then
    echo "Switched $file to $NEW_CODENAME"
    switched_files+=("$file")
  fi
}

# switch_os_sources: the OS entries in /etc/apt, both formats; the Regolith
# line is not one of them, it is replaced as a whole
switch_os_sources() {
  local file entry
  find_stock_uris
  for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
    if [ -f "$file" ] && [ "$file" != "$SOURCES" ]; then
      switch_source_file "$file" switch_list_file
    fi
  done
  for file in /etc/apt/sources.list.d/*.sources; do
    if [ -f "$file" ]; then
      switch_source_file "$file" switch_deb822_file
    fi
  done
  if [ ${#switched_files[@]} -eq 0 ]; then
    warn "no OS source entry has a $CODENAME suite to switch to $NEW_CODENAME"
  fi
  if [ ${#DISABLED[@]} -gt 0 ]; then
    {
      echo "Disabled instead of switched to $NEW_CODENAME (not stock OS URIs):"
      echo
      for entry in "${DISABLED[@]}"; do
        echo "- \`$entry\`"
      done
      echo
    } >> "$SUMMARY"
  fi
}

if [ "$OS_UPGRADE" -eq 1 ]; then
  RELEASE="$CODENAME → $NEW_CODENAME"
else
  RELEASE=$CODENAME
fi
echo "## Upgrade $DISTRO $RELEASE $ARCH: $FROM_SUITE $FROM_COMPONENT → $TO_SUITE $TO_COMPONENT" >> "$SUMMARY"

echo "::group::Prepare the container"
apt-get update
apt-get "${APT_OPTS[@]}" install --no-install-recommends ca-certificates wget gnupg tzdata
mkdir -p /etc/apt/keyrings
wget -qO - "$KEY_URL" | gpg --dearmor > "$KEYRING"
echo "::endgroup::"

echo "::group::Install from $FROM_LINE"
echo "$FROM_LINE" > "$SOURCES"
apt-get update
targets=(regolith-desktop)
for session in "${SESSIONS[@]}"; do
  if [ -z "$(apt-cache madison "$session" 2>/dev/null)" ]; then
    continue
  fi
  # A session package can be in the archive without being installable on the
  # codename (e.g. regolith-session-sway in bookworm v3.4, whose sway
  # packages aren't built for bookworm): leave it out, but say so.
  if apt-get -s install regolith-desktop "$session" > /dev/null 2>&1; then
    targets+=("$session")
  else
    warn "$session is in the from line but not installable there, not testing it"
  fi
done
echo "Installing: ${targets[*]}"
apt-get "${APT_OPTS[@]}" install "${targets[@]}"
installed_packages > "$WORKDIR/before.txt"
echo "::endgroup::"
echo "Installed from the from line: \`${targets[*]}\` ($(wc -l < "$WORKDIR/before.txt") packages in total)" >> "$SUMMARY"

echo "::group::Upgrade to $TO_LINE"
if [ "$OS_UPGRADE" -eq 1 ]; then
  echo "Upgrading the OS from $CODENAME to $NEW_CODENAME"
  switch_os_sources
fi
echo "$TO_LINE" > "$SOURCES"
apt-get update
if ! apt-get "${UPGRADE_OPTS[@]}" full-upgrade; then
  fail "apt-get full-upgrade failed"
fi
installed_packages > "$WORKDIR/after.txt"
echo "::endgroup::"

echo "::group::Check the upgraded system"
for package in "${targets[@]}"; do
  if ! awk -v p="$package" '$1 == p { found = 1 } END { exit !found }' "$WORKDIR/after.txt"; then
    fail "$package is not installed after the upgrade"
  fi
done

if ! apt-get check; then
  fail "apt-get check reports broken dependencies"
fi

# Upgrading the OS, a check command that fails is a failure too; the same
# release run keeps tolerating it.
if [ "$OS_UPGRADE" -eq 0 ]; then
  audit=$(dpkg --audit || true)
elif ! audit=$(dpkg --audit); then
  fail "dpkg --audit failed"
fi
if [ -n "$audit" ]; then
  echo "$audit"
  fail "dpkg --audit reports packages in a broken state"
fi

# Nothing may be left to upgrade, hold back or remove.
if [ "$OS_UPGRADE" -eq 0 ]; then
  pending=$(apt-get -s "${APT_OPTS[@]}" full-upgrade | grep -E '^(Inst|Remv) ' || true)
elif simulation=$(apt-get -s "${UPGRADE_OPTS[@]}" full-upgrade); then
  pending=$(echo "$simulation" | grep -E '^(Inst|Remv) ' || true)
else
  pending=
  fail "the simulated apt-get full-upgrade failed"
fi
if [ -n "$pending" ]; then
  echo "$pending"
  fail "the upgrade left packages to install, upgrade or remove: $(echo "$pending" | awk '{print $2}' | sort -u | tr '\n' ' ')"
fi

# Every installed package that the to line has must be at least at its
# version there (a downgrade would mean the to line is behind the from line).
# The to line's indexes for the codename upgraded to, binary-<arch> and
# binary-all; apt may store them compressed (Docker images set
# Acquire::GzipIndexes), which cat-file reads.
mapfile -t to_indexes < <(find /var/lib/apt/lists \
  -name "*_${DISTRO}_${TO_SUITE}_dists_${NEW_CODENAME}_${TO_COMPONENT}_binary-${ARCH}_Packages*" -o \
  -name "*_${DISTRO}_${TO_SUITE}_dists_${NEW_CODENAME}_${TO_COMPONENT}_binary-all_Packages*")
if [ ${#to_indexes[@]} -eq 0 ]; then
  fail "no package index of the to line in /var/lib/apt/lists"
else
  for index in "${to_indexes[@]}"; do
    /usr/lib/apt/apt-helper cat-file "$index"
  done | awk '/^Package:/ { p = $2 } /^Version:/ { print p, $2 }' | cat > "$WORKDIR/to-index.txt"
  if [ ! -s "$WORKDIR/to-index.txt" ]; then
    fail "the package index of the to line lists no package: ${to_indexes[*]}"
  fi
  while read -r package version candidate; do
    if dpkg --compare-versions "$version" lt "$candidate"; then
      fail "$package is at $version, older than $candidate in the to line"
    fi
  done < <(awk 'NR == FNR { v[$1] = $2; next } $1 in v { print $1, v[$1], $2 }' "$WORKDIR/after.txt" "$WORKDIR/to-index.txt")
fi

# Upgrading the OS, the OS must have finished moving: every installed package
# that the switched OS entries have for the new codename must be at least at
# their version there. A package kept back, e.g. because its new version
# depends on a package no archive has, is not pending work for the simulated
# full-upgrade above, which only reports it as kept back. Packages on hold
# ("hi") count too, although installed_packages leaves them out: here every
# package dpkg has installed counts, whatever its selection.
if [ "$OS_UPGRADE" -eq 1 ] && [ ${#OS_TARGETS[@]} -gt 0 ]; then
  dpkg-query -W -f '${db:Status-Abbrev} ${Package} ${Version}\n' |
    awk 'substr($1, 2, 1) == "i" { print $2, $3 }' | sort > "$WORKDIR/os-installed.txt"
  declare -A os_targets=() behind=()
  for target in "${OS_TARGETS[@]}"; do
    os_targets[$target]=1
  done
  # shellcheck disable=SC2016  # $(...) are apt-get indextargets fields
  mapfile -t os_indexes < <(apt-get indextargets --format '$(REPO_URI) $(RELEASE) $(ARCHITECTURE) $(FILENAME)' \
    'Created-By: Packages' | while read -r uri suite arch index; do
      if [ -n "${os_targets[$uri $suite]:-}" ] && { [ "$arch" == "$ARCH" ] || [ "$arch" == all ]; } &&
        [ -f "$index" ]; then
        echo "$index"
      fi
    done)
  if [ ${#os_indexes[@]} -eq 0 ]; then
    fail "no package index of the OS entries switched to $NEW_CODENAME in /var/lib/apt/lists"
  else
    for index in "${os_indexes[@]}"; do
      /usr/lib/apt/apt-helper cat-file "$index"
    done | awk '/^Package:/ { p = $2 } /^Version:/ { print p, $2 }' | cat > "$WORKDIR/os-index.txt"
    while read -r package version candidate; do
      if dpkg --compare-versions "$version" lt "$candidate" &&
        { [ -z "${behind[$package]:-}" ] || dpkg --compare-versions "${behind[$package]#* }" lt "$candidate"; }; then
        behind[$package]="$version $candidate"
      fi
    done < <(awk 'NR == FNR { v[$1] = $2; next } ($1 in v) && v[$1] != $2 { print $1, v[$1], $2 }' "$WORKDIR/os-installed.txt" "$WORKDIR/os-index.txt")
    mapfile -t left_behind < <(printf '%s\n' "${!behind[@]}" | sort)
    for package in "${left_behind[@]}"; do
      [ -n "$package" ] || continue
      read -r version candidate <<< "${behind[$package]}"
      fail "$package is at $version, older than $candidate in the $NEW_CODENAME OS archive: the OS upgrade left it behind"
    done
  fi
fi

# Set operations use awk, not comm or join: uutils coreutils 0.2.2 (the
# default coreutils of Ubuntu 25.10) gives wrong results for comm on
# correctly sorted input.
only_in() {  # only_in <a> <b>: packages in list a but not in list b
  awk 'NR == FNR { seen[$1]; next } !($1 in seen) { print $1 }' "$2" "$1" | sort -u | tr '\n' ' '
}

removed=$(only_in "$WORKDIR/before.txt" "$WORKDIR/after.txt")
if [ -n "$removed" ]; then
  warn "removed by the upgrade: $removed"
fi

# Installed packages that no archive line has any more: left over from the
# from line, e.g. packages the new release dropped.
leftover=$(apt list --installed 2>/dev/null | awk -F/ '/,local\]/ { print $1 }' | tr '\n' ' ')
if [ -n "$leftover" ]; then
  warn "installed but no longer in any archive line (left over from $FROM_SUITE $FROM_COMPONENT): $leftover"
fi

changed=$(awk 'NR == FNR { v[$1] = $2; next } ($1 in v) && v[$1] != $2 { print $1 " " v[$1] " → " $2 }' "$WORKDIR/before.txt" "$WORKDIR/after.txt")
added=$(only_in "$WORKDIR/after.txt" "$WORKDIR/before.txt")
{
  echo "<details><summary>Package changes ($(echo -n "$changed" | grep -c . || true) upgraded, $(echo -n "$added" | wc -w) new)</summary>"
  echo
  echo '```'
  echo "$changed"
  [ -n "$added" ] && echo "new: $added"
  echo '```'
  echo "</details>"
} >> "$SUMMARY"
echo "::endgroup::"

if [ "$FAILED" -ne 0 ]; then
  echo "Upgrade test failed."
  exit 1
fi
echo "- :white_check_mark: upgrade succeeded" >> "$SUMMARY"
echo "Upgrade test passed."
