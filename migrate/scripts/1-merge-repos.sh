#!/usr/bin/env bash
#
# Merge old repositories into unified folder structure.
#
# Note that this is the staging area, and the entire source files have to be rebuilt
# again (because we're merging multiple architectures' repo into one, and all the source
# files previously were built per single distror/codename/component triplet, and not
# sharable.)

merge() {
    local distro="$1"
    mkdir -p "$MERGED_PATH/$distro"

    for codename in $(ls | grep "$distro" | cut -d"-" -f3 | sort | uniq); do
        if [ -z "$codename" ]; then
            continue
        fi

        for repo in $(ls | grep "$distro-$codename"); do
            if [ -z "$repo" ]; then
                return
            fi
            if [ ! -d "$repo" ]; then
                continue
            fi

            mkdir -p "$MERGED_PATH/$distro/$codename"

            component=$(echo "$repo" | cut -d"-" -f1)

            if [ "$component" == "release" ]; then
                component="main"
                arch=$(echo "$repo" | cut -d"-" -f5)

                if [ -z "$arch" ]; then
                    arch=$(echo "$repo" | cut -d"-" -f4)
                fi
            else
                arch=$(echo "$repo" | cut -d"-" -f4)
            fi

            printf "Distro   : $distro\n"
            printf "Codename : $codename\n"
            printf "Component: $component\n"
            printf "Arch     : $arch\n"
            printf "==============================\n"

            pushd $repo > /dev/null

            if [ ! -d "pool/main" ]; then
                popd > /dev/null
                printf "==============================\n"

                continue
            fi

            # add all the files in pool/main
            mkdir -p "$MERGED_PATH/$distro/$codename/$component"

            files=""
            if [ "$PACKAGE_TYPE" == "deb" ]; then
                files=$(find pool/main -type f -name "*.deb")
            elif [ "$PACKAGE_TYPE" == "src" ]; then
                files=$(find pool/main -type f -not -name "*.deb")
            fi

            for f in $files; do
                if [ -z "$f" ]; then
                    continue
                fi
                name=$(basename $f)

                # link the file if it doesn't exist
                if [ $(find "$MERGED_PATH/$distro/$codename/$component" -type f -name "$name" | wc -l) == 0 ]; then
                    filename=$(basename "$f")
                    extension="${filename##*.}"

                    if [ "$extension" == "deb" ]; then
                        ln $f "$MERGED_PATH/$distro/$codename/$component"
                    else
                        cp $f "$MERGED_PATH/$distro/$codename/$component"
                    fi
                    echo "Copied: $f"

                # otherwise store it in duplicate folder
                else
                    mkdir -p "$MERGED_PATH/$distro/$codename/$component/duplicate"

                    difffile=""
                    if [ "$PACKAGE_TYPE" == "deb" ]; then
                        difffile="debdiffs"
                    elif [ "$PACKAGE_TYPE" == "src" ]; then
                        difffile="sourcediff"
                    fi

                    if [ ! -f "$MERGED_PATH/$distro/$codename/$component/duplicate/$difffile" ]; then
                        touch "$MERGED_PATH/$distro/$codename/$component/duplicate/$difffile"
                    fi

                    # the file is already being tracked in duplicate folder
                    if [ $(grep -rn "^=> comparing .*$from_path+$name$" $MERGED_PATH/$distro/$codename/$component/duplicate/$difffile | wc -l) != 0 ]; then
                        continue
                    fi

                    from_path=$(echo "$repo" | cut -d"/" -f 2)
                    ln $f "$MERGED_PATH/$distro/$codename/$component/duplicate/$(date +%s)+$from_path+$name"
                    echo "Duplicate: $f"
                fi
            done

            if [ -d "$MERGED_PATH/$distro/$codename/$component/duplicate" ]; then
                files=""
                difffile=""

                if [ "$PACKAGE_TYPE" == "deb" ]; then
                    files=$(ls "$MERGED_PATH/$distro/$codename/$component/duplicate" | grep "\.deb")
                    difffile="debdiffs"
                elif [ "$PACKAGE_TYPE" == "src" ]; then
                    files=$(ls "$MERGED_PATH/$distro/$codename/$component/duplicate" | grep -v "\.deb")
                    difffile="sourcediff"
                fi

                for f in $(echo "$files" | grep -v debdiffs | grep -v sourcediff); do
                    duplicate_file="$MERGED_PATH/$distro/$codename/$component/duplicate/$f"
                    persisted_file="$MERGED_PATH/$distro/$codename/$component"/$(echo $f | cut -d"+" -f3)

                    # the file is already being tracked in duplicate folder
                    if [ $(grep -rn "^=> comparing $f" $MERGED_PATH/$distro/$codename/$component/duplicate/$difffile | wc -l) != 0 ]; then
                        continue
                    fi

                    result=""
                    process="fasle"

                    if [ "$PACKAGE_TYPE" == "deb" ]; then
                        result=$(debdiff $duplicate_file $persisted_file 2>&1)

                        if [ $(echo "$result" | grep "No differences were encountered between the control files" | wc -l) == 0 ]; then
                            process="true"
                        fi
                    elif [ "$PACKAGE_TYPE" == "src" ]; then
                        filename=$(basename "$f")
                        extension="${filename##*.}"
                        extension=$(echo "$filename" | sed 's/.*\///' | grep -oE "(^[^.]*$|(\.[^0-9])*(\.[^0-9]*$))")

                        # .dsc
                        if [ "$extension" == ".dsc" ]; then
                            result=$(diff $duplicate_file $persisted_file 2>&1)

                        # .diff.gz
                        elif [ "$extension" == ".diff.gz" ]; then
                            result=$(diff $duplicate_file $persisted_file 2>&1)

                        # .tar.xz
                        elif [ "$extension" == ".tar.xz" ]; then
                            result=$(diff <(tar -tvf $duplicate_file | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2) <(tar -tvf $persisted_file | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2) 2>&1)

                        # .debian.tar.xz
                        elif [ "$extension" == ".debian.tar.xz" ]; then
                            result=$(diff <(tar -tvf $duplicate_file | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2) <(tar -tvf $persisted_file | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2) 2>&1)

                        # .orig.tar.gz
                        elif [ "$extension" == ".orig.tar.gz" ]; then
                            result=$(diff <(tar -tvf $duplicate_file | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2) <(tar -tvf $persisted_file | awk '{printf "%10s %s\n",$3,$6}' | sort -k 2) 2>&1)
                        fi

                        if [ -n "$result" ]; then
                            process="true"
                        fi
                    fi

                    echo "=> comparing $f"
                    echo "$result"
                    echo "===================================================================================================================================="

                    if [ "$process" == "true" ]; then
                        echo "=> comparing $f" >> "$MERGED_PATH/$distro/$codename/$component/duplicate/$difffile"
                        echo "$result" >> "$MERGED_PATH/$distro/$codename/$component/duplicate/$difffile"
                        echo "====================================================================================================================================" >> "$MERGED_PATH/$distro/$codename/$component/duplicate/debdiffs"
                    fi
                done
            fi

            popd > /dev/null
            printf "==============================\n"
        done
    done
}

main() {
    pushd $ROOT_PATH > /dev/null

    merge "ubuntu"
    merge "debian"

    popd > /dev/null
}

if [ -z "$1" ]; then
    echo "usage migrate-repo.sh <path-to-repos-old> <package-type>"
    exit 1
fi
if [ -z "$2" ]; then
    echo "usage migrate-repo.sh <path-to-repos-old> <package-type>"
    exit 1
fi

ROOT_PATH=$(realpath $1)
MERGED_PATH="$(dirname "$ROOT_PATH")/repos-merged"

mkdir -p "$MERGED_PATH"

PACKAGE_TYPE=$2

if [ "$PACKAGE_TYPE" != "deb" ] && [ "$PACKAGE_TYPE" != "src" ]; then
    echo "unknown package type. must be 'deb' or 'src'"
    exit 1
fi

main

# overrides
if [ "$PACKAGE_TYPE" == "src" ]; then
    # regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz
    cp "$ROOT_PATH/unstable-ubuntu-mantic-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/focal/unstable/"
    cp "$ROOT_PATH/unstable-ubuntu-mantic-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/jammy/unstable/"
    cp "$ROOT_PATH/unstable-ubuntu-mantic-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/lunar/unstable/"
    cp "$ROOT_PATH/unstable-ubuntu-mantic-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/noble/unstable/"

    cp "$ROOT_PATH/testing-ubuntu-mantic-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/focal/testing/"
    cp "$ROOT_PATH/testing-ubuntu-mantic-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/jammy/testing/"
    cp "$ROOT_PATH/testing-ubuntu-mantic-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/lunar/testing/"
    cp "$ROOT_PATH/testing-ubuntu-mantic-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/noble/testing/"

    cp "$ROOT_PATH/release-current-ubuntu-lunar-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/focal/main/"
    cp "$ROOT_PATH/release-current-ubuntu-lunar-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/jammy/main/"
    cp "$ROOT_PATH/release-current-ubuntu-lunar-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/mantic/main/"

    cp "$ROOT_PATH/testing-debian-bullseye-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/debian/bookworm/testing/"
    cp "$ROOT_PATH/testing-debian-bullseye-amd64/pool/main/r/regolith-compositor-picom-glx/regolith-compositor-picom-glx_1.3.0-1regolith.orig.tar.gz" "$MERGED_PATH/debian/testing/testing/"

    # regolith-powerd_0.2.0-1regolith.orig.tar.gz
    cp "$ROOT_PATH/unstable-ubuntu-mantic-amd64/pool/main/r/regolith-powerd/regolith-powerd_0.2.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/noble/unstable/"

    cp "$ROOT_PATH/testing-ubuntu-mantic-amd64/pool/main/r/regolith-powerd/regolith-powerd_0.2.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/jammy/testing/"
    cp "$ROOT_PATH/testing-ubuntu-mantic-amd64/pool/main/r/regolith-powerd/regolith-powerd_0.2.0-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/noble/testing/"

    # regolith-wm-config_4.1.7-1regolith.orig.tar.gz
    cp "$ROOT_PATH/unstable-ubuntu-lunar-arm64/pool/main/r/regolith-wm-config/regolith-wm-config_4.1.7-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/lunar/unstable/"

    # trawl_0.2.2ubuntu1-1regolith.orig.tar.gz
    cp "$ROOT_PATH/testing-ubuntu-mantic-amd64/pool/main/t/trawl/trawl_0.2.2ubuntu1-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/lunar/testing/"

    cp "$ROOT_PATH/unstable-ubuntu-mantic-amd64/pool/main/t/trawl/trawl_0.2.2ubuntu1-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/jammy/unstable/"
    cp "$ROOT_PATH/unstable-ubuntu-mantic-amd64/pool/main/t/trawl/trawl_0.2.2ubuntu1-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/lunar/unstable/"

    cp "$ROOT_PATH/unstable-debian-testing-amd64/pool/main/t/trawl/trawl_0.2.2ubuntu1-1regolith.orig.tar.gz" "$MERGED_PATH/debian/bookworm/unstable/"

    # trawl_0.2.3-1regolith.orig.tar.gz
    cp "$ROOT_PATH/testing-ubuntu-mantic-amd64/pool/main/t/trawl/trawl_0.2.3-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/jammy/testing/"
    cp "$ROOT_PATH/testing-ubuntu-mantic-amd64/pool/main/t/trawl/trawl_0.2.3-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/noble/testing/"
    
    cp "$ROOT_PATH/unstable-ubuntu-mantic-amd64/pool/main/t/trawl/trawl_0.2.3-1regolith.orig.tar.gz" "$MERGED_PATH/ubuntu/noble/unstable/"

    # xdg-desktop-portal-regolith_0.3.3-1regolith.orig.tar.gz
    # nothing to do. arm64 is different than amd64. but amd64 is the correct source code.
fi
