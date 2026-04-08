#!/bin/sh
# shared noise (logs), death (die), and crypto trivia nobody agrees on
# everyone sources this. try not to run rm -rf / on import thanks

# --- logging --------------------------------------------------------------

log_info() {
    [ "${RIPPERONI_QUIET:-0}" = "1" ] && return 0
    printf '\033[0;36m[info]\033[0m %s\n' "$*" >&2
}

log_warn() {
    printf '\033[0;33m[warn]\033[0m %s\n' "$*" >&2
}

log_error() {
    printf '\033[0;31m[error]\033[0m %s\n' "$*" >&2
}

log_debug() {
    [ "${RIPPERONI_VERBOSE:-0}" = "1" ] || return 0
    printf '\033[0;90m[debug]\033[0m %s\n' "$*" >&2
}

die() {
    log_error "$*"
    exit 1
}

# --- checksums (pick your fighter: gnu vs bsd vs nothing) -----------------

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        die "no sha256 tool available (install coreutils or use shasum)"
    fi
}

sha256_write() {
    # file + sidecar. same dual-tool nonsense as sha256_file
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$(dirname "$1")" && sha256sum "$(basename "$1")") >"$2"
    elif command -v shasum >/dev/null 2>&1; then
        (cd "$(dirname "$1")" && shasum -a 256 "$(basename "$1")") >"$2"
    else
        die "no sha256 tool available (install coreutils or use shasum)"
    fi
}

# --- paths ----------------------------------------------------------------

path_abs() {
    # no readlink -f on mac. we cope
    case "$1" in
        /*) echo "$1" ;;
        *)  echo "$(pwd)/$1" ;;
    esac
}

# --- iso8601 timestamp ----------------------------------------------------

now_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# --- meta (paper trail so future-you can blame past-you) ------------------

meta_write() {
    # output_dir drive detect_file handler — write the receipt
    output_dir=$1
    drive=$2
    detect_file=$3
    handler=$4
    meta="$output_dir/ripperoni.meta"

    {
        echo "# ripperoni.meta — provenance record"
        echo "rip_version=${RIPPERONI_VERSION:-unknown}"
        echo "timestamp=$(now_iso)"
        echo "host=$(uname -n)"
        echo "os=$(uname -s)"
        echo "arch=$(uname -m)"
        echo "drive=$drive"
        echo "handler=$handler"
        echo "# --- detected disc ---"
        cat "$detect_file"
    } >"$meta"
}
