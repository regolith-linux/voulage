#!/usr/bin/env bash

remove_packages() {
    for f in $(find . -maxdepth 1 -type f | sort); do
        if [ -z "$f" ]; then
            continue
        fi

        base_name=$(basename $f)

        pkg_name=$(echo $base_name | cut -d"_" -f1)
        pkg_version=$(echo $base_name | cut -d"_" -f2)
        pkg_arch=$(echo $base_name | cut -d"_" -f3)

        if [ -z "$pkg_arch" ]; then
            continue
        fi

        if aptly -config=/etc/aptly/debian/stable.conf repo search bookworm-main $pkg_name', $Version (% '$pkg_version'*)' >/dev/null 2>&1; then
            aptly -config=/etc/aptly/debian/stable.conf \
                repo \
                remove \
                bookworm-main \
                $pkg_name', $Version (% '$pkg_version'*)'

            #echo "going to delete name: $pkg_name, version: $pkg_version, arch: $pkg_arch"
        fi
    done
}

main() {
    pushd $PACKAGES_ROOT > /dev/null

    remove_packages "ubuntu"

    popd > /dev/null
}

if [ -z "$1" ]; then
    echo "usage: sanitize-source.sh </path/to/archives/packages>"
    exit 1
fi

PACKAGES_ROOT=$(realpath $1) # e.g. /opt/archives/packages

if [ ! -d "$PACKAGES_ROOT" ]; then
    echo "error: $PACKAGES_ROOT not found"
    exit 1
fi

main

