#!/usr/bin/env bash
#
# Rebuild all the source files.
#
# The following files will be rebuilt out of exisiting .orig.tar.gz file which
# is previously repacked without /debian folder in it.
#
# - .dsc
# - .debian.tar.xz
#
# This will ensure one single .orig.tar.gz file can be used for all the
# packages of the same version and same component of different codenames.

runcmd() {
    printf '== %s\n' "${*}"
    "${@}";
}

generate() {
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

        for component in $(ls "$distro/$codename"); do
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

            pushd $distro/$codename/$component > /dev/null

            for f in $(find . -maxdepth 1 -type f -name "*.orig.tar.gz" | sort); do
                if [ -z "$f" ]; then
                    continue
                fi

                base_name=$(basename $f)
                if [ -n "$ONLY_PACKAGE" ] && [ "$ONLY_PACKAGE" != "$base_name" ]; then
                    continue
                fi

                tmp=$(mktemp -d)
                if [ -z "$tmp" ]; then
                    continue
                fi
                if [ ! -d "$tmp" ]; then
                    continue
                fi

                pkg_full_name=$(echo $base_name | sed 's/.orig.tar.gz//g')
                pkg_name=$(echo $f | cut -d"_" -f1)

                runcmd cp "$pkg_full_name.orig.tar.gz" "$tmp"
                runcmd cp "$pkg_full_name-$codename.debian.tar.xz" "$tmp"

                # entering /tmp/tmp.XXXXXXXXXX
                pushd $tmp > /dev/null

                runcmd tar -xf "$pkg_full_name-$codename.debian.tar.xz"
                runcmd mkdir $pkg_name
                runcmd mv "debian/" "$pkg_name"

                if [ -d "$pkg_name" ]; then
                    pushd $pkg_name > /dev/null

                    runcmd apt update
                    runcmd apt build-dep -y .
                    runcmd debuild -S -sa

                    popd > /dev/null
                fi

                # existing /tmp/tmp.XXXXXXXXXX
                popd > /dev/null

                # copy newly generated .dsc and .debian.tar.xz file back to the repo
                runcmd cp $tmp/$pkg_full_name-$codename.dsc .
                runcmd cp $tmp/$pkg_full_name-$codename.debian.tar.xz .

                rm -rf $tmp > /dev/null
                printf "==============================\n"
            done

            popd > /dev/null
        done
    done
}


main() {
    pushd $ROOT_PATH > /dev/null

    generate "ubuntu"
    generate "debian"

    popd > /dev/null
}

if [ -z "$1" ]; then
    echo "usage rebuild-sources.sh <path-to-repos-merged>"
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
ONLY_PACKAGE="$5"

main
