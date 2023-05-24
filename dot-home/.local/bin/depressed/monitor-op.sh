#!/usr/bin/env bash
## Depressed by script ./hdmi-hotplug.sh
## @Date 2022/11/29

if [ 1 -ne  $# ];then
  echo -e "Usage:\t ./$(basename $0) [hdmi-on|hdmi-off|hdmi-mirror]"
  exit 1
fi

function query_monitor_name() {
  echo $(xrandr -q | grep -iE '\bconnected\b' | grep -i $1 | cut -d ' ' -f 1)
}

mainMonitor=$(query_monitor_name edp)
externalMonitor=$(query_monitor_name hdmi)
allExternalMonitor=$(xrandr -q | grep -i hdmi | cut -d ' ' -f 1)

case "$1" in
  hdmi-off)
    for m in $allExternalMonitor
    do
      echo -e "turn off $m"
      xrandr --output $m --off
    done
    ;;
  hdmi-on|hdmi-mirror)
    if [ -z "$externalMonitor" ]; then
      echo -e "no connected hdmi detected"
      exit 1
    fi

    case "$1" in
      hdmi-on)
        xrandr --output $externalMonitor --auto --primary --above $mainMonitor
        ;;
      hdmi-mirror)
        xrandr --output $externalMonitor --auto --primary --same-as $mainMonitor
        ;;
    esac

    ;;
  *)
    echo -e "Usage:\t ./$(basename $0) [hdmi-on|hdmi-off|hdmi-mirror]"
    exit 1
    ;;
esac
