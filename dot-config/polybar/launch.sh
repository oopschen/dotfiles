#!/usr/bin/env bash

# Terminate already running bar instances
# If all your bars have ipc enabled, you can use
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Launch bar1 and bar2
loggbar=/tmp/polybar-gbar.log
loggstatusbar=/tmp/polybar-statusBar.log

# clean log files
truncate -s 0 $loggbar  2>>/dev/null
truncate -s 0 $loggstatusbar 2>>/dev/null

echo "---" | tee -a  $loggbar $loggstatusbar
polybar gbar 2>&1 | tee -a $loggbar & disown
polybar statusBar 2>&1 | tee -a $loggstatusbar & disown

echo "Bars launched..."

while :; do
    gbar_pid=$(grep -i pid $loggbar | tail -n1  | sed -r 's/.*pid\s*:\s+([0-9]+).+/\1/ig')
    echo -en "gbar log $gbar_pid" > /tmp/c.log
    if [ -z "$gbar_pid" ]; then
        sleep 0.3
        continue
    fi

    polybar-msg -p $gbar_pid cmd hide
    break
done
