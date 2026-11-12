#!/usr/bin/env bash

LOCK=/tmp/polybar-launch.lock
PENDING=/tmp/polybar-launch.pending
LOG=/tmp/polybar-launch.log

log() { echo "$(date +%T) $*" >> "$LOG"; }

# 互斥：已有实例在跑就留标记退出
log "invoked: pid=$$ parent=[$(ps -o args= -p $PPID)]"
exec 9>"$LOCK"
if ! flock -n 9; then
    touch "$PENDING"
    exit 0
fi

# 以 pgrep 为准，取 bar 当前的 pid（可能为空）
bar_pid() { pgrep -u "$UID" -f "^polybar $1$" | head -n1; }

kill_bar() {
    local name=$1 pid tries=0
    pid=$(bar_pid "$name")
    [ -z "$pid" ] && return 0
    log "kill $name ($pid)"

    while [ -n "$(bar_pid "$name")" ]; do
        tries=$((tries + 1))
        if [ "$tries" -gt 10 ]; then
            pkill -9 -u "$UID" -f "^polybar $name$" 2>/dev/null
        else
            pkill -u "$UID" -f "^polybar $name$" 2>/dev/null
        fi
        sleep 0.2
    done

    rm -f "/tmp/polybar_mqueue.$pid"
}

start_bar() {
    local name=$1 logfile=/tmp/polybar-$1.log
    log "start $name"
    : > "$logfile"
    # 9>&- 关闭锁描述符，避免 polybar 继承并长期占着锁
    polybar "$name" >>"$logfile" 2>&1 </dev/null 9>&- &
    disown
    # 等进程出现（pgrep 为准）
    for _ in $(seq 1 25); do
        [ -n "$(bar_pid "$name")" ] && return 0
        sleep 0.2
    done
    log "start $name failed: process not found"
    return 1
}

restart_bar() {
    local name=$1 pid
    pid=$(bar_pid "$name")
    if [ -z "$pid" ]; then
        start_bar "$name"
        return
    fi

    if timeout 2 polybar-msg -p "$pid" cmd restart >/dev/null 2>&1; then
        sleep 1
        if [ -n "$(bar_pid "$name")" ]; then
            log "restart $name ok"
            return 0
        fi
        log "restart $name: process gone afterwards"
    else
        log "polybar-msg restart $name failed (rc=$?), force kill"
    fi

    kill_bar "$name"
    start_bar "$name"
}

# 给 gbar 发 hide，失败要处理
hide_gbar() {
    local pid
    for _ in $(seq 1 3); do
        pid=$(bar_pid gbar)
        if [ -n "$pid" ] && timeout 2 polybar-msg -p "$pid" cmd hide >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.3
    done
    return 1
}

run() {
    restart_bar gbar
    restart_bar statusBar

    sleep 0.5
    if ! hide_gbar; then
        log "hide gbar failed, kill and start gbar again"
        kill_bar gbar
        start_bar gbar
        hide_gbar || log "hide gbar failed again, giving up"
    fi
}

# 运行期间又有调用（留下标记）就再完整跑一轮
while :; do
    rm -f "$PENDING"
    run
    [ -e "$PENDING" ] || break
done
