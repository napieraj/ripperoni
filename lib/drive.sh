#!/bin/sh
# drives: list them, guess which one you meant, beg MakeMKV for a number

drive_list() {
    case "$RIPPERONI_OS" in
        linux)
            # no sr* node → no drive. kernel doesn't lie as much as drutil
            for d in /dev/sr*; do
                [ -e "$d" ] || continue
                model=$(_drive_model_linux "$d")
                fw=$(_drive_firmware_linux "$d")
                printf "%-12s  %-30s  fw %s\n" "$d" "$model" "$fw"
            done
            ;;
        macos)
            # drutil: occasionally helpful, always smug
            drutil list 2>/dev/null | awk '
                NR > 1 && NF >= 4 {
                    # fields: num, vendor, product, rev [, bus, support]
                    printf "drive %s  %s %s  fw %s\n", $1, $2, $3, $4
                }'
            ;;
    esac
}

drive_autodetect() {
    case "$RIPPERONI_OS" in
        linux)
            for d in /dev/sr0 /dev/sr1 /dev/sr2; do
                [ -e "$d" ] && { echo "$d"; return 0; }
            done
            return 1
            ;;
        macos)
            # yeah the "path" is just "1". don't @ me, @ apple
            if drutil list 2>/dev/null | grep -q '^ *1 '; then
                echo "1"
                return 0
            fi
            return 1
            ;;
    esac
}

_drive_model_linux() {
    # sysfs says who made the thing
    dev=$(basename "$1")
    vendor=
    model=
    [ -r "/sys/block/$dev/device/vendor" ] && vendor=$(tr -d ' ' < "/sys/block/$dev/device/vendor")
    [ -r "/sys/block/$dev/device/model" ] && model=$(tr -d ' ' < "/sys/block/$dev/device/model")
    echo "${vendor:-?} ${model:-?}"
}

_drive_firmware_linux() {
    dev=$(basename "$1")
    [ -r "/sys/block/$dev/device/rev" ] && tr -d ' ' < "/sys/block/$dev/device/rev" || echo "?"
}

drive_macos_bsd_node() {
    drive=$1

    case "$RIPPERONI_OS" in
        macos) ;;
        *)
            return 1
            ;;
    esac

    case "$drive" in
        /dev/disk[0-9]*)
            printf '%s\n' "$drive"
            return 0
            ;;
    esac

    case "$drive" in
        ''|*[!0-9]*)
            return 1
            ;;
    esac

    command -v drutil >/dev/null 2>&1 || return 1

    bsd=$(drutil list 2>/dev/null | awk -v want="$drive" '
        $1 == want {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^\/dev\/disk[0-9]+$/) {
                    print $i
                    exit 0
                }
            }
        }
    ')

    [ -n "$bsd" ] || return 1
    printf '%s\n' "$bsd"
}

# --- MakeMKV disc index (WHY is this not the same as /dev/sr1. WHY.) -------
# parse DRV: spam from `makemkvcon -r info disc:9999` and pray

makemkv_disc_index_for_drive() {
    drive=$1

    if [ -n "${RIPPERONI_MAKEMKV_DISC:-}" ]; then
        echo "$RIPPERONI_MAKEMKV_DISC"
        return 0
    fi

    command -v makemkvcon >/dev/null 2>&1 || {
        echo 0
        return 0
    }

    out=$(makemkvcon -r --cache=1 info disc:9999 2>&1 || true)

    idx=$(printf '%s\n' "$out" | awk -v d="$drive" '
        /^DRV:/ {
            line = $0
            sub(/^DRV:/, "", line)
            if (match(line, /^[0-9]+/)) {
                di = substr(line, RSTART, RLENGTH)
                if (index(line, "\"" d "\"") > 0) {
                    print di
                    exit 0
                }
            }
        }
    ')

    if [ -n "$idx" ]; then
        echo "$idx"
        return 0
    fi

    case "$RIPPERONI_OS" in
        macos)
            case "$drive" in
                ''|*[!0-9]*) ;;
                *)
                    idx=$((drive - 1))
                    [ "$idx" -lt 0 ] && idx=0
                    if printf '%s\n' "$out" | grep -q "^DRV:$idx,"; then
                        echo "$idx"
                        return 0
                    fi
                    ;;
            esac
            ;;
    esac

    log_warn "could not map drive \"$drive\" to a MakeMKV index; using disc:0 (set RIPPERONI_MAKEMKV_DISC to override)"
    echo 0
}

# --- LibreDrive (UHD stares at you until this says enabled) ---------------
# grep makemkv vomit. do NOT trust "but my drive is on the forum list" energy

drive_libredrive_status() {
    drive=$1
    command -v makemkvcon >/dev/null 2>&1 || {
        echo "unknown (makemkvcon not installed)"
        return 1
    }

    # 9999 = "hey makemkv list drives don't mount my cat" per upstream docs
    out=$(makemkvcon -r --cache=1 info disc:9999 2>&1 || true)

    if echo "$out" | grep -qi 'libredrive.*enabled'; then
        echo "enabled"
    elif echo "$out" | grep -qi 'libredrive'; then
        echo "present but not enabled"
    else
        echo "not detected"
    fi
}
