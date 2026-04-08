#!/bin/sh
# doctor: poke the patient, count how many things hurt
# exit 0 fine, 1 warnings, 2 you're not ripping anything today buddy

set -eu

# child process = parent's variables do not exist. we re-source the world. c'est la vie
if [ -z "${RIPPERONI_ROOT:-}" ]; then
    RIPPERONI_ROOT=$(cd "$(dirname "$0")/.." && pwd)
fi
# shellcheck source=../lib/common.sh
. "$RIPPERONI_ROOT/lib/common.sh"
# shellcheck source=../lib/config.sh
. "$RIPPERONI_ROOT/lib/config.sh"
# shellcheck source=../lib/platform.sh
. "$RIPPERONI_ROOT/lib/platform.sh"
# shellcheck source=../lib/drive.sh
. "$RIPPERONI_ROOT/lib/drive.sh"
# shellcheck source=../lib/state.sh
. "$RIPPERONI_ROOT/lib/state.sh"
config_load
platform_init

drive=${1:-}

warnings=0
blockers=0

ok()    { printf '  \033[0;32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[0;33m!\033[0m %s\n' "$*"; warnings=$((warnings + 1)); }
fail()  { printf '  \033[0;31m✗\033[0m %s\n' "$*"; blockers=$((blockers + 1)); }

# version strings: everyone speaks a different dialect. table-driven nonsense below
_tool_version() {
    case "$1" in
        ffmpeg)
            ffmpeg -version 2>&1 | awk 'NR==1 { print $1, $2, $3; exit }'
            ;;
        flac)
            flac --version 2>&1 | head -1
            ;;
        ddrescue)
            ddrescue --version 2>&1 | awk 'NR==1 { print $NF; exit }' | sed 's/^/v/'
            ;;
        cyanrip)
            # cyanrip uses -V (capital, single dash). Falls back to "present"
            # if the option isn't recognized in some build.
            v=$(cyanrip -V 2>&1 | head -1)
            case "$v" in
                *cyanrip*|*[0-9].[0-9]*) echo "$v" ;;
                *) echo "present" ;;
            esac
            ;;
        makemkvcon)
            # makemkvcon has no version flag. Running it with no args prints
            # a banner including the version on stderr, then exits non-zero.
            v=$(makemkvcon 2>&1 | awk '/MakeMKV/ && /v[0-9]/ { print; exit }')
            [ -n "$v" ] && echo "$v" || echo "present"
            ;;
        dd)
            # GNU dd has --version; BSD/macOS dd does not. Try GNU first,
            # fall back to "present" silently.
            v=$(dd --version 2>/dev/null | head -1)
            [ -n "$v" ] && echo "$v" || echo "present"
            ;;
        redumper)
            redumper --version 2>&1 | head -1
            ;;
        *)
            echo "present"
            ;;
    esac
}

echo "ripperoni doctor"
echo

# --- binaries (or lack thereof) -------------------------------------------
echo "tools:"

for tool in makemkvcon cyanrip ffmpeg flac dd ddrescue redumper; do
    if command -v "$tool" >/dev/null 2>&1; then
        ver=$(_tool_version "$tool")
        ok "$tool ($ver)"
    else
        case "$tool" in
            makemkvcon|cyanrip|ffmpeg|flac)
                fail "$tool — required"
                ;;
            ddrescue|redumper)
                warn "$tool — optional"
                ;;
            *)
                warn "$tool — optional"
                ;;
        esac
    fi
done

# sha256sum OR shasum. pick one. any one
if command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; then
    ok "sha256 available"
else
    fail "no sha256 tool (install coreutils)"
fi

# --- optical hardware (if any) --------------------------------------------
echo
echo "drives:"
if drive_list 2>/dev/null | grep -q .; then
    drive_list | sed 's/^/  /'
else
    fail "no optical drives found"
fi

# --- libredrive (UHD crowd control) ---------------------------------------
if [ -n "$drive" ]; then
    echo
    echo "libredrive on $drive:"
    status=$(drive_libredrive_status "$drive" 2>&1 || echo "probe failed")
    case "$status" in
        enabled) ok "$status" ;;
        *)       warn "$status" ;;
    esac
fi

# --- drive state (as far as we can tell) ----------------------------------
if [ -n "$drive" ]; then
    echo
    echo "drive state:"
    s=$(state_read "$drive" 2>&1 || echo "unknown")
    echo "  $s"
fi

# --- disk space (rips are fat) --------------------------------------------
echo
echo "storage:"
if [ -d "$output_root" ] || mkdir -p "$output_root" 2>/dev/null; then
    # df -BG isn't portable because of course it isn't
    free_kb=$(df -k "$output_root" | awk 'NR==2 { print $4 }')
    free_gb=$((free_kb / 1024 / 1024))
    if [ "$free_gb" -lt 100 ]; then
        warn "output_root has ${free_gb}G free (< 100G)"
    else
        ok "output_root has ${free_gb}G free"
    fi

    # can we actually write there or are you pointing at a museum piece
    testfile="$output_root/.ripperoni-doctor-$$"
    if touch "$testfile" 2>/dev/null; then
        rm -f "$testfile"
        ok "output_root is writable"
    else
        fail "output_root is not writable: $output_root"
    fi
else
    fail "cannot create output_root: $output_root"
fi

# --- stay awake juice -----------------------------------------------------
echo
echo "sleep inhibit:"
case "$RIPPERONI_OS" in
    macos)
        if command -v caffeinate >/dev/null 2>&1; then
            ok "caffeinate available"
        else
            warn "caffeinate not found"
        fi
        ;;
    linux)
        if command -v systemd-inhibit >/dev/null 2>&1; then
            ok "systemd-inhibit available"
        else
            warn "systemd-inhibit not found (long rips may be interrupted by sleep)"
        fi
        ;;
esac

# --- verdict --------------------------------------------------------------
echo
if [ $blockers -gt 0 ]; then
    printf '\033[0;31m%d blocker(s), %d warning(s)\033[0m\n' "$blockers" "$warnings"
    exit 2
elif [ $warnings -gt 0 ]; then
    printf '\033[0;33m%d warning(s)\033[0m\n' "$warnings"
    exit 1
else
    printf '\033[0;32mall checks passed\033[0m\n'
    exit 0
fi
