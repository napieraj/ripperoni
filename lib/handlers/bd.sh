#!/bin/sh
# blu-ray / UHD. makemkv does the work; we hold its jacket
# UHD without libredrive enabled = hard no. don't argue with the script

handler_run() {
    drive=$1
    detect_file=$2
    output_dir=$3

    command -v makemkvcon >/dev/null 2>&1 || die "makemkvcon not installed"

    # shellcheck disable=SC1090
    # need TYPE etc
    . "$detect_file"

    if [ "$TYPE" = "bd-uhd" ]; then
        ld_status=$(drive_libredrive_status "$drive")
        log_info "libredrive: $ld_status"
        case "$ld_status" in
            enabled) ;;
            *) die "UHD rip requires LibreDrive (status: $ld_status)" ;;
        esac
    fi

    platform_sleep_inhibit_start
    trap 'platform_sleep_inhibit_stop' EXIT INT TERM

    min_length=${makemkv_min_length_bd:-120}
    log_info "ripping with minlength=$min_length"

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
