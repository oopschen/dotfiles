#!/usr/bin/env bash
# An i3wm term wrapper for personal usage.
# make st term run once and rezie by i3wm for_window rule, move to scratchpad
#

wm_instance=cmdterm
pattern_cmd_term="st.+\s$wm_instance\s"
mode=$1

## function definition
#
### @args name_pattern progress name pattern
# @ reutnr 1 when proccess exists
function has_prog_started() {
    res=$(pgrep -f "$1")
    if [ -z "$res" ]; then
        echo 0
    else
        echo 1
    fi

}

### The window display already
### @args ins i3wm instance selector
### @ return 1 when window is display
function i3wm_has_window_display() {
    path_res=$(i3-msg -t get_tree | \
        jq -c "path(..|.window_properties?|.instance?|select(.==\"$1\"))|.[:-2]")

    if [ 0 -eq $? ] && [ ! -z "$path_res" ]; then
        output_val=$(i3-msg -t get_tree | jq "getpath($path_res) | .output" | tr -d '"')
        if [[ "$output_val" == "__"* ]]; then
            echo "0"
            return
        fi
    fi
    echo "1"
}

### Get focus status for window 
### @args ins i3wm instance selector
### @ return 1 or 0
function i3wm_is_window_focus() {
    path_res=$(i3-msg -t get_tree | \
        jq -c "path(..|.window_properties?|.instance?|select(.==\"$1\"))|.[:-2]")

    if [ 0 -eq $? ] && [ ! -z "$path_res" ]; then
        prop_val=$(i3-msg -t get_tree | jq "getpath($path_res) | .focused" | tr -d '"')
        if [ "$prop_val" = "true" ]; then
            echo "1"
            return
        fi
    fi
    echo "0"
}

function i3wm_display_window() {
    i3-msg "[instance=\"(?i)$1\"] exec i3-move-position.sh cur-float-cmd-by-instance '(i?)$1' 0 79 ; [instance=\"(?i)$1\"] scratchpad show;resize set 40 ppt 20 ppt; "
}

function i3wm_hide_window() {
    i3-msg "[instance=\"(?i)$1\"] move scratchpad"
}

### The window is floating
### @args ins i3wm instance selector
### @ return 1 when window is floating
function i3wm_is_window_floating() {
    path_res=$(i3-msg -t get_tree | \
        jq -c "path(..|.window_properties?|.instance?|select(.==\"$1\"))|.[:-2]")

    if [ 0 -eq $? ] && [ ! -z "$path_res" ]; then
        floating_val=$(i3-msg -t get_tree | jq "getpath($path_res) | .floating" | tr -d '"')
        if [[ "$floating_val" == *"_on" ]]; then
            echo "1"
            return
        fi
    fi
    echo "0"
}

function i3wm_focus_window() {
    i3-msg "[instance=\"(?i)$1\"] focus"
}

## function definition end

# query program started
# if has started: 
#   if is not floating mode:
#     focus
#   elif it is hidden:
#     show it 
#   else
#     if it is not focus 
#       move to current focus workspace
#     elif is toggle mode
#       toggle display
#     else
#       focus
# else
#   start it 
#   make it seen by user
# 
#

has_prog_exists=$(has_prog_started "$pattern_cmd_term")
if [ "1" = "$has_prog_exists" ]; then
    has_window_display=$(i3wm_has_window_display "$wm_instance")
    is_window_floating=$(i3wm_is_window_floating "$wm_instance")

    if [ "0" = "$is_window_floating" ];then
        echo "window exists, but not floating focus it"
        i3wm_focus_window "$wm_instance"
    elif [ "0" = "$has_window_display" ];then
        echo "command term displays"
        i3wm_display_window "$wm_instance"
    else
        is_cmdterm_focus=$(i3wm_is_window_focus "$wm_instance")

        if [  "0" = "$is_cmdterm_focus" ];then
            echo "command term displays when on focus"
            i3wm_display_window "$wm_instance"
        elif [ "toggle" = "$mode" ]; then
            echo "command term displays(T)"
            i3wm_hide_window "$wm_instance"
        else
            echo "command term already display $has_window_display"
            i3wm_focus_window "$wm_instance"
        fi
    fi
else
    echo "command term launches..."
    i3-utils-base-term.sh "-n $wm_instance -t $wm_instance"

    case $mode in
        launch)
            # as i3wm auto move term to scrath, so it will not show
            ;;
        *)
            ;;
    esac
fi
