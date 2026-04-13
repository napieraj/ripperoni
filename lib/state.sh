#!/bin/sh
# drive mood ring. NOT the same as detect.sh — that's "what disc", this is "what's the tray doing"
#
# states: unknown open loading empty ready busy error empty-or-open (last one is mac's fault)
# linux: ioctl 0x5326, works enough to impress your uncle
# mac: optional ripperoni-iokit-state (IOKit) → else drutil xml. see tools/macos-iokit-state/

# ripperoni-iokit-state stdout: open|empty|loading|ready|busy|unknown (one line).
# Shell uses only open|empty|loading|ready|busy; unknown → fall back to drutil.

# --- state read -----------------------------------------------------------

# Optional macOS helper: RIPPERONI_IOKIT_STATE=/path/to/binary, PATH, or .build under RIPPERONI_ROOT.
_iokit_helper_bin() {
    if [ -n "${RIPPERONI_IOKIT_STATE:-}" ] && [ -x "$RIPPERONI_IOKIT_STATE" ]; then
        printf '%s\n' "$RIPPERONI_IOKIT_STATE"
        return 0
    fi
    _ik=$(command -v ripperoni-iokit-state 2>/dev/null || true)
    if [ -n "$_ik" ] && [ -x "$_ik" ]; then
        printf '%s\n' "$_ik"
        return 0
    fi
    if [ -n "${RIPPERONI_ROOT:-}" ]; then
        for _p in \
            "$RIPPERONI_ROOT/tools/macos-iokit-state/.build/arm64-apple-macosx/release/ripperoni-iokit-state" \
            "$RIPPERONI_ROOT/tools/macos-iokit-state/.build/x86_64-apple-macosx/release/ripperoni-iokit-state" \
            "$RIPPERONI_ROOT/tools/macos-iokit-state/.build/release/ripperoni-iokit-state"
        do
            if [ -x "$_p" ]; then
                printf '%s\n' "$_p"
                return 0
            fi
        done
    fi
    return 1
}

# Prints a trusted state line on success; exit 1 → caller uses drutil.
_iokit_selector_for_drive() {
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

    _bsd=$(drive_macos_bsd_node "$drive" 2>/dev/null || true)
    [ -n "$_bsd" ] || return 1
    printf '%s\n' "$_bsd"
}

_iokit_state_try() {
    drive=$1
    _bin=$( _iokit_helper_bin ) || return 1
    _selector=$( _iokit_selector_for_drive "$drive" ) || return 1
    _line=$("$_bin" "$_selector" 2>/dev/null) || return 1
    _line=$(printf '%s\n' "$_line" | tr -d '\r')
    case "$_line" in
        open|empty|loading|ready|busy)
            printf '%s\n' "$_line"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Sets RIPPERONI_READ_STATE and (on macOS) RIPPERONI_STATE_SOURCE in the current shell.
# Use this instead of $(state_read) when you need RIPPERONI_STATE_SOURCE — command substitution runs in a subshell and drops that side effect.
_state_read_dispatch() {
    drive=$1
    case "$RIPPERONI_OS" in
        linux)
            RIPPERONI_STATE_SOURCE=ioctl
            RIPPERONI_READ_STATE=$( _state_read_linux "$drive" )
            ;;
        macos)
            if _ikout=$( _iokit_state_try "$drive" ); then
                RIPPERONI_STATE_SOURCE=iokit
                RIPPERONI_READ_STATE=$_ikout
            else
                RIPPERONI_STATE_SOURCE=drutil
                RIPPERONI_READ_STATE=$( _state_read_macos_drutil "$drive" )
            fi
            ;;
        *)
            RIPPERONI_STATE_SOURCE=
            RIPPERONI_READ_STATE=unknown
            ;;
    esac
}

state_read() {
    _state_read_dispatch "$1"
    printf '%s\n' "$RIPPERONI_READ_STATE"
}

_state_read_linux() {
    drive=$1
    [ -e "$drive" ] || { echo unknown; return; }

    # fuser heuristics: "busy" if more than one pid. yes it's a hack. you're welcome
    if command -v fuser >/dev/null 2>&1; then
        if fuser "$drive" >/dev/null 2>&1; then
            # if it's ONLY us, pretend we're not here
            holders=$(fuser "$drive" 2>/dev/null | tr -s ' ' '\n' | grep -c .)
            if [ "$holders" -gt 1 ]; then
                echo busy
                return
            fi
        fi
    fi

    # ioctl: python3, else python2 corpse, else perl. pick your trauma
    val=$(_ioctl_cdrom_status "$drive") || { echo unknown; return; }

    case "$val" in
        0) echo unknown ;;       # CDS_NO_INFO (cool story)
        1) echo empty ;;          # nothing in the slot
        2) echo open ;;           # close it
        3) echo loading ;;        # spinny boi
        4) echo ready ;;          # go time
        *) echo unknown ;;
    esac
}

_ioctl_cdrom_status() {
    drive=$1
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$drive" <<'PY' 2>/dev/null
import fcntl, os, sys
try:
    fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NONBLOCK)
    print(fcntl.ioctl(fd, 0x5326))
    os.close(fd)
except Exception:
    sys.exit(1)
PY
    elif command -v python >/dev/null 2>&1; then
        python - "$drive" <<'PY' 2>/dev/null
import fcntl, os, sys
try:
    fd = os.open(sys.argv[1], os.O_RDONLY | os.O_NONBLOCK)
    print(fcntl.ioctl(fd, 0x5326))
    os.close(fd)
except Exception:
    sys.exit(1)
PY
    elif command -v perl >/dev/null 2>&1; then
        perl - "$drive" <<'PL' 2>/dev/null
use strict;
use Fcntl;
sysopen(my $fh, $ARGV[0], O_RDONLY | O_NONBLOCK) or exit 1;
print ioctl($fh, 0x5326, 0) + 0, "\n";
close $fh;
PL
    else
        return 1
    fi
}

_state_read_macos_drutil() {
    drive=$1
    # drive is literally "1" or "2". apple numbered them like apartments
    command -v drutil >/dev/null 2>&1 || { echo unknown; return; }

    # plist xml. we grep like cavemen. MediaType present → something's in there
    out=$(drutil -drive "$drive" status -xml 2>/dev/null) || {
        echo unknown
        return
    }

    if echo "$out" | grep -q '<key>MediaType</key>'; then
        # disc in, toc-ish readable
        echo ready
    elif echo "$out" | grep -q '<key>IsBusy</key>'; then
        # sometimes "busy" during spin-up. sure. ok.
        if echo "$out" | grep -A1 'IsBusy' | grep -q '<true/>'; then
            echo loading
            return
        fi
        echo empty-or-open
    else
        echo empty-or-open
    fi
}

# --- wait -----------------------------------------------------------------

state_wait() {
    # drive target timeout — wait until the universe aligns
    drive=$1
    target=$2
    timeout=${3:-30}

    waited=0
    delay_ms=100
    max_delay_ms=1000

    while [ "$waited" -lt "$((timeout * 1000))" ]; do
        current=$(state_read "$drive")
        if [ "$current" = "$target" ]; then
            return 0
        fi
        # exponential nap. we're not polling like a jackhammer
        _sleep_ms "$delay_ms"
        waited=$((waited + delay_ms))
        delay_ms=$((delay_ms * 2))
        [ "$delay_ms" -gt "$max_delay_ms" ] && delay_ms=$max_delay_ms
    done

    return 1
}

_sleep_ms() {
    # sleep only speaks seconds. awk does the millisecond cosplay
    ms=$1
    sleep "$(awk "BEGIN { printf \"%.3f\", $ms / 1000 }")"
}

# --- wiretap (JSON soap opera of your drive) ------------------------------
# poll poll poll. someday: real events. today: loops and spite

state_wiretap() {
    drive=$1
    last=""

    log_info "wiretapping $drive (Ctrl-C to stop)"

    while :; do
        _state_read_dispatch "$drive"
        current=$RIPPERONI_READ_STATE
        case "$RIPPERONI_OS" in
            linux) wire_src=ioctl ;;
            *)     wire_src=${RIPPERONI_STATE_SOURCE:-drutil} ;;
        esac
        if [ "$current" != "$last" ] && [ -n "$last" ]; then
            ts=$(now_iso)
            printf '{"ts":"%s","drive":"%s","from":"%s","to":"%s","source":"%s"}\n' \
                "$ts" "$drive" "$last" "$current" "$wire_src"
        elif [ -z "$last" ]; then
            ts=$(now_iso)
            printf '{"ts":"%s","drive":"%s","from":null,"to":"%s","source":"%s"}\n' \
                "$ts" "$drive" "$current" "$wire_src"
        fi
        last=$current
        sleep 1
    done
}

# --- eject / close --------------------------------------------------------

state_eject() {
    drive=$1
    case "$RIPPERONI_OS" in
        linux)
            if command -v eject >/dev/null 2>&1; then
                eject "$drive"
            else
                die "eject(1) not installed"
            fi
            ;;
        macos)
            drutil -drive "$drive" tray eject
            ;;
    esac
}

state_close() {
    drive=$1
    case "$RIPPERONI_OS" in
        linux)
            # kernel might admit the tray can't close itself. believe it
            if [ -r /proc/sys/dev/cdrom/info ]; then
                can=$(awk '/Can close tray/ { print $NF }' /proc/sys/dev/cdrom/info)
                if [ "$can" = "0" ]; then
                    log_warn "drive reports it cannot motorized-close the tray"
                    return 1
                fi
            fi
            if command -v eject >/dev/null 2>&1; then
                eject -t "$drive"
            else
                die "eject(1) not installed"
            fi
            ;;
        macos)
            drutil -drive "$drive" tray close
            ;;
    esac
}
