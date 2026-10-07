#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: ./install.sh [--root PLUTONIUM_DIR] [--yes] [--uninstall] [--find]"
}

root="${PLUTONIUM_DIR:-}"
yes=0
uninstall=0
find_only=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root) shift; root="${1:-}" ;;
        --yes) yes=1 ;;
        --uninstall) uninstall=1 ;;
        --find) find_only=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
download="$(cd "$script_dir/../.." && pwd)"
if [ -f "$script_dir/tools/build.py" ]; then
    download="$script_dir/dist/t6/src"
fi
source_dir="$download/Plutonium/storage/t6/mods/zm_zstats"
source_image="$download/Plutonium/storage/t6/images/menu_zm_cac_backing.iwi"

hash_file() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    else shasum -a 256 "$1" | awk '{print $1}'; fi
}

if [ -z "$root" ]; then
    read -r -p "Plutonium folder: " root
fi
if [ -z "$root" ]; then
    echo "No Plutonium folder was supplied."
    exit 2
fi

storage="${root%/}/storage/t6"
destination="$storage/mods/zm_zstats"
image_dir="$storage/images"
image_destination="$image_dir/menu_zm_cac_backing.iwi"
image_backup="$image_dir/menu_zm_cac_backing.zstats-backup.iwi"
image_marker="$image_dir/menu_zm_cac_backing.zstats.sha256"

if [ "$find_only" -eq 1 ]; then
    echo "Plutonium: $root"
    echo "Black Ops II storage: $storage"
    if [ -d "$destination" ]; then echo "ZStats installed: yes"; else echo "ZStats installed: no"; fi
    if [ -f "$image_destination" ]; then echo "ZStats background installed: yes"; else echo "ZStats background installed: no"; fi
    exit 0
fi

if [ "$uninstall" -eq 1 ]; then
    if [ ! -d "$destination" ] && [ ! -f "$image_marker" ]; then
        echo "ZStats is not installed at the selected location."
        exit 0
    fi
    if [ "$yes" -ne 1 ]; then
        read -r -p "Remove $destination? [y/N] " answer
        case "$answer" in y|Y|yes|YES) ;; *) exit 0 ;; esac
    fi
    if [ -d "$destination" ]; then rm -rf -- "$destination"; fi
    image_owned=0
    if [ -f "$image_destination" ] && [ -f "$image_marker" ] && [ "$(hash_file "$image_destination")" = "$(cat "$image_marker")" ]; then
        image_owned=1
    fi
    if [ "$image_owned" -eq 1 ]; then
        if [ -f "$image_backup" ]; then
            mv -f -- "$image_backup" "$image_destination"
            echo "Restored the previous menu_zm_cac_backing texture."
        else
            rm -f -- "$image_destination"
            echo "Removed the ZStats menu background texture."
        fi
    elif [ -f "$image_marker" ]; then
        echo "Warning: menu_zm_cac_backing changed after installation; leaving it and any backup untouched."
    fi
    rm -f -- "$image_marker"
    echo "Removed ZStats from $destination"
    exit 0
fi

if [ ! -d "$source_dir" ]; then
    echo "The T6 payload is missing. Extract the complete release zip before installing."
    exit 1
fi
if [ ! -f "$source_image" ]; then
    echo "The T6 menu background payload is missing. Extract the complete release zip before installing."
    exit 1
fi
if [ "$yes" -ne 1 ]; then
    read -r -p "Install ZStats to $destination? [Y/n] " answer
    case "$answer" in n|N|no|NO) exit 0 ;; esac
fi

mkdir -p "$(dirname "$destination")"
rm -rf -- "$destination"
cp -R -- "$source_dir" "$destination"
mkdir -p "$image_dir"
image_owned=0
if [ -f "$image_destination" ] && [ -f "$image_marker" ] && [ "$(hash_file "$image_destination")" = "$(cat "$image_marker")" ]; then
    image_owned=1
fi
if [ -f "$image_destination" ] && [ "$image_owned" -ne 1 ] && [ ! -f "$image_backup" ]; then
    cp -- "$image_destination" "$image_backup"
fi
cp -- "$source_image" "$image_destination"
hash_file "$source_image" > "$image_marker"
echo "Installed ZStats to $destination"
echo "Installed ZStats menu background to $image_destination"
