#!/bin/sh
# config: it's just shell assignments. we're not parsing yaml at 2am again.

config_load() {
    # defaults first, then file, then env, then flags stomps everything. natural order
    output_root="${RIPPERONI_OUTPUT_ROOT:-$HOME/media/rips}"
    default_drive=""
    makemkv_min_length_bd=120
    makemkv_min_length_dvd=300
    cd_offset=6
    cd_format=flac
    verify=1
    sleep_inhibit=1
    # someday logging might care. until then it exists so shellcheck stops acting like a hall monitor
    log_level=info
    wait_for_ready=1
    wait_timeout=30
    eject_on_success=0
    eject_on_failure=0

    config_file=${RIPPERONI_CONFIG:-$HOME/.config/ripperoni/config}
    if [ -r "$config_file" ]; then
        # your homework
        # shellcheck disable=SC1090
        . "$config_file"
        log_debug "loaded config from $config_file"
    else
        log_debug "no config file at $config_file (using defaults)"
    fi
}

config_print() {
    # dumping log_level here keeps humans and shellcheck equally informed. try not to cry
    cat <<EOF
# resolved config
output_root=$output_root
default_drive=$default_drive
makemkv_min_length_bd=$makemkv_min_length_bd
makemkv_min_length_dvd=$makemkv_min_length_dvd
cd_offset=$cd_offset
cd_format=$cd_format
verify=$verify
sleep_inhibit=$sleep_inhibit
log_level=$log_level
wait_for_ready=$wait_for_ready
wait_timeout=$wait_timeout
eject_on_success=$eject_on_success
eject_on_failure=$eject_on_failure
EOF
}
