#!/bin/sh
# mac vs penguin. third OSes can kick rocks until someone sends a patch

platform_init() {
    case "$(uname -s)" in
        Darwin) RIPPERONI_OS=macos ;;
        Linux)  RIPPERONI_OS=linux ;;
        *)      die "unsupported OS: $(uname -s)" ;;
    esac
    export RIPPERONI_OS
    log_debug "platform: $RIPPERONI_OS"
}

# --- please do not sleep mid-rip (rude) -----------------------------------

platform_sleep_inhibit_start() {
    [ "${sleep_inhibit:-1}" = "1" ] || return 0

    if [ -n "${RIPPERONI_INHIBIT_DIR:-}" ]; then
        RIPPERONI_CAFFEINATE_PIDFILE="$RIPPERONI_INHIBIT_DIR/caffeinate.pid"
        RIPPERONI_SYSTEMD_INHIBIT_PIDFILE="$RIPPERONI_INHIBIT_DIR/inhibit.pid"
    else
        t=${TMPDIR:-/tmp}
        RIPPERONI_CAFFEINATE_PIDFILE="$t/ripperoni.caffeinate.$$"
        RIPPERONI_SYSTEMD_INHIBIT_PIDFILE="$t/ripperoni.inhibit.$$"
    fi

    case "$RIPPERONI_OS" in
        macos)
            if command -v caffeinate >/dev/null 2>&1; then
                caffeinate -dims &
                echo $! >"$RIPPERONI_CAFFEINATE_PIDFILE"
            fi
            ;;
        linux)
            if command -v systemd-inhibit >/dev/null 2>&1; then
                # systemd wants a process. fine. sleep 24h it is, you weirdos
                systemd-inhibit --what=idle:sleep:handle-lid-switch \
                    --who=rip --why="ripping disc" \
                    sleep 86400 &
                echo $! >"$RIPPERONI_SYSTEMD_INHIBIT_PIDFILE"
            fi
            ;;
    esac
}

platform_sleep_inhibit_stop() {
    for pidfile in "${RIPPERONI_CAFFEINATE_PIDFILE:-}" "${RIPPERONI_SYSTEMD_INHIBIT_PIDFILE:-}"; do
        [ -n "$pidfile" ] || continue
        if [ -f "$pidfile" ]; then
            kill "$(cat "$pidfile")" 2>/dev/null || true
            rm -f "$pidfile"
        fi
    done
    RIPPERONI_CAFFEINATE_PIDFILE=
    RIPPERONI_SYSTEMD_INHIBIT_PIDFILE=
}

# --- default drive paths (mostly lies on mac; drutil does the real work) --

platform_default_drive_glob() {
    case "$RIPPERONI_OS" in
        macos) echo "/dev/disk*" ;;  # decorative. apple thinks different at us
        linux) echo "/dev/sr*" ;;
    esac
}
