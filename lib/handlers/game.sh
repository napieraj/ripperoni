#!/bin/sh
# game discs: NOT IMPLEMENTED. we print redumper and exit 0 like that's helpful
# preservation dumps are a whole lawsuit of edge cases. you're on your own hero

handler_run() {
    drive=$1
    detect_file=$2
    output_dir=$3
    # not implemented, but we still swallow the argument so the dispatcher stays smug and uniform
    : "$detect_file"

    cat <<EOF | tee "$output_dir/ripperoni.log"
Game disc handling is not implemented in the base layer.

For preservation-grade dumps, run redumper manually:

    redumper dump --drive=$drive --image-path=$output_dir --image-name=disc

See https://github.com/superg/redumper for installation.
EOF
    return 0
}
