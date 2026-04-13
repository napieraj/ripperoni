#!/bin/sh
set -eu

usage() {
    cat <<'EOF'
usage: scripts/install.sh [--user] [--prefix <path>] [--wrapper]

install ripperoni into <prefix>/bin as `ripperoni`.

options:
  --user            install to ~/.local/bin
  --prefix <path>   install prefix override
  --wrapper         write a tiny wrapper script instead of symlink
  -h, --help        show this help

env:
  PREFIX            same as --prefix
EOF
}

SCRIPT_SELF=$(readlink "$0" 2>/dev/null || echo "$0")
case "$SCRIPT_SELF" in
    /*) ;;
    *) SCRIPT_SELF="$(pwd)/$SCRIPT_SELF" ;;
esac
REPO_ROOT=$(cd "$(dirname "$SCRIPT_SELF")/.." && pwd)
SOURCE_BIN="$REPO_ROOT/bin/ripperoni"

[ -x "$SOURCE_BIN" ] || {
    echo "error: source binary missing or not executable: $SOURCE_BIN" >&2
    exit 1
}

use_user=0
prefer_wrapper=0
prefix="${PREFIX:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --user)
            use_user=1
            shift
            ;;
        --wrapper)
            prefer_wrapper=1
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

bindir="$prefix/bin"
target="$bindir/ripperoni"

mkdir -p "$bindir" 2>/dev/null || {
    echo "error: cannot create $bindir (try sudo, --user, or --prefix)" >&2
    exit 1
}

if [ -e "$target" ] || [ -L "$target" ]; then
    rm -f "$target"
fi

if [ "$prefer_wrapper" = "1" ]; then
    cat >"$target" <<EOF
#!/bin/sh
exec "$SOURCE_BIN" "\$@"
EOF
    chmod +x "$target"
    mode=wrapper
else
    if ln -s "$SOURCE_BIN" "$target" 2>/dev/null; then
        mode=symlink
    else
        cat >"$target" <<EOF
#!/bin/sh
exec "$SOURCE_BIN" "\$@"
EOF
        chmod +x "$target"
        mode=wrapper
    fi
fi

echo "installed ripperoni -> $target ($mode)"

case ":${PATH:-}:" in
    *":$bindir:"*)
        ;;
    *)
        echo
        echo "note: $bindir is not on PATH"
        echo "add this to your shell profile:"
        echo "  export PATH=\"$bindir:\$PATH\""
        ;;
esac
