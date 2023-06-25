#!/usr/bin/env bash
#

# find hdmi name
extern_status=
for ds in hdmi- dp-
do
    extern_status=$(xrandr|  grep -Ei "\b$ds\b.+\bconnected\b")
    if [[ ! -z "$extern_status" ]]; then
        echo "Choose external display: $ds"
        break
    fi

done

if [[ -z "$extern_status" ]]; then
    echo "No external display found!!!"
    exit 1
fi


inter_status=$(xrandr|  grep -Ei "\bedp\b.+\bconnected\b")

extern_name=$(echo "$extern_status" | cut -d ' ' -f 1)
inter_name=$(echo "$inter_status" | cut -d ' ' -f 1)

cmd_xrandr="/usr/bin/xrandr"
display_mode=""

_m=$1
mode="${_m:=none}"

function display_extern() {
    for inter_loop_name in $($cmd_xrandr | grep -iE "\bedp" | cut -d " " -f 1)
    do
        $cmd_xrandr --output $inter_loop_name --off 
    done
    $cmd_xrandr --output $extern_name --primary --auto 

}

function display_local() {
    for extern_loop_name in $($cmd_xrandr | grep -iE "\bhdmi" | cut -d " " -f 1)
    do
        $cmd_xrandr --output $extern_loop_name --off
    done
    $cmd_xrandr --output $inter_name --primary --auto 
}

if [[ ! -z "$extern_status" && ! -z "$inter_status" ]]; then
    case $mode in 
        mirror) 
            $cmd_xrandr --output $extern_name --primary --auto \
                --output $inter_name --auto --same-as $extern_name
            display_mode="$extern_name[*],$inter_name[*]"
            ;;
        off) 
            display_local
            display_mode="$extern_name,$inter_name[*]"
            ;;
        *)
            $cmd_xrandr --output $extern_name --primary --auto \
                --output $inter_name --auto --left-of $extern_name
            display_mode="$extern_name[*],$inter_name"
            ;;

    esac

elif [[ -z "$extern_status" && ! -z "$inter_status" ]]; then
    display_local
    display_mode="$inter_name[*]"

elif [[ ! -z "$extern_status" &&  -z "$inter_status" ]]; then
    display_extern
    display_mode="$extern_name[*]"

else
    exit 1

fi

/usr/bin/notify-send -u low -a udev -t 2000 "Display updated: $display_mode"
