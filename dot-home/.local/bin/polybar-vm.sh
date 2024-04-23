#!/usr/bin/env bash
#
output=""


function check_vm_w11() {
    # check ipsec
    pidfile="/tmp/.vm.win11.pid"
    if [ -f "$pidfile" ] && [ -e "/proc/$(cat $pidfile)" ]; then
        echo -e "%{T2}%{F#00A1F1} %{F-}%{T-}"
    else
        echo ""
    fi
}

## call functions
output=$(check_vm_w11)

if [ -z "$output" ]; then
    echo -e "\n"
else
    echo -e "$output"
fi
