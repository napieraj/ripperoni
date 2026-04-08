#!/bin/sh
# where the files land. templates are hardcoded because yaml would own my soul

naming_resolve() {
    # type root name_override detect_file
    type=$1
    root=$2
    name=$3
    detect_file=$4

    # slurp detection (vars pop out of the file like a jack-in-the-box)
    LABEL=""
    # shellcheck disable=SC1090
    . "$detect_file"

    # title: you win, then disc label, then UNKNOWN and we all feel bad
    title=${name:-${LABEL:-UNKNOWN}}
    # / and : can go step on legos
    safe=$(echo "$title" | tr '/:' '__' | tr -s ' ')

    case "$type" in
        bd|bd-uhd)  echo "$root/bluray/$safe" ;;
        dvd)        echo "$root/dvd/$safe" ;;
        cd)         echo "$root/audio/$safe" ;;
        data)       echo "$root/iso/$safe" ;;
        game)       echo "$root/games/$safe" ;;
        mixed)      echo "$root/mixed/$safe" ;;
        *)          echo "$root/unknown/$safe" ;;
    esac
}
