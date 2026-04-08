#!/bin/sh
# drive mood ring. NOT the same as detect.sh — that's "what disc", this is "what's the tray doing"
#
# states: unknown open loading empty ready busy error empty-or-open (last one is mac's fault)
# linux: ioctl 0x5326, works enough to impress your uncle
# mac: xml + vibes. empty vs open? apple says ¯\_(ツ)_/¯

# --- state read -----------------------------------------------------------

state_read() {
    drive=$1
    case "$RIPPERONI_OS" in
        linux)  _state_read_linux "$drive" ;;
        macos)  _state_read_macos "$drive" ;;
        *)      echo unknown ;;
    esac
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

_state_read_macos() {
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
    source_tag=$([ "$RIPPERONI_OS" = "linux" ] && echo ioctl || echo drutil)

    log_info "wiretapping $drive (Ctrl-C to stop)"

    while :; do
        current=$(state_read "$drive")
        if [ "$current" != "$last" ] && [ -n "$last" ]; then
            ts=$(now_iso)
            printf '{"ts":"%s","drive":"%s","from":"%s","to":"%s","source":"%s"}\n' \
                "$ts" "$drive" "$last" "$current" "$source_tag"
        elif [ -z "$last" ]; then
            ts=$(now_iso)
            printf '{"ts":"%s","drive":"%s","from":null,"to":"%s","source":"%s"}\n' \
                "$ts" "$drive" "$current" "$source_tag"
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
