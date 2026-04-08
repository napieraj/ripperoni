#!/bin/sh
# dvd-video. same makemkv circus, longer minlength so menu loops don't own you

handler_run() {
    drive=$1
    detect_file=$2
    output_dir=$3
    # same arity as the other handlers; DVD path ignores the detect blob. blame the API, not us.
    : "$detect_file"

    command -v makemkvcon >/dev/null 2>&1 || die "makemkvcon not installed"

    platform_sleep_inhibit_start
    trap 'platform_sleep_inhibit_stop' EXIT INT TERM

    min_length=${makemkv_min_length_dvd:-300}
    log_info "ripping DVD with minlength=$min_length"

    disc=$(makemkv_disc_index_for_drive "$drive")
    log_info "makemkv disc index: $disc"

    makemkvcon \
        --progress=-same \
        --minlength="$min_length" \
        mkv "disc:$disc" all "$output_dir" \
        2>&1 | tee "$output_dir/ripperoni.log"
    rc=$?

    platform_sleep_inhibit_stop
    return $rc
}
