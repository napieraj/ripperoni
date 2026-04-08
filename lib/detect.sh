#!/bin/sh
# figure out what you shoved in the slot. prints KEY=value lines for the cult ritual of `source`
# must set TYPE. LABEL/SIZE_BYTES/etc if we feel like it
# types: bd bd-uhd dvd cd data game mixed (and regret)

detect_run() {
    drive=$1
    override_type=$2

    if [ -n "$override_type" ]; then
        echo "TYPE=$override_type"
        echo "LABEL="
        echo "DETECT_SOURCE=override"
        return 0
    fi

    case "$RIPPERONI_OS" in
        linux)  _detect_linux "$drive" ;;
        macos)  _detect_macos "$drive" ;;
    esac
}

_detect_linux() {
    drive=$1

    # udev knows things. thank udev. feed udev /dev/srN
    if command -v udevadm >/dev/null 2>&1; then
        props=$(udevadm info --query=property --name="$drive" 2>/dev/null)

        is_bd=$(echo "$props" | awk -F= '/^ID_CDROM_MEDIA_BD=1/ { print 1 }')
        is_dvd=$(echo "$props" | awk -F= '/^ID_CDROM_MEDIA_DVD=1/ { print 1 }')
        is_cd=$(echo "$props" | awk -F= '/^ID_CDROM_MEDIA_CD=1/ { print 1 }')
        has_audio=$(echo "$props" | awk -F= '/^ID_CDROM_MEDIA_TRACK_COUNT_AUDIO=/ { print $2 }')
        has_data=$(echo "$props" | awk -F= '/^ID_CDROM_MEDIA_TRACK_COUNT_DATA=/ { print $2 }')
        label=$(echo "$props" | awk -F= '/^ID_FS_LABEL=/ { print $2 }')

        if [ "$is_bd" = "1" ]; then
            # BD vs UHD: udev shrugs, makemkv picks a fight with AACS in the parking lot
            type=$(_probe_uhd "$drive")
            echo "TYPE=$type"
            echo "LABEL=${label:-}"
            echo "DETECT_SOURCE=udev+makemkvcon"
            return 0
        elif [ "$is_dvd" = "1" ]; then
            echo "TYPE=dvd"
            echo "LABEL=${label:-}"
            echo "DETECT_SOURCE=udev"
            return 0
        elif [ "$is_cd" = "1" ]; then
            if [ -n "$has_audio" ] && [ "$has_audio" != "0" ]; then
                if [ -n "$has_data" ] && [ "$has_data" != "0" ]; then
                    echo "TYPE=mixed"
                else
                    echo "TYPE=cd"
                fi
                echo "TRACKS=$has_audio"
            else
                echo "TYPE=data"
            fi
            echo "LABEL=${label:-}"
            echo "DETECT_SOURCE=udev"
            return 0
        fi
    fi

    # udev failed you? makemkv is Plan B. Plan B talks too much
    _detect_via_makemkvcon "$drive"
}

_detect_macos() {
    drive=$1
    # drutil xml. still better than guessing from LED blink patterns
    out=$(drutil -drive "$drive" status -xml 2>/dev/null) || {
        echo "TYPE=unknown"
        return 1
    }

    media=$(echo "$out" | awk '
        /<key>MediaType<\/key>/ { getline; gsub(/<[^>]+>/, ""); gsub(/^ +| +$/, ""); print; exit }
    ')

    case "$media" in
        *BD*)
            type=$(_probe_uhd "$drive")
            echo "TYPE=$type"
            echo "DETECT_SOURCE=drutil+makemkvcon"
            ;;
        *DVD*)
            echo "TYPE=dvd"
            echo "DETECT_SOURCE=drutil"
            ;;
        *CD*)
            # audio cd vs data cd? drutil mumbles. we punt to other tools and hope
            _detect_cd_kind "$drive"
            echo "DETECT_SOURCE=drutil+probe"
            ;;
        *)
            _detect_via_makemkvcon "$drive"
            ;;
    esac
}

_probe_uhd() {
    # "is this UHD" — grep for scary strings. science
    drive=$1
    command -v makemkvcon >/dev/null 2>&1 || { echo bd; return; }

    disc=$(makemkv_disc_index_for_drive "$drive")
    out=$(makemkvcon -r info "disc:$disc" 2>/dev/null || true)

    if echo "$out" | grep -qi 'AACS2\|UHD\|Ultra HD'; then
        echo bd-uhd
    else
        # shrug → bd. libredrive might save your evening anyway
        echo bd
    fi
}

_detect_cd_kind() {
    # TODO real audio-vs-data probe. today: assume cd and let cyanrip yell if we're wrong
    echo "TYPE=cd"
}

_detect_via_makemkvcon() {
    drive=$1
    command -v makemkvcon >/dev/null 2>&1 || {
        echo "TYPE=unknown"
        return 1
    }

    disc=$(makemkv_disc_index_for_drive "$drive")
    out=$(makemkvcon -r info "disc:$disc" 2>/dev/null || true)

    if echo "$out" | grep -qi 'Blu-ray\|BD'; then
        if echo "$out" | grep -qi 'AACS2\|UHD'; then
            echo "TYPE=bd-uhd"
        else
            echo "TYPE=bd"
        fi
    elif echo "$out" | grep -qi 'DVD'; then
        echo "TYPE=dvd"
    else
        echo "TYPE=unknown"
        return 1
    fi
    echo "DETECT_SOURCE=makemkvcon"
}
