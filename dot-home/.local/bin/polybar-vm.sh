#!/usr/bin/env bash
#
prefix_output="%{T2}%{F#63F3CF} %{F-}%{T-}"
output=""


function check_vm_w11() {
    # check ipsec
    pidfile="/tmp/.vm.win11.pid"
    if [ -f "$pidfile" ] && [ -e "/proc/$(cat $pidfile)" ]; then
        echo -e "%{T1}%{F#F0C674} 11%{F-}%{T-}"
    else
        echo ""
    fi
}

## call functions
output=$(check_vm_w11)

if [ -z "$output" ]; then
    echo -e "\n"
else
    echo -e "$prefix_output $output"
fi
