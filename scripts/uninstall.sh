#!/bin/sh
set -eu

usage() {
    cat <<'EOF'
usage: scripts/uninstall.sh [--user] [--prefix <path>]

remove ripperoni from <prefix>/bin/ripperoni.

options:
  --user            target ~/.local/bin
  --prefix <path>   uninstall prefix override
  -h, --help        show this help

env:
  PREFIX            same as --prefix
EOF
}

use_user=0
prefix="${PREFIX:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --user)
            use_user=1
            shift
            ;;
        --prefix)
            [ $# -ge 2 ] || {
                echo "error: --prefix needs a value" >&2
                exit 1
            }
            prefix=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ -z "$prefix" ]; then
    if [ "$use_user" = "1" ]; then
        prefix="$HOME/.local"
    else
        os=$(uname -s)
        arch=$(uname -m)
        case "$os:$arch" in
            Darwin:arm64)
                if [ -d "/opt/homebrew/bin" ] || [ -w "/opt/homebrew" ]; then
                    prefix="/opt/homebrew"
                else
                    prefix="/usr/local"
                fi
                ;;
            *)
                prefix="/usr/local"
                ;;
        esac
    fi
fi

target="$prefix/bin/ripperoni"

if [ -e "$target" ] || [ -L "$target" ]; then
    rm -f "$target"
    echo "removed $target"
else
    echo "nothing to remove at $target"
fi
