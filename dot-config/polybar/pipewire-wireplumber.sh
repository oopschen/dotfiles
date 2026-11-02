#!/usr/bin/env bash
#
# pipewire.sh — Polybar 的 PipeWire / WirePlumber 音量 + 麦克风模块
#
# 依赖  : bash >= 4.4, wpctl (WirePlumber)
#         pactl (可选, 来自 libpulse / pipewire-pulse, 用于事件驱动的实时刷新)
# 字体  : Nerd Font (PW_ICON_SET=nerd 时)
#
# 用法  : pipewire.sh <命令> [sink|source] [参数]
#   listen [kind]      持续输出, 事件驱动 (配合 polybar 的 tail = true)
#   show   [kind]      只输出一次
#   up     [kind]      音量 +PW_STEP%
#   down   [kind]      音量 -PW_STEP%
#   toggle [kind]      静音 / 取消静音
#   set    kind N      直接设置音量为 N%
#   kind: sink = 默认输出设备 (默认), source = 默认麦克风
#
# 样式  : 通过环境变量或配置文件 (见下) 调整, 优先级: 环境变量 > 配置文件 > 默认值
#   PW_ICON_SET     nerd | emoji | ascii                 图标集 (默认 nerd)
#   PW_LAYOUT       full | icon | bar | barpct | text    布局预设 (默认 full)
#   PW_FORMAT       自定义格式, 如 '{icon} {bar} {pct}'  (设置后覆盖 PW_LAYOUT)
#   PW_BAR_WIDTH / PW_BAR_FILL / PW_BAR_EMPTY            进度条宽度与字符
#   PW_COLOR_ICON / PW_COLOR_TEXT / PW_COLOR_MUTED / PW_COLOR_WARN
#                   颜色, 如 '#89b4fa'; 留空则继承 polybar 的前景色
#   PW_LABEL_MUTED  静音时代替百分比显示的文字 (默认留空 = 仍显示百分比)
#   PW_ICON_FONT    图标使用的 polybar 字体序号 (font-N 的 N, 从 1 开始), 用于单独调整图标大小
#   PW_ICON_MUTE / PW_ICON_LOW / PW_ICON_MID / PW_ICON_HIGH / PW_ICON_MIC / PW_ICON_MIC_OFF
#                   单独替换某个图标
#   PW_STEP         滚轮步长 % (默认 5)
#   PW_MAX_VOL      音量上限 % (默认 100, 设 150 允许超音量)
#   PW_AUTO_UNMUTE  静音时向上滚动自动取消静音 (默认 1)
#   PW_CONF         配置文件路径 (默认 ~/.config/polybar/pipewire.conf)

set -u

CONF_VARS=(
    PW_STEP PW_MAX_VOL PW_AUTO_UNMUTE PW_ICON_SET PW_LAYOUT PW_FORMAT
    PW_BAR_WIDTH PW_BAR_FILL PW_BAR_EMPTY
    PW_COLOR_ICON PW_COLOR_TEXT PW_COLOR_MUTED PW_COLOR_WARN PW_LABEL_MUTED PW_ICON_FONT
    PW_ICON_MUTE PW_ICON_LOW PW_ICON_MID PW_ICON_HIGH PW_ICON_MIC PW_ICON_MIC_OFF
)

TARGET=@DEFAULT_AUDIO_SINK@ KIND=sink
VOL=0 MUTED=0 NODEV=0
LAST='' FD='' SUB_PID=''

# ───────────────────────── 配置 ─────────────────────────

load_config() {
    local -A from_env=()
    local v conf=${PW_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/polybar/pipewire.conf}

    for v in "${CONF_VARS[@]}"; do
        [[ -v $v ]] && from_env[$v]=${!v}
    done
    # shellcheck disable=SC1090
    [[ -r $conf ]] && source "$conf"
    for v in "${!from_env[@]}"; do          # 环境变量优先于配置文件
        printf -v "$v" '%s' "${from_env[$v]}"
    done

    : "${PW_STEP:=5}"
    : "${PW_MAX_VOL:=150}"
    : "${PW_AUTO_UNMUTE:=1}"
    : "${PW_ICON_SET:=nerd}"
    : "${PW_LAYOUT:=full}"
    : "${PW_FORMAT:=}"
    : "${PW_BAR_WIDTH:=8}"
    : "${PW_BAR_FILL:=━}"
    : "${PW_BAR_EMPTY:=─}"
    : "${PW_COLOR_ICON:=#F0C674}"
    : "${PW_COLOR_TEXT:=}"
    : "${PW_COLOR_MUTED:=#FF2171}"
    : "${PW_COLOR_WARN:=#FF5F15}"
    : "${PW_LABEL_MUTED:=}"
    : "${PW_ICON_FONT:=2}"

    # 图标集 (顺序: 静音 低 中 高 麦克风 麦克风关闭)
    local -a d
    case $PW_ICON_SET in
        emoji) d=(🔇 🔈 🔉 🔊 🎤 🚫) ;;
        ascii) d=(MUTE VOL VOL VOL MIC MIC-OFF) ;;
        *)     d=("󰝟" "󰕿" "󰖀" "󰕾" "󰍬" "󰍭") ;;
    esac
    : "${PW_ICON_MUTE:=${d[0]}}"
    : "${PW_ICON_LOW:=${d[1]}}"
    : "${PW_ICON_MID:=${d[2]}}"
    : "${PW_ICON_HIGH:=${d[3]}}"
    : "${PW_ICON_MIC:=${d[4]}}"
    : "${PW_ICON_MIC_OFF:=${d[5]}}"

    if [[ -z $PW_FORMAT ]]; then
        case $PW_LAYOUT in
            icon)   PW_FORMAT='{icon}' ;;
            bar)    PW_FORMAT='{icon} {bar}' ;;
            barpct) PW_FORMAT='{icon} {bar} {pct}' ;;
            text)   PW_FORMAT='{pct}' ;;
            *)      PW_FORMAT='{icon} {pct}' ;;
        esac
    fi
}

# ───────────────────────── 状态读取 ─────────────────────────

# 读取 wpctl 输出: "Volume: 0.50" 或 "Volume: 0.50 [MUTED]"
get_state() {
    local out v int frac
    NODEV=0 MUTED=0 VOL=0

    if ! out=$(wpctl get-volume "$TARGET" 2>/dev/null) || [[ $out != Volume:* ]]; then
        NODEV=1 MUTED=1
        return
    fi
    [[ $out == *'[MUTED]'* ]] && MUTED=1

    v=${out#Volume: }; v=${v%% *}
    [[ $v == *.* ]] || v+=.0
    int=${v%%.*}
    frac=${v#*.}00; frac=${frac:0:2}
    VOL=$(( 10#${int:-0} * 100 + 10#$frac ))
}

# ───────────────────────── 渲染 ─────────────────────────

# paint COLOR TEXT -> REPLY (带 polybar 颜色标签; COLOR 为空则原样返回)
paint() {
    if [[ -n $1 ]]; then REPLY="%{F$1}$2%{F-}"; else REPLY=$2; fi
}

render() {
    get_state

    local off=0 icon pct bar fill empty n c_icon=$PW_COLOR_ICON c_text=$PW_COLOR_TEXT out
    (( MUTED || VOL == 0 )) && off=1

    # 图标
    if [[ $KIND == source ]]; then
        (( off )) && icon=$PW_ICON_MIC_OFF || icon=$PW_ICON_MIC
    elif (( off ));        then icon=$PW_ICON_MUTE
    elif (( VOL < 34 ));   then icon=$PW_ICON_LOW
    elif (( VOL < 67 ));   then icon=$PW_ICON_MID
    else                        icon=$PW_ICON_HIGH
    fi

    # 百分比
    if (( NODEV )); then pct='--'
    elif (( MUTED )) && [[ -n $PW_LABEL_MUTED ]]; then pct=$PW_LABEL_MUTED
    else pct="${VOL}%"
    fi

    # 进度条
    n=$(( (VOL > 100 ? 100 : VOL) * PW_BAR_WIDTH + 50 ))
    n=$(( n / 100 ))
    printf -v fill  '%*s' "$n" ''
    printf -v empty '%*s' "$(( PW_BAR_WIDTH - n ))" ''
    bar=${fill// /$PW_BAR_FILL}${empty// /$PW_BAR_EMPTY}

    # 颜色: 静音/无设备 -> 灰, 超过 100% -> 警告色
    if (( off )); then
        c_icon=$PW_COLOR_MUTED c_text=$PW_COLOR_MUTED
    elif (( VOL > 100 )); then
        c_icon=$PW_COLOR_WARN c_text=$PW_COLOR_WARN
    fi

    out=$PW_FORMAT
    paint "$c_icon" "$icon"
    [[ -n $PW_ICON_FONT ]] && REPLY="%{T$PW_ICON_FONT}$REPLY%{T-}"
    out=${out//\{icon\}/$REPLY}
    paint "$c_text" "$pct";  out=${out//\{pct\}/$REPLY}
    paint "$c_text" "$bar";  out=${out//\{bar\}/$REPLY}

    # 内容没变化就不输出, 避免 polybar 无谓重绘
    if [[ $out != "$LAST" ]]; then
        LAST=$out
        printf '%s\n' "$out"
    fi
}

# ───────────────────────── 事件监听 ─────────────────────────

cleanup() {
    [[ -n $SUB_PID ]] && kill "$SUB_PID" 2>/dev/null
    [[ -n $FD ]] && exec {FD}<&-
    SUB_PID='' FD=''
}

listen() {
    local line
    trap cleanup EXIT
    trap 'exit 0' TERM INT HUP

    render

    # 没有 pactl 时退化为 1 秒轮询
    if ! command -v pactl >/dev/null 2>&1; then
        while sleep 1; do render; done
    fi

    while :; do
        exec {FD}< <(exec pactl subscribe 2>/dev/null)
        SUB_PID=$!
        render      # (重新)连接后同步一次状态

        while read -r -u "$FD" line; do
            # 只关心 sink / source / server(默认设备切换) 事件, 忽略 sink-input 等
            case $line in
                *" on sink #"*|*" on source #"*|*" on server"*) ;;
                *) continue ;;
            esac
            # 去抖: 吃掉 50ms 内连续到达的事件 (快速滚轮时合并为一次刷新)
            while read -r -t 0.05 -u "$FD" _; do :; done
            render
        done

        cleanup     # pipewire 重启 / pactl 退出 -> 稍后重连
        sleep 1
    done
}

# ───────────────────────── 操作 ─────────────────────────

limit_float() {   # 150 -> 1.50
    printf '%d.%02d' $(( PW_MAX_VOL / 100 )) $(( PW_MAX_VOL % 100 ))
}

usage() {
    sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
}

main() {
    local cmd=${1:-show}

    KIND=${2:-sink}
    case $KIND in
        sink)   TARGET=@DEFAULT_AUDIO_SINK@ ;;
        source) TARGET=@DEFAULT_AUDIO_SOURCE@ ;;
        *)      usage ;;
    esac

    if ! command -v wpctl >/dev/null 2>&1; then
        echo "wpctl not found"
        exit 1
    fi

    load_config

    case $cmd in
        listen) listen ;;
        show)   render ;;
        up)
            (( PW_AUTO_UNMUTE )) && wpctl set-mute "$TARGET" 0
            wpctl set-volume -l "$(limit_float)" "$TARGET" "${PW_STEP}%+"
            ;;
        down)
            wpctl set-volume "$TARGET" "${PW_STEP}%-"
            ;;
        toggle)
            wpctl set-mute "$TARGET" toggle
            ;;
        set)
            [[ ${3:-} =~ ^[0-9]+$ ]] || usage
            wpctl set-volume -l "$(limit_float)" "$TARGET" "${3}%"
            ;;
        *) usage ;;
    esac
}

main "$@"
