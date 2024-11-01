#!/bin/sh

#getDefaultSink() {
#    defaultSink=$(wpctl status | awk '/^Audio/ {flag=1; next} /Sinks:/ && (flag == 1) {flag=2; next}  /Sources:/ && (flag==2){flag = 0 } flag==2 {print $0}')
#}

function get_vol() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@
}

case $1 in
    "--up")
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+
        ;;
    "--down")
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-
        ;;
    "--toggle")
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
esac


MUTE_STATE=muted
VOLUME=0
#SINK=$(getDefaultSink)
VOLUME_PERCENTAGE=0% 

## wait for pipewired starting
loop=0
while [ 3 -gt $loop ]; do
    is_pipewiere_started=
    # check pipewire daemon startup
    if [ -z "$(wpctl status 2>&1| grep -i 'not connect to pipewire' )" ]; then
        # check get vol
        RAW_VOL_CONTENT=$(get_vol | grep -iE "^volume:.+")
        if [ ! -z "$RAW_VOL_CONTENT" ]; then
            MUTE_STATE=$(echo "$RAW_VOL_CONTENT" | grep -i muted)
            VOLUME=$(echo "$RAW_VOL_CONTENT" | sed -r 's/.*([0-9]\.[0-9]+).*/\1/ig' | tr -d ' ')
            VOLUME_PERCENTAGE="$(echo "($VOLUME * 100)/1" | bc)%" 
            break
        fi

    fi

    sleep 1
    loop=$(echo "1 + $loop" | bc)
done


if [ -z "$MUTE_STATE" ]; then
    echo -e "%{T2}\UF028%{T-} %{T1}${VOLUME_PERCENTAGE}%{T-}"
else
    echo -e "%{F#A54242}%{T2}\UF026%{T-} %{T1}${VOLUME_PERCENTAGE}%{T-}%{F-}"
fi
