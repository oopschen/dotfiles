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


MUTE_STATE=
VOLUME=

## wait for pipewired starting
is_pipewiere_started=
loop=0
while [ ! -z "$(is_pipewiere_started=;wpctl status 2>&1| grep -i 'not connect to pipewire' )" ] && [ 3 -gt $loop ]; do
    sleep 1
    loop=$(echo "1 + $loop" | bc)
    is_pipewiere_started=1
done

MUTE_STATE=muted
VOLUME=0
if [ -z "$is_pipewiere_started" ]; then
    MUTE_STATE=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -i muted)
    VOLUME=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | sed -r 's/.*([0-9]\.[0-9]+).*/\1/ig' | tr -d ' ')
fi

#SINK=$(getDefaultSink)
VOLUME_PERCENTAGE="$(echo "($VOLUME * 100)/1" | bc)%" 

if [ -z "$MUTE_STATE" ]; then
    echo -e "%{T2}\UF028%{T-} %{T1}${VOLUME_PERCENTAGE}%{T-}"
else
    echo -e "%{F#A54242}%{T2}\UF026%{T-} %{T1}${VOLUME_PERCENTAGE}%{T-}%{F-}"
fi
