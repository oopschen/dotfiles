#!/usr/bin/env bash


hdmi_status=$(xrandr|  grep -Ei "hdmi.+\bconnected\b")
edp_status=$(xrandr|  grep -Ei "edp.+\bconnected\b")

hdmi_name=$(echo "$hdmi_status" | cut -d ' ' -f 1)
edp_name=$(echo "$edp_status" | cut -d ' ' -f 1)

cmd_xrandr="/usr/bin/xrandr"
display_mode=""

mode="$1:none"


if [[ ! -z "$hdmi_status" && ! -z "$edp_status" ]]; then
    case $mode in 
        mirror) 
            $cmd_xrandr --output $hdmi_name --primary --auto \
                --output $edp_name --auto --same-as $hdmi_name
            display_mode="$hdmi_name[*],$edp_name[*]"
            ;;
        *)
            $cmd_xrandr --output $hdmi_name --primary --auto \
                --output $edp_name --auto --left-of $hdmi_name
            display_mode="$hdmi_name[*],$edp_name"
            ;;

    esac

elif [[ -z "$hdmi_status" && ! -z "$edp_status" ]]; then
    for hdmi_loop_name in $($cmd_xrandr | grep -iE "\bhdmi" | cut -d " " -f 1)
    do
        $cmd_xrandr --output $hdmi_loop_name --off
    done
    $cmd_xrandr --output $edp_name --primary --auto 
    display_mode="$edp_name[*]"

elif [[ ! -z "$hdmi_status" &&  -z "$edp_status" ]]; then
    for edp_loop_name in $($cmd_xrandr | grep -iE "\bedp" | cut -d " " -f 1)
    do
        $cmd_xrandr --output $edp_loop_name --off 
    done
    $cmd_xrandr --output $hdmi_name --primary --auto 
    display_mode="$hdmi_name[*]"

else
    exit 1

fi

/usr/bin/notify-send -u low -a udev -t 2000 "Display updated: $display_mode"
