#!/usr/bin/env bash
#
# Publish new repos out of merged old repositories.

runcmd() {
    printf '== %s\n' "${*}"
    "${@}";
}

publish() {
    local distro="$1"

    if [ -n "$ONLY_DISTRO" ] && [ "$ONLY_DISTRO" != "$distro" ]; then
        return
    fi

    for codename in $(ls "$distro" | sort | uniq); do
        if [ -z "$codename" ]; then
            continue
        fi
        if [ ! -d "$distro/$codename" ]; then
            continue
        fi
        if [ -n "$ONLY_CODENAME" ] && [ "$ONLY_CODENAME" != "$codename" ]; then
            continue
        fi

        local repos=""
        local components=""

        for component in $(ls "$distro/$codename"); do
            if [ -z "$component" ]; then
                return
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

            pushd $distro/$codename/$component > /dev/null

            # add all the files in pool/main
            files=$(find . -maxdepth 1 -type f -name "*.deb" -o -name "*.dsc")
            if [ -z "$files" ]; then
                popd > /dev/null
                printf "==============================\n"

                continue
            fi

            # create repo if it doesn't exist
            if [ "$(aptly repo show -config=/etc/aptly/$distro.conf $codename-$component)" ]; then
                : # nothing
            else
                runcmd aptly \
                       repo \
                       create \
                       -config=/etc/aptly/$distro.conf \
                       -component=$component \
                       -distribution=$codename \
                       -comment="Regolith Linux for $distro $codename" \
                       $codename-$component
            fi

            runcmd aptly \
                   repo \
                   add \
                   -config=/etc/aptly/$distro.conf \
                   $codename-$component \
                   $files

            if [[ "$repos" != *"$codename-$component"* ]]; then
                repos="$repos$codename-$component "
            fi
            if [[ "$components" != *"$component"* ]]; then
                components="$components$component,"
            fi

            # publish or update repo
            if [ "$(aptly publish show -config=/etc/aptly/$distro.conf $codename-$component)" ]; then
                runcmd aptly \
                       publish \
                       update \
                       -config=/etc/aptly/$distro.conf \
                       $codename-$component
            fi

            popd > /dev/null
            printf "==============================\n"
        done

        if [ -n "$repos" ] && [ -n "$components" ]; then
            # remove the last comma from 'components' list
            components="${components%?}"

            runcmd aptly \
                   publish \
                   repo \
                   -config=/etc/aptly/$distro.conf \
                   -component=$components \
                   -distribution=$codename \
                   -label="Regolith Linux" \
                   -origin="Regolith Linux" \
                   -acquire-by-hash \
                   $repos
        fi
    done
}

main() {
    pushd $ROOT_PATH > /dev/null

    publish "ubuntu"
    publish "debian"

    popd > /dev/null
}

if [ -z "$1" ]; then
    echo "usage publish-repos.sh <path-to-repos-merged>"
    exit 1
fi

ROOT_PATH=$(realpath $1)

if [ ! -d "$ROOT_PATH" ]; then
    echo "error: $ROOT_PATH not found"
    exit 1
fi

ONLY_DISTRO="$2"
ONLY_CODENAME="$3"
ONLY_COMPONENT="$4"

main
