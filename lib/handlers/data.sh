#!/bin/sh
# data disc dump to a .iso. plain dd unless RIPPERONI_RESCUE asks for ddrescue
#
# mac/bsd: no status=progress. we fall through gnu → gdd → pv → sad silent dd
# pv ≠ conv=noerror,sync. bad sectors want ddrescue, not vibes

_data_dd_dump() {
    drive=$1
    iso=$2
    log=$3

    if dd if=/dev/zero of=/dev/null count=0 status=progress >/dev/null 2>&1; then
        dd if="$drive" of="$iso" bs=2048 status=progress conv=noerror,sync \
            2>&1 | tee "$log"
        return $?
    fi

    if command -v gdd >/dev/null 2>&1; then
        gdd if="$drive" of="$iso" bs=2048 status=progress conv=noerror,sync \
            2>&1 | tee "$log"
        return $?
    fi

    if command -v pv >/dev/null 2>&1; then
        # stderr → log only; never tee progress into the image unless you hate yourself
        if [ -n "${SIZE_BYTES:-}" ] && printf '%s' "$SIZE_BYTES" | grep -Eq '^[0-9]+$'; then
            pv -B 2048 -s "$SIZE_BYTES" "$drive" >"$iso" 2>>"$log"
        else
            pv -B 2048 "$drive" >"$iso" 2>>"$log"
        fi
        return $?
    fi

    dd if="$drive" of="$iso" bs=2048 conv=noerror,sync 2>&1 | tee "$log"
    return $?
}

handler_run() {
    drive=$1
    detect_file=$2
    output_dir=$3

    # shellcheck disable=SC1090
    . "$detect_file"

    label=${LABEL:-disc}
    iso="$output_dir/${label}.iso"

    log_info "dumping data disc to $(basename "$iso")"

    if [ "${RIPPERONI_RESCUE:-0}" = "1" ]; then
        command -v ddrescue >/dev/null 2>&1 || die "ddrescue not installed"
        ddrescue -b 2048 -n "$drive" "$iso" "$output_dir/ddrescue.map" \
            2>&1 | tee "$output_dir/ripperoni.log"
        rc=$?
    else
        _data_dd_dump "$drive" "$iso" "$output_dir/ripperoni.log"
        rc=$?
    fi

    return $rc
}
