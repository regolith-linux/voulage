#!/usr/bin/env bash
#
# Sanitize .orig.tar.gz source file by explicitly removing "debian/" folder
# from it.
#
# Repacking .orig.tar.gz is particularly important to strip the tarball from
# any references to the OS, Codename, and Suite. This process will make this
# file to be shared among different components, suits, codenames of a distro
# for one particular package version.

runcmd() {
    printf '== %s\n' "${*}"
    "${@}";
}

sanitize() {
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

                # entering /tmp/tmp.XXXXXXXXXX
                pushd $tmp > /dev/null

                runcmd tar -xzf "$pkg_full_name.orig.tar.gz"

                if [ -d "$pkg_name" ]; then
                    # delete /debian folder and repackage .orig.tar.gz
                    pushd $pkg_name > /dev/null
                    runcmd rm -rf debian/
                    popd > /dev/null

                    runcmd tar --force-local -cvzf "$pkg_full_name.orig.tar.gz" $pkg_name
                fi

                # existing /tmp/tmp.XXXXXXXXXX
                popd > /dev/null

                # copy sanitized .orig.tar.gz file back to the repo
                runcmd cp $tmp/$pkg_full_name.orig.tar.gz .

                rm -rf $tmp > /dev/null
                printf "==============================\n"
            done

            popd > /dev/null
        done
    done
}

main() {
    pushd $ROOT_PATH > /dev/null

    sanitize "ubuntu"
    sanitize "debian"

    popd > /dev/null
}

if [ -z "$1" ]; then
    echo "usage sanitize-source.sh <path-to-repos-merged>"
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
