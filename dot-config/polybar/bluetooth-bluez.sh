#!/usr/bin/env bash
# ======================================================================
#  polybar bluetooth module  (bash + BlueZ / bluetoothctl)
# ----------------------------------------------------------------------
#  用法:
#    bluetooth.sh [选项] [watch]   常驻输出，事件驱动实时刷新 (配合 tail = true)
#    bluetooth.sh status           只输出一次当前状态 (调试用)
#    bluetooth.sh toggle           已连接 -> 断开；未连接 -> 重连上次设备
#    bluetooth.sh power            开/关蓝牙适配器
#
#  选项:
#    --style  full|compact|name|icon   内置样式 (默认 full)
#    --format '{icon} {name} {bars}'   自定义模板，优先级高于 --style
#                                      占位符: {icon} {name} {bars} {dbm} {text} {count}
#    --max-len N                       设备名最大长度 (默认 16)
#    --interval N                      信号强度刷新间隔，秒 (默认 5)
#
#  所有变量也可写进配置文件 ~/.config/polybar/bluetooth.conf (bash 语法):
#    STYLE=compact
#    COLOR_CONN="#a6e3a1"
#    GLYPHS="● ● ● ●"
#    ICON_CONN=""
#
#  依赖: bluez (bluetoothctl)；信号强度可选: btmgmt / hcitool (bluez 自带)；notify-send
# ======================================================================

shopt -u patsub_replacement 2>/dev/null   # 防止设备名中的 & 被当作特殊字符
# 保证按“字符”而不是“字节”截断设备名 (polybar 有时在 C locale 下启动)
[[ ${LC_ALL:-${LANG:-}} == *[Uu][Tt][Ff]* ]] || export LC_ALL=C.UTF-8

CONFIG=${BT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/polybar/bluetooth.conf}
# shellcheck disable=SC1090
[[ -r $CONFIG ]] && source "$CONFIG"

# ---------------------------- 可替换样式 ------------------------------
# 图标 (Nerd Font Material Design Icons)，也可以在配置文件里换成别的字符
_i_off=$'\xf3\xb0\x82\xb2'    # 󰂲 bluetooth-off
_i_on=$'\xf3\xb0\x82\xaf'     # 󰂯 bluetooth
_i_conn=$'\xf3\xb0\x82\xb1'   # 󰂱 bluetooth-connect
: "${ICON_OFF:=$_i_off}"
: "${ICON_ON:=$_i_on}"
: "${ICON_CONN:=$_i_conn}"

# 颜色 (polybar %{F#rrggbb})，默认 Catppuccin 风格
: "${COLOR_OFF:=#6c7086}"     # 蓝牙关闭
: "${COLOR_ON:=#89b4fa}"      # 蓝牙开启但无连接
: "${COLOR_CONN:=#a6e3a1}"    # 已连接 / 信号格亮
: "${COLOR_DIM:=#45475a}"     # 信号格暗 / 次要文字

# 文字与信号格 (GLYPHS 用空格分成 4 项，从弱到强，例如 "● ● ● ●" 或 "▁ ▃ ▅ ▇")
: "${TEXT_OFF:=Off}"
: "${TEXT_ON:=On}"
: "${GLYPHS:=▂ ▄ ▆ █}"

: "${STYLE:=full}"
: "${FORMAT:=}"
: "${MAX_LEN:=16}"
: "${INTERVAL:=5}"
: "${SHOW_DBM:=1}"

# 信号强度来源 (均为 bluez 自带命令)，按顺序尝试，成功后缓存:
#   info     bluetoothctl info 里的 RSSI 属性 (始终最先尝试，无需权限)
#   btmgmt   btmgmt conn-info，绝对 dBm，通常需要 CAP_NET_ADMIN
#   hcitool  hcitool rssi，相对值 (0 最佳)，部分系统需要权限
: "${SIGNAL_SOURCES:=btmgmt hcitool}"
# 需要提权时填 "sudo -n"（配合 sudoers 免密），或改用 setcap，见说明
: "${SUDO_CMD:=}"

# ----------------------------- 命令行参数 -----------------------------
CMD=watch
while (($#)); do
    case $1 in
        --style)    STYLE=$2;    shift 2 ;;
        --format)   FORMAT=$2;   shift 2 ;;
        --max-len)  MAX_LEN=$2;  shift 2 ;;
        --interval) INTERVAL=$2; shift 2 ;;
        watch|status|toggle|power) CMD=$1; shift ;;
        *) shift ;;
    esac
done

if [[ -z $FORMAT ]]; then
    case $STYLE in
        full)    FORMAT='{icon} {name} {bars} {dbm}' ;;
        compact) FORMAT='{icon} {name} {bars}' ;;
        name)    FORMAT='{icon} {name}' ;;
        icon)    FORMAT='{icon}' ;;
        *)       FORMAT='{icon} {name} {bars} {dbm}' ;;
    esac
fi
# 未连接 / 关闭时的模板：icon 样式只显示图标，其余显示 图标+状态文字
if [[ $STYLE == icon || $FORMAT == '{icon}' ]]; then
    IDLE_FORMAT='{icon}'
else
    IDLE_FORMAT='{icon} {text}'
fi

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/polybar-bluetooth.last"

# ------------------------------ 工具函数 ------------------------------
notify() {
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a polybar-bluetooth -t 2500 "$1" "${2:-}"
}

fg() { REPLY="%{F$1}$2%{F-}"; }          # 着色 -> REPLY (避免子进程)

fill() {                                  # 模板 $1 + P_* 变量 -> REPLY
    local s=$1
    s=${s//'{icon}'/$P_icon}
    s=${s//'{name}'/$P_name}
    s=${s//'{bars}'/$P_bars}
    s=${s//'{dbm}'/$P_dbm}
    s=${s//'{text}'/$P_text}
    s=${s//'{count}'/$P_count}
    while [[ $s == *"  "* ]]; do s=${s//  / }; done
    s=${s# }; s=${s% }
    REPLY=$s
}

bars() {                                  # $1 = 0..4 -> REPLY
    local i s="" g
    read -ra g <<<"$GLYPHS"
    for ((i = 0; i < 4; i++)); do
        if ((i < $1)); then s+="%{F$COLOR_CONN}${g[i]}"
        else                s+="%{F$COLOR_DIM}${g[i]}"; fi
    done
    REPLY="$s%{F-}"
}

rssi_level() {                            # $1=值 $2=1绝对dBm/0相对值 -> REPLY
    local v=$1
    if (($2)); then
        ((v >= -60)) && REPLY=4 || { ((v >= -70)) && REPLY=3 || { ((v >= -80)) && REPLY=2 || REPLY=1; }; }
    else   # hcitool: 0 为最佳，越负越差
        ((v >= -2)) && REPLY=4 || { ((v >= -6)) && REPLY=3 || { ((v >= -12)) && REPLY=2 || REPLY=1; }; }
    fi
}

# --------------------------- BlueZ 状态查询 ---------------------------
# 设置: POWERED CONN_N DEV_MAC DEV_NAME DEV_RSSI RSSI_ABS
query_state() {
    POWERED=; CONN_N=0; DEV_MAC=; DEV_NAME=; DEV_RSSI=; RSSI_ABS=1
    local l mac info

    while IFS= read -r l; do
        [[ $l == *Powered:* ]] && POWERED=${l##*: }
    done < <(bluetoothctl show 2>/dev/null)
    [[ $POWERED == yes ]] || return 0

    while read -r _ mac _; do
        [[ $mac =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] || continue
        info=$(bluetoothctl info "$mac" 2>/dev/null)
        [[ $info == *"Connected: yes"* ]] || continue
        if ((++CONN_N == 1)); then
            DEV_MAC=$mac
            while IFS= read -r l; do
                case $l in
                    *Alias:*) DEV_NAME=${l#*Alias: } ;;
                    *RSSI:*)  [[ $l =~ \((-?[0-9]+)\) ]] && DEV_RSSI=${BASH_REMATCH[1]} ;;
                esac
            done <<<"$info"
        fi
    done < <(bluetoothctl devices Connected 2>/dev/null)

    if ((CONN_N)) && [[ -z $DEV_RSSI ]]; then
        signal_fallback
    fi
}

# bluetoothctl 拿不到 RSSI 时，依次尝试 bluez 的 btmgmt / hcitool
SIG_CACHE=; SIG_RETRY_AT=0; SIG_MAC=
signal_fallback() {
    local src out t
    [[ $DEV_MAC != "$SIG_MAC" ]] && { SIG_MAC=$DEV_MAC; SIG_RETRY_AT=0; SIG_CACHE=; }
    ((SECONDS < SIG_RETRY_AT)) && return 0   # 都失败过 -> 60 秒内不再重试，省资源

    for src in $SIG_CACHE $SIGNAL_SOURCES; do
        case $src in
            btmgmt)
                command -v btmgmt >/dev/null 2>&1 || continue
                for t in bredr le_public le_random; do
                    out=$(timeout 2 $SUDO_CMD btmgmt conn-info -t "$t" "$DEV_MAC" 2>/dev/null)
                    # 127 表示“不可用”
                    if [[ $out =~ [Rr][Ss][Ss][Ii][^-0-9]*(-?[0-9]+) && ${BASH_REMATCH[1]} != 127 ]]; then
                        DEV_RSSI=${BASH_REMATCH[1]}; RSSI_ABS=1; SIG_CACHE=btmgmt; return 0
                    fi
                done ;;
            hcitool)
                command -v hcitool >/dev/null 2>&1 || continue
                out=$(timeout 2 $SUDO_CMD hcitool rssi "$DEV_MAC" 2>/dev/null)
                if [[ $out =~ (-?[0-9]+)[[:space:]]*$ ]]; then
                    DEV_RSSI=${BASH_REMATCH[1]}; RSSI_ABS=0; SIG_CACHE=hcitool; return 0
                fi ;;
        esac
    done
    SIG_CACHE=; SIG_RETRY_AT=$((SECONDS + 60))
}

# ------------------------------ 渲染输出 ------------------------------
LAST_OUT=; LAST_SAVED=

render() {
    query_state
    local out
    P_icon=; P_name=; P_bars=; P_dbm=; P_text=; P_count=

    if [[ $POWERED != yes ]]; then
        fg "$COLOR_OFF" "$ICON_OFF"; P_icon=$REPLY
        fg "$COLOR_OFF" "$TEXT_OFF"; P_text=$REPLY
        fill "$IDLE_FORMAT"; out=$REPLY
    elif ((CONN_N == 0)); then
        fg "$COLOR_ON" "$ICON_ON";   P_icon=$REPLY
        fg "$COLOR_DIM" "$TEXT_ON";  P_text=$REPLY
        fill "$IDLE_FORMAT"; out=$REPLY
    else
        local name=${DEV_NAME//%/}
        ((${#name} > MAX_LEN)) && name="${name:0:MAX_LEN-1}…"
        fg "$COLOR_CONN" "$ICON_CONN"; P_icon=$REPLY
        P_name=$name
        ((CONN_N > 1)) && P_count="+$((CONN_N - 1))"
        if [[ -n $DEV_RSSI ]]; then
            rssi_level "$DEV_RSSI" "$RSSI_ABS"; bars "$REPLY"; P_bars=$REPLY
            if ((SHOW_DBM && RSSI_ABS)); then
                fg "$COLOR_DIM" "${DEV_RSSI}dBm"; P_dbm=$REPLY
            fi
        fi
        fill "$FORMAT"; out=$REPLY
        [[ $FORMAT == *'{count}'* ]] || { [[ -n $P_count ]] && out+=" %{F$COLOR_DIM}$P_count%{F-}"; }

        # 记住最近连接的设备，供“点击重连”使用
        if [[ $DEV_MAC != "$LAST_SAVED" ]]; then
            printf '%s\n' "$DEV_MAC" >"$STATE_FILE" 2>/dev/null && LAST_SAVED=$DEV_MAC
        fi
    fi

    if [[ $out != "$LAST_OUT" ]]; then   # 无变化不重复输出，减少 polybar 重绘
        printf '%s\n' "$out"
        LAST_OUT=$out
    fi
}

# ----------------------------- 实时监听 -------------------------------
cleanup() { [[ -n ${MON_PID:-} ]] && kill "$MON_PID" 2>/dev/null; }

relevant() {
    case $1 in
        *Connected:*|*Powered:*|*Alias:*|*Controller*|*"[DEL]"*) return 0 ;;
    esac
    return 1
}

watch() {
    trap cleanup EXIT
    trap 'exit 0' INT TERM HUP
    local line rc i POLL=0

    render
    # bluetoothctl --monitor 在 bluez 事件到来时才输出，平时零开销
    coproc MON { exec bluetoothctl --monitor 2>&1; }

    while :; do
        if ((POLL)); then sleep "$INTERVAL"; render; continue; fi

        read -r -t "$INTERVAL" -u "${MON[0]}" line 2>/dev/null; rc=$?
        if ((rc == 0)); then
            relevant "$line" || continue
            # 防抖：吞掉紧随其后的一串事件，只渲染一次
            for ((i = 0; i < 300; i++)); do
                read -r -t 0.25 -u "${MON[0]}" line 2>/dev/null || break
            done
            render
        elif ((rc > 128)); then            # 超时：仅在已连接时刷新信号强度
            ((CONN_N)) && render
        else                               # 监听进程退出 -> 降级为轮询
            POLL=1
        fi
    done
}

# ------------------------------ 点击动作 ------------------------------
cmd_toggle() {
    query_state
    if [[ $POWERED != yes ]]; then
        bluetoothctl power on >/dev/null 2>&1
        sleep 0.5
        CONN_N=0
    fi

    if ((CONN_N > 0)); then
        printf '%s\n' "$DEV_MAC" >"$STATE_FILE" 2>/dev/null
        if bluetoothctl disconnect "$DEV_MAC" 2>&1 | grep -qi 'successful'; then
            notify "Bluetooth" "已断开 ${DEV_NAME:-$DEV_MAC}"
        else
            notify "Bluetooth" "断开失败"
        fi
        return
    fi

    local mac
    mac=$(head -n1 "$STATE_FILE" 2>/dev/null)
    if [[ -z $mac ]]; then                 # 没有记录 -> 取第一个已配对设备
        read -r _ mac _ < <(bluetoothctl devices Paired 2>/dev/null)
    fi
    if [[ -z $mac ]]; then
        notify "Bluetooth" "没有可连接的已配对设备"
        return
    fi
    notify "Bluetooth" "正在连接 $mac …"
    if timeout 20 bluetoothctl connect "$mac" 2>&1 | grep -qi 'successful'; then
        notify "Bluetooth" "连接成功"
    else
        notify "Bluetooth" "连接失败"
    fi
}

cmd_power() {
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        bluetoothctl power off >/dev/null 2>&1
    else
        bluetoothctl power on >/dev/null 2>&1
    fi
}

# -------------------------------- 入口 --------------------------------
if ! command -v bluetoothctl >/dev/null 2>&1; then
    echo "bluetoothctl not found"
    exit 1
fi

case $CMD in
    watch)  watch ;;
    status) render ;;
    toggle) cmd_toggle ;;
    power)  cmd_power ;;
esac
