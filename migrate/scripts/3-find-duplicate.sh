#!/usr/bin/env bash
#
# Find duplicate .orig.tar.gz files of same components across different codename
# and if they are identical use single copy for all instances. This will ensure
# that the checksum of the file remains consistence across multiple codenames for
# single version and single component.

runcmd() {
    printf '== %s\n' "${*}"
    "${@}";
}

duplicate() {
    local distro="$1"

    if [ -n "$ONLY_DISTRO" ] && [ "$ONLY_DISTRO" != "$distro" ]; then
        return
    fi

    # look up in reverse order (newer codenames first)
    codenames=$(ls "$distro" | sort -r | uniq)

    for codename in $(ls "$distro" | sort -r | uniq); do
        if [ -z "$codename" ]; then
            continue
        fi
        if [ ! -d "$distro/$codename" ]; then
            continue
        fi

        # remove current codename from list of all codename to be compared to
        codenames=$(echo "$codenames" | sed "s/$codename//g")

        for component in experimental main testing unstable; do
            if [ -z "$component" ]; then
                continue
            fi
            if [ ! -d "$distro/$codename/$component" ]; then
                continue
            fi
            if [ -n "$ONLY_COMPONENT" ] && [ "$ONLY_COMPONENT" != "$component" ]; then
                continue
            fi

            printf "Distro   : $distro\n"
            printf "Codename : $codename\n"
            printf "Component: $component\n"
            printf "==============================\n"

            for f in $(find "$distro/$codename/$component" -maxdepth 1 -type f -name "*.orig.tar.gz" | sort); do
                if [ -z "$f" ]; then
                    continue
                fi

                name=$(basename $f)
                if [ -n "$ONLY_PACKAGE" ] && [ "$ONLY_PACKAGE" != "$name" ]; then
                    continue
                fi

                for c in $codenames; do
                    # ignore current codename
                    if [ "$c" == "$codename" ]; then
                        continue
                    fi

                    # the other codename doesn't have this component
                    if [ ! -d "$distro/$c/$component" ]; then
                        continue
                    fi

                    # this file doesn't exist in other component
                    if [ ! -f "$distro/$c/$component/$name" ]; then
                        continue
                    fi

                    printf "==> checking $name in $distro/$c/$component\n"

                    if [ -d "$distro/$c/$component/sanitized/" ]; then
                        if [ -f "$distro/$c/$component/sanitized/sanitizeddiff" ]; then
                            if [ $(grep -rn "^=> checking $name" $distro/$c/$component/sanitized/sanitizeddiff | wc -l) != 0 ]; then
                                printf "already processed!\n"
                                printf "==============================\n"

                                continue
                            fi
                        fi
                    fi

                    source_file="$distro/$codename/$component/$name"
                    target_file="$distro/$c/$component/$name"

                    result=$(diff <(tar -tvf $source_file | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2) <(tar -tvf $target_file | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2) 2>&1)

                    if [ -n "$result" ]; then
                        printf "files content are different, do not override!\n"
                        printf "==============================\n"

                        continue
                    fi

                    runcmd mkdir -p "$distro/$c/$component/sanitized"

                    if [ ! -f "$distro/$c/$component/sanitized/sanitizeddiff" ]; then
                        touch "$distro/$c/$component/sanitized/sanitizeddiff"
                    fi

                    runcmd mv "$distro/$c/$component/$name" "$distro/$c/$component/sanitized/$(date +%s)+$component-$distro-$codename+$name"
                    runcmd cp "$distro/$codename/$component/$name" "$distro/$c/$component"

                    echo "=> checking $name" >> "$distro/$c/$component/sanitized/sanitizeddiff"
                    echo "identical, keeping $distro/$codename/$component/$name" >> "$distro/$c/$component/sanitized/sanitizeddiff"
                    echo "==============================" >> "$distro/$c/$component/sanitized/sanitizeddiff"

                    printf "==============================\n"
                done
            done
        done
    done
}

main() {
    pushd $ROOT_PATH > /dev/null

    duplicate "ubuntu"
    duplicate "debian"

    popd > /dev/null
}

if [ -z "$1" ]; then
    echo "usage find-duplicate.sh <path-to-repos-merged>"
    exit 1
fi

ROOT_PATH=$(realpath $1)

if [ ! -d "$ROOT_PATH" ]; then
    echo "error: $ROOT_PATH not found"
    exit 1
fi

ONLY_DISTRO="$2"
ONLY_COMPONENT="$3"
ONLY_PACKAGE="$4"

main
