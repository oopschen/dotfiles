#!/bin/sh

#getDefaultSink() {
#    defaultSink=$(wpctl status | awk '/^Audio/ {flag=1; next} /Sinks:/ && (flag == 1) {flag=2; next}  /Sources:/ && (flag==2){flag = 0 } flag==2 {print $0}')
#}

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

MUTE_STATE=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -i muted)
VOLUME=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | sed -r 's/.*([0-9]\.[0-9]+).*/\1/ig' | tr -d ' ')
#SINK=$(getDefaultSink)
VOLUME_PERCENTAGE="$(echo "($VOLUME * 100)/1" | bc)%" 

if [ -z "$MUTE_STATE" ]; then
    echo -e "%{T2}\UF028%{T-} %{T1}${VOLUME_PERCENTAGE}%{T-}"
else
    echo -e "%{F#A54242}%{T2}\UF026%{T-} %{T1}${VOLUME_PERCENTAGE}%{T-}%{F-}"
fi
