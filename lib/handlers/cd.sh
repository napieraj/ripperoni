#!/bin/sh
# audio CDs. cyanrip + MusicBrainz + AccurateRip — basically a whole mood

handler_run() {
    drive=$1
    detect_file=$2
    output_dir=$3
    # we take detect_file because every handler has to match the same sad function shape.
    # CDs don't care about your JSON feelings. shellcheck cares; we appease it with a no-op.
    : "$detect_file"

    command -v cyanrip >/dev/null 2>&1 || die "cyanrip not installed"

    offset=${cd_offset:-6}
    format=${cd_format:-flac}
    log_info "ripping CD (offset=$offset, format=$format)"

    # cyanrip flags in plain clothes:
    # -s offset  -S paranoid  -o format  -D out dir
    cyanrip \
        -d "$drive" \
        -s "$offset" \
        -S \
        -o "$format" \
        -D "$output_dir" \
        2>&1 | tee "$output_dir/ripperoni.log"
    rc=$?

    # grep the log for "not accurate" and judge you softly
    if grep -qi 'not accurate' "$output_dir/ripperoni.log" 2>/dev/null; then
        log_warn "one or more tracks not AccurateRip-verified"
    fi

    return $rc
}
