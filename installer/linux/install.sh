#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: ./install.sh [--root PLUTONIUM_DIR] [--state-root DIR] [--mode mod|script] [--install|--uninstall|--find|--verify|--configure] [--yes]"
}

root="${PLUTONIUM_DIR:-}"
state_root=''
yes=0
uninstall=0
find_only=0
verify=0
configure=0
mode=mod

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root|--state-root)
            option="$1"; shift
            [ "$#" -gt 0 ] || { usage; exit 2; }
            if [ "$option" = --root ]; then root="$1"; else state_root="$1"; fi ;;
        --install) ;;
        --yes) yes=1 ;;
        --uninstall) uninstall=1 ;;
        --find) find_only=1 ;;
        --verify) verify=1 ;;
        --configure) configure=1 ;;
        --mode) shift; mode="${1:-}" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done
case "$mode" in mod|script) ;; *) usage; exit 2 ;; esac

normalize_root() {
    if command -v cygpath >/dev/null 2>&1 && [[ "$1" =~ ^[A-Za-z]:[\\/] ]]; then
        cygpath -u "$1"
    else
        printf '%s' "$1"
    fi
}
[ -z "$root" ] || root="$(normalize_root "$root")"
[ -z "$state_root" ] || state_root="$(normalize_root "$state_root")"

if [ "$configure" -eq 1 ]; then
    echo 'Set zs_* options in the Plutonium console before starting a match.'
    echo 'For example: seta zs_hud_preset detailed'
    echo 'The loose T6 script has no lobby or pause-menu Lua. Career PB storage needs the mod menu.'
    exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
download="$(cd "$script_dir/../.." && pwd)"
if [ -f "$script_dir/tools/build.py" ]; then
    download="$script_dir/dist/t6/src"
fi
source_dir="$download/Plutonium/storage/t6/mods/zm_zstats"
source_image="$download/Plutonium/storage/t6/images/menu_zm_cac_backing.iwi"
source_script="$download/Plutonium/storage/t6/scripts/zm/zstats.gsc"

hash_file() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    else shasum -a 256 "$1" | awk '{print $1}'; fi
}

if [ -z "$root" ]; then
    roots=("$HOME/.steam/steam" "$HOME/.steam/root" "$HOME/.local/share/Steam"
           "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
           "$HOME/.var/app/com.valvesoftware.Steam/data/Steam")
    for mount in /run/media/mmcblk0p1 /run/media/deck/* /run/media/*; do
        [ -d "$mount/steamapps" ] && roots+=("$mount")
    done
    libraries=()
    for steam in "${roots[@]}"; do
        [ -d "$steam/steamapps" ] || continue
        libraries+=("$steam")
        vdf="$steam/steamapps/libraryfolders.vdf"
        if [ -f "$vdf" ]; then
            while IFS= read -r library; do [ -d "$library/steamapps" ] && libraries+=("$library"); done \
                < <(grep -oE '"path"[[:space:]]+"[^"]+"' "$vdf" 2>/dev/null |
                    sed -E 's/.*"path"[[:space:]]+"([^"]+)".*/\1/')
        fi
    done
    candidates=("$HOME/.local/share/Plutonium" "$HOME/Plutonium"
                "$HOME/.wine/drive_c/users"/*/AppData/Local/Plutonium
                "$HOME/Games/Heroic/Prefixes"/*/drive_c/users/*/AppData/Local/Plutonium
                "$HOME/.var/app/com.heroicgameslauncher.hgl/config/heroic/Prefixes"/*/drive_c/users/*/AppData/Local/Plutonium
                "$HOME/.local/share/lutris/prefixes"/*/drive_c/users/*/AppData/Local/Plutonium
                "$HOME/.local/share/bottles/bottles"/*/drive_c/users/*/AppData/Local/Plutonium)
    for library in "${libraries[@]}"; do
        candidates+=("$library/steamapps/compatdata"/*/pfx/drive_c/users/*/AppData/Local/Plutonium)
    done
    for candidate in "${candidates[@]}"; do
        if [ -d "$candidate/storage/t6" ]; then root="$candidate"; break; fi
    done
fi
if [ -z "$root" ] && [ "$find_only" -eq 1 ]; then
    echo 'Plutonium folder not found. Pass --root.'
    exit 0
fi
if [ -z "$root" ]; then read -r -p "Plutonium folder: " root; fi
if [ -z "$root" ]; then
    echo "No Plutonium folder was supplied."
    exit 2
fi
if [ ! -d "$root" ]; then
    echo "Plutonium folder does not exist: $root"
    exit 1
fi

storage="${root%/}/storage/t6"
destination="$storage/mods/zm_zstats"
image_dir="$storage/images"
image_destination="$image_dir/menu_zm_cac_backing.iwi"
image_backup="$image_dir/menu_zm_cac_backing.zstats-backup.iwi"
image_marker="$image_dir/menu_zm_cac_backing.zstats.sha256"
script_destination="$storage/scripts/zm/zstats.gsc"
script_marker="$script_destination.zstats.sha256"
script_backup="$script_destination.zstats-backup"
mod_files=('zstats.iwd' 'scripts/zm/zstats.gsc')

log_action() {
    printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" >> "$log_file"
}
prepare_log() {
    local state="${state_root:-${XDG_STATE_HOME:-$HOME/.local/state}/zstats}"
    mkdir -p "$state"
    log_file="$state/install.log"
    log_action plan "$mode $root"
}
marker_matches() {
    [ -f "$1" ] && [ -f "$2" ] &&
        [ "$(hash_file "$1")" = "$(tr -d '\r\n' < "$2" | tr '[:upper:]' '[:lower:]')" ]
}
owned() {
    marker_matches "$1" "$1.zstats.sha256"
}
legacy() {
    [ -f "$1" ] || return 1
    local own_path="${1%.zstats-backup}"
    if [ "$own_path" = "$script_destination" ] || [ "$own_path" = "$destination/scripts/zm/zstats.gsc" ]; then
        head -n 1 "$1" | grep -q '^// ZSTATS T6'
    elif [ "$own_path" = "$destination/zstats.iwd" ]; then
        LC_ALL=C grep -aq 'ui/t6/menus/zstatssettings.lua' "$1"
    else
        return 1
    fi
}
managed() {
    owned "$1" || { [ ! -f "$1.zstats.sha256" ] && legacy "$1"; }
}
install_file() {
    local from="$1" target="$2" backup="$2.zstats-backup"
    if [ -f "$target" ] && ! managed "$target" && [ -f "$backup" ]; then
        echo "Cannot replace changed file while its backup already exists: $target" >&2
        return 1
    fi
    mkdir -p "$(dirname "$target")"
    if [ -f "$target" ] && ! managed "$target"; then
        cp -- "$target" "$backup"
        log_action backed-up "$target"
    fi
    cp -- "$from" "$target"
    hash_file "$target" > "$target.zstats.sha256"
    log_action installed "$target"
}
remove_file() {
    local target="$1" backup="$1.zstats-backup"
    if ! managed "$target"; then
        echo "Warning: modified or unowned file left alone: $target"
        log_action left-unowned "$target"
        return 0
    fi
    rm -- "$target"
    if [ -f "$backup" ]; then
        if legacy "$backup"; then
            log_action left-legacy-backup "$backup"
        else
            mv -- "$backup" "$target"
            log_action restored "$target"
        fi
    else
        log_action removed "$target"
    fi
    if [ -f "$target.zstats.sha256" ]; then rm -- "$target.zstats.sha256"; fi
}

if [ "$mode" = script ]; then
    if [ "$find_only" -eq 1 ]; then
        echo "T6 loose script: $script_destination"
        if [ -f "$script_destination" ]; then echo 'Installed: yes'; else echo 'Installed: no'; fi
        exit 0
    fi
    if [ "$verify" -eq 1 ]; then
        if [ ! -f "$source_script" ] || [ ! -f "$script_destination" ] ||
           [ "$(hash_file "$source_script")" != "$(hash_file "$script_destination")" ]; then
            echo 'The T6 loose script is absent or differs from this download.'
            exit 1
        fi
        echo 'Verified the T6 loose script.'
        exit 0
    fi
    if [ "$uninstall" -eq 1 ]; then
        if ! managed "$script_destination"; then
            echo 'The T6 loose script is absent, modified, or unowned; left alone.'
            exit 0
        fi
        if [ "$yes" -ne 1 ]; then
            read -r -p "Remove $script_destination? [y/N] " answer
            case "$answer" in y|Y|yes|YES) ;; *) exit 0 ;; esac
        fi
        prepare_log
        remove_file "$script_destination"
        echo 'Removed the T6 loose script.'
        exit 0
    fi
    [ -f "$source_script" ] || { echo 'The T6 script payload is missing.'; exit 1; }
    if [ "$yes" -ne 1 ]; then
        read -r -p "Install T6 loose script to $script_destination? [Y/n] " answer
        case "$answer" in n|N|no|NO) exit 0 ;; esac
    fi
    prepare_log
    install_file "$source_script" "$script_destination"
    echo "Installed T6 loose script to $script_destination"
    exit 0
fi

if [ "$verify" -eq 1 ]; then
    for relative in "${mod_files[@]}"; do
        if [ ! -f "$source_dir/$relative" ] || [ ! -f "$destination/$relative" ] ||
           [ "$(hash_file "$source_dir/$relative")" != "$(hash_file "$destination/$relative")" ]; then
            echo "The T6 mod file is absent or differs: $relative"
            exit 1
        fi
    done
    echo 'Verified the T6 mod files.'
    exit 0
fi

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
    prepare_log
    for relative in "${mod_files[@]}"; do remove_file "$destination/$relative"; done
    image_owned=0
    if marker_matches "$image_destination" "$image_marker"; then
        image_owned=1
    fi
    if [ "$image_owned" -eq 1 ]; then
        if [ -f "$image_backup" ]; then
            mv -f -- "$image_backup" "$image_destination"
            log_action restored "$image_destination"
            echo "Restored the previous menu_zm_cac_backing texture."
        else
            rm -f -- "$image_destination"
            log_action removed "$image_destination"
            echo "Removed the ZStats menu background texture."
        fi
    elif [ -f "$image_marker" ]; then
        echo "Warning: menu_zm_cac_backing changed after installation; leaving it and any backup untouched."
    fi
    if [ "$image_owned" -eq 1 ]; then rm -f -- "$image_marker"; fi
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
for relative in "${mod_files[@]}"; do
    [ -f "$source_dir/$relative" ] || { echo "The T6 mod payload is missing: $relative"; exit 1; }
done
if [ "$yes" -ne 1 ]; then
    read -r -p "Install ZStats to $destination? [Y/n] " answer
    case "$answer" in n|N|no|NO) exit 0 ;; esac
fi

for relative in "${mod_files[@]}"; do
    target="$destination/$relative"
    if [ -f "$target" ] && ! managed "$target" && [ -f "$target.zstats-backup" ]; then
        echo "Cannot replace changed file while its backup already exists: $target" >&2
        exit 1
    fi
done
if [ -f "$image_destination" ] && ! marker_matches "$image_destination" "$image_marker" &&
   [ -f "$image_backup" ]; then
    echo "Cannot replace changed image while its backup already exists: $image_destination" >&2
    exit 1
fi
prepare_log
for relative in "${mod_files[@]}"; do install_file "$source_dir/$relative" "$destination/$relative"; done
mkdir -p "$image_dir"
image_owned=0
if marker_matches "$image_destination" "$image_marker"; then
    image_owned=1
fi
if [ -f "$image_destination" ] && [ "$image_owned" -ne 1 ] && [ ! -f "$image_backup" ]; then
    cp -- "$image_destination" "$image_backup"
fi
cp -- "$source_image" "$image_destination"
hash_file "$source_image" > "$image_marker"
log_action installed "$image_destination"
echo "Installed ZStats to $destination"
echo "Installed ZStats menu background to $image_destination"
