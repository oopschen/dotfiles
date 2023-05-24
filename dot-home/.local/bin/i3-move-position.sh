#!/usr/bin/env bash
#
## float-cmd: move float command line container to abs pos
## im: move im container to abs pos
## cur-float-cmd: move float command line container to current focused workspace

mode=$1
criteria=$2
left_offset_percentage=$3
top_offset_percentage=$4
msg=""

pos_info=$(xrandr | grep primary | cut -d ' ' -f 4)
pos_x=$(echo "$pos_info" | cut -d '+' -f 2)
pos_y=$(echo "$pos_info" | cut -d '+' -f 3)

display_info=$(echo "$pos_info" | cut -d '+' -f 1)
display_width=$(echo "$display_info" | cut -d 'x' -f 1)
display_height=$(echo "$display_info" | cut -d 'x' -f 2)

## query focused workspace pos
#
focused_pos_x=$(i3-msg -t get_workspaces | jq -c ".[] | select(.focused)" | jq ".rect.x")
focused_pos_y=$(i3-msg -t get_workspaces | jq -c ".[] | select(.focused)" | jq ".rect.y")
focused_pos_width=$(i3-msg -t get_workspaces | jq -c ".[] | select(.focused)" | jq ".rect.width")
focused_pos_height=$(i3-msg -t get_workspaces | jq -c ".[] | select(.focused)" | jq ".rect.height")

case $mode in 
    float-cmd)
        dst_pos_x=$(python -c "import math;print(math.ceil($pos_x + $left_offset_percentage / 100.0 * $display_width))")
        dst_pos_y=$(python -c "print($pos_y + 5)")
        msg="[class=\"$criteria\"] move position $dst_pos_x $dst_pos_y"
        ;;

    im)
        dst_pos_x=$(python -c "import math;print(math.ceil($pos_x + $left_offset_percentage / 100.0 * $display_width))")
        dst_pos_y=$pos_y
        msg="[class=\"$criteria\"] move position $dst_pos_x $dst_pos_y"
        ;;

    cur-float-cmd)
        dst_pos_x=$(python -c "import math;print(math.ceil($focused_pos_x+ $left_offset_percentage / 100.0 * $focused_pos_width))")
        dst_pos_y=$(python -c "print($focused_pos_y + 5)")
        msg="[class=\"$criteria\"] move position $dst_pos_x $dst_pos_y"
        ;;

    cur-float-cmd-by-instance)
        dst_pos_x=$(python -c "import math;print(math.ceil($focused_pos_x + $left_offset_percentage / 100.0 * $focused_pos_width))")
        dst_pos_y=$(python -c "import math;print($focused_pos_y + math.ceil($focused_pos_height * $top_offset_percentage / 100))")
        msg="[instance=\"$criteria\"] move position $dst_pos_x $dst_pos_y"
        ;;

    *)
        echo -e "support mode: float-cmd|im\n\tUsage: ./script mode window_criteria left_offset_percentage"
        exit 1
esac

i3-msg "$msg"
