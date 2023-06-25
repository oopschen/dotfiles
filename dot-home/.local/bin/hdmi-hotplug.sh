#!/usr/bin/env bash
#

# find hdmi name
extern_status=
extern_name=
for ds in hdmi- dp-
do
    extern_status=$(xrandr|  grep -Ei "\b$ds\b.+\bconnected\b")
    if [[ ! -z "$extern_status" ]]; then
        echo "Choose external display: $ds"
        break
    fi

done

if [[ -z "$extern_status" ]]; then
    extern_status=$(xrandr|  grep -Ei "\bhdmi\b.+\bconnected\b")
else
    extern_name=$(echo "$extern_status" | cut -d ' ' -f 1)
fi


intern_status=$(xrandr|  grep -Ei "\bedp\b.+\bconnected\b")
intern_name=$(echo "$intern_status" | cut -d ' ' -f 1)

cmd_xrandr=/usr/bin/xrandr
display_mode=

_m=$1
mode=${_m:=none}


function display_extern() {
    $cmd_xrandr --output $intern_name --off 
    $cmd_xrandr --output $extern_name --primary --auto 

}

function display_local() {
    $cmd_xrandr --output $extern_name --off
    $cmd_xrandr --output $intern_name --primary --auto 
}

## params;
## internal name
## external name
function gen_scale_xrandr_param() {
    intern_dis_name=$1
    extern_dis_name=$2
    
    intern_dis_name_resolutin=$(xrandr|  grep -Ei -A1 "\b$intern_dis_name\b.+\bconnected\b" | tail -n1 | sed -r 's/.+\b([0-9]+x[0-9]+)\b.+/\1/ig')
    extern_dis_name_resolutin=$(xrandr|  grep -Ei -A1 "\b$extern_dis_name\b.+\bconnected\b" | tail -n1 | sed -r 's/.+\b([0-9]+x[0-9]+)\b.+/\1/ig')

    intern_dis_name_x=$(echo "$intern_dis_name_resolutin" | cut -d 'x' -f 1)
    intern_dis_name_y=$(echo "$intern_dis_name_resolutin" | cut -d 'x' -f 2)
    extern_dis_name_x=$(echo "$extern_dis_name_resolutin" | cut -d 'x' -f 1)
    extern_dis_name_y=$(echo "$extern_dis_name_resolutin" | cut -d 'x' -f 2)

    scale_x=$(python -c "print(\"%0.2f\"  % ($intern_dis_name_x / $extern_dis_name_x))")
    scale_y=$(python -c "print(\"%0.2f\"  % ($intern_dis_name_y / $extern_dis_name_y))")
    echo "--scale ${scale_x}x${scale_y}"
}

if [[ ! -z "$extern_status" && ! -z "$intern_status" ]]; then
    case $mode in 
        mirror) 
            echo "Mirror Display"
            $cmd_xrandr --output $extern_name --primary --auto \
                $(gen_scale_xrandr_param $intern_name $extern_name) \
                --output $intern_name --auto --same-as $extern_name
            display_mode="$extern_name[*],$intern_name[*]"
            ;;
        off) 
            echo "Local Display Only: $intern_name"
            display_local
            display_mode="$extern_name,$intern_name[*]"
            ;;
        *)
            echo "Multiple Display : $intern_name, $extern_name"
            $cmd_xrandr --output $extern_name --primary --auto \
                $(gen_scale_xrandr_param $intern_name $extern_name) \
                --output $intern_name --auto --left-of $extern_name
            display_mode="$extern_name[*],$intern_name"
            ;;

    esac

elif [[ -z "$extern_status" && ! -z "$intern_status" ]]; then
    echo "Local Display Only(1 display): $intern_name"
    display_local
    display_mode="$intern_name[*]"

elif [[ ! -z "$extern_status" &&  -z "$intern_status" ]]; then
    echo "Extern Display Only(1 display): $extern_status"
    display_extern
    display_mode="$extern_name[*]"

else
    exit 1

fi

/usr/bin/notify-send -u low -t 1000 "Display Changed" "$display_mode"
