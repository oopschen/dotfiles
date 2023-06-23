#!/usr/bin/env bash

# Terminate already running bar instances
# If all your bars have ipc enabled, you can use 
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

logfile=/tmp/polybar-gbar.log

# Launch bar1 and bar2
echo "---" | tee -a $logfile
polybar gbar 2>&1 | tee -a $logfile & disown

echo "Bars launched..."
