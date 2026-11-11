#!/usr/bin/env bash

# 先尝试优雅退出
polybar-msg cmd quit >/dev/null 2>&1
sleep 0.3
pkill -u "$UID" -x polybar

# 等待旧进程退出，超时则强杀
tries=0
while pgrep -u "$UID" -x polybar >/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 10 ]; then
        pkill -9 -u "$UID" -x polybar 2>/dev/null
    fi
    sleep 0.2
done

loggbar=/tmp/polybar-gbar.log
loggstatusbar=/tmp/polybar-statusBar.log
: > "$loggbar"
: > "$loggstatusbar"

polybar gbar      >>"$loggbar"       2>&1 </dev/null &
gbar_pid=$!
polybar statusBar >>"$loggstatusbar" 2>&1 </dev/null &
disown -a

echo "Bars launched..."

for _ in $(seq 1 33); do
    if polybar-msg -p "$gbar_pid" cmd hide >/dev/null 2>&1; then
        break
    fi
    sleep 0.3
done
