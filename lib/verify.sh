#!/bin/sh
# did the rip actually rip or did we just make a pretty corrupt file
# verify_run is optional-ish via config/flags; checksum file still happens on success because paranoia wins

verify_run() {
    type=$1
    output_dir=$2

    case "$type" in
        bd|bd-uhd|dvd)  _verify_video "$output_dir" ;;
        cd)             _verify_audio "$output_dir" ;;
        data)           _verify_data  "$output_dir" ;;
        *)              log_warn "no verify step for type: $type" ;;
    esac
}

_verify_video() {
    output_dir=$1
    command -v ffmpeg >/dev/null 2>&1 || {
        log_warn "ffmpeg not installed, skipping video verification"
        return 0
    }

    failed=0
    for f in "$output_dir"/*.mkv; do
        [ -e "$f" ] || continue
        log_info "verifying $(basename "$f")"
        # separate err files so three mkvs don't write a novel in one file
        verr="$output_dir/verify.$(basename "$f").err"
        if ! ffmpeg -v error -i "$f" -f null - 2>"$verr"; then
            log_error "stream errors in $(basename "$f")"
            failed=1
        fi
        [ -s "$verr" ] || rm -f "$verr"
    done
    return $failed
}

_verify_audio() {
    output_dir=$1
    command -v flac >/dev/null 2>&1 || {
        log_warn "flac not installed, skipping audio verification"
        return 0
    }

    failed=0
    for f in "$output_dir"/*.flac; do
        [ -e "$f" ] || continue
        log_info "verifying $(basename "$f")"
        if ! flac -t "$f" >/dev/null 2>&1; then
            failed=1
            log_error "flac test failed: $f"
        fi
    done
    return $failed
}

_verify_data() {
    output_dir=$1
    # iso: if it's zero bytes something is deeply wrong with your life choices
    for f in "$output_dir"/*.iso; do
        [ -e "$f" ] || continue
        [ -s "$f" ] || { log_error "empty ISO: $f"; return 1; }
    done
    return 0
}

# --- checksum sidecar (hash the evidence) ---------------------------------

verify_checksums() {
    output_dir=$1
    checksum_file="$output_dir/$(basename "$output_dir").sha256"

    : >"$checksum_file"
    for f in "$output_dir"/*.mkv "$output_dir"/*.flac "$output_dir"/*.iso; do
        [ -e "$f" ] || continue
        hash=$(sha256_file "$f")
        printf '%s  %s\n' "$hash" "$(basename "$f")" >>"$checksum_file"
    done

    log_info "checksums written to $(basename "$checksum_file")"
}
