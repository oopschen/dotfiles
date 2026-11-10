#!/usr/bin/env bash
# ==============================================================================
# i3-utils-cmd-term.sh —— i3wm 下的"呼出式命令终端"
#
# 同一个快捷键，三种工作模式：
#   swap       （默认）终端始终可见，没有隐藏状态；形态由"当前所在 workspace"决定。
#              只允许两种合法状态：
#                当前 ws 是指定 ws   -> 窗体非浮动，位于指定 ws 中
#                当前 ws 不是指定 ws -> 窗体浮动，位于当前 ws 的左侧（或右侧）
#              按键行为：
#                当前 ws = 指定 ws   窗体已非浮动且在其中 => 不作动作；否则移入并聚焦
#                当前 ws != 指定 ws  窗体未浮动在当前 ws => 浮动显示在当前 ws；
#                                    已浮动在当前 ws    => 再按则推送回指定 ws（不切换焦点）
#              （--refocus 可在指定 ws 内窗体未聚焦时补一次聚焦）
#   float      仅漂浮窗，scratchpad 显隐，已聚焦时再按则隐藏
#   workspace  仅固定 workspace，已聚焦时再按则返回上一个 workspace
#
# 依赖：i3-msg  jq  bash>=4   （可选：flock，防止连按快捷键时重复启动）
#
# ------------------------------------------------------------------------------
# i3 配置示例（快捷键在 i3 config 中实现，只需一个键）
#
#   # 默认 swap 模式：窗体形态跟随当前 workspace
#   bindsym $mod+grave exec --no-startup-id i3-utils-cmd-term.sh toggle
#
#   # 可选：切换"当前模式"（swap / float / workspace 之间选定一个，会话内有效）
#   bindsym $mod+Shift+grave exec --no-startup-id i3-utils-cmd-term.sh --set-mode float
#
#   # 或者固定参数，不依赖状态文件：
#   # bindsym $mod+grave exec --no-startup-id i3-utils-cmd-term.sh -m swap -w 9 -s left toggle
#
#   # 可选：首次启动时无闪烁（窗口一出现就是浮动）
#   # for_window [instance="cmdterm"] floating enable
#
# ------------------------------------------------------------------------------
# 用法：i3-utils-cmd-term.sh [选项] [动作]
#   动作  show    召回并聚焦（默认，不切换形态/不隐藏）
#         toggle  swap 模式同 show；float 模式：隐藏；workspace 模式：返回上一 ws
#         launch  仅确保进程已启动，不抢焦点
#   所有选项均可通过同名环境变量 CMDTERM_* 设置，命令行优先。详见 --help。
# ==============================================================================

set -u
set -o pipefail

readonly SCRIPT_NAME=${0##*/}
readonly RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp}

# ------------------------------------------------------------------------------
# 1. 配置（默认值 <- 环境变量 <- 命令行）
# ------------------------------------------------------------------------------
ACTION=${CMDTERM_ACTION:-show}              # show | toggle | launch
MODE=${CMDTERM_MODE:-}                      # swap | float | workspace（空则读状态文件，再默认 swap）
INSTANCE=${CMDTERM_INSTANCE:-cmdterm}       # 终端窗口的 WM_CLASS instance（不区分大小写）
LAUNCH_CMD=${CMDTERM_LAUNCH_CMD:-'i3-utils-base-term.sh "-n {instance} -t {instance}"'}
WAIT_TIMEOUT=${CMDTERM_WAIT_TIMEOUT:-3}     # 启动后等待窗口出现的最长秒数

# 固定形态参数
WORKSPACE=${CMDTERM_WORKSPACE:-9}           # 目标 workspace 名称

# 漂浮形态参数
FLOAT_SIDE=${CMDTERM_FLOAT_SIDE:-left}      # left | right
FLOAT_WIDTH=${CMDTERM_FLOAT_WIDTH:-45}      # 宽度，工作区百分比 (ppt)
FLOAT_HEIGHT=${CMDTERM_FLOAT_HEIGHT:-80}    # 高度，工作区百分比 (ppt)
FLOAT_MARGIN_X=${CMDTERM_FLOAT_MARGIN_X:-0} # 距停靠边缘的像素
FLOAT_MARGIN_Y=${CMDTERM_FLOAT_MARGIN_Y:-79} # 距顶部像素（给状态栏留空）

# swap 模式参数
SWAP_REFOCUS=${CMDTERM_SWAP_REFOCUS:-0}     # 1 = 已处于合法状态但未聚焦时，补一次聚焦

DEBUG=${CMDTERM_DEBUG:-0}
SET_MODE=""                                 # --set-mode 的值

MODE_FILE="$RUNTIME_DIR/i3-cmd-term-${UID:-0}.mode"

# ------------------------------------------------------------------------------
# 2. 通用工具函数
# ------------------------------------------------------------------------------
log()  { (( DEBUG )) && printf '[%s] %s\n' "$SCRIPT_NAME" "$*" >&2; return 0; }
die()  { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
用法: $SCRIPT_NAME [选项] [show|toggle|launch]

动作:
  show              召回并聚焦（默认）
  toggle            swap: 同 show；float: 隐藏；workspace: 返回上一 ws
  launch            只确保已启动，不抢焦点

模式:
  swap (默认)       始终可见；在指定 ws => 非浮动在其中；在其他 ws => 浮动在当前 ws，再按则推回指定 ws
  float             仅漂浮窗（scratchpad 显隐）
  workspace         仅固定 workspace

选项 (环境变量):
  -m, --mode MODE        swap | float | workspace        (CMDTERM_MODE)
      --set-mode MODE    写入状态文件并立即生效           (同上取值)
  -t, --toggle           等价于动作 toggle
  -i, --instance NAME    窗口 instance 名                (CMDTERM_INSTANCE, 默认 $INSTANCE)
  -c, --cmd CMD          启动命令，{instance} 会被替换    (CMDTERM_LAUNCH_CMD)
  -w, --workspace NAME   固定形态的目标 ws               (CMDTERM_WORKSPACE, 默认 $WORKSPACE)
  -s, --side SIDE        漂浮停靠边: left | right         (CMDTERM_FLOAT_SIDE, 默认 $FLOAT_SIDE)
      --width N          漂浮宽度 ppt                     (CMDTERM_FLOAT_WIDTH, 默认 $FLOAT_WIDTH)
      --height N         漂浮高度 ppt                     (CMDTERM_FLOAT_HEIGHT, 默认 $FLOAT_HEIGHT)
      --margin-x N       漂浮距停靠边缘 px                (CMDTERM_FLOAT_MARGIN_X, 默认 $FLOAT_MARGIN_X)
      --margin-y N       漂浮顶边距 px                    (CMDTERM_FLOAT_MARGIN_Y, 默认 $FLOAT_MARGIN_Y)
      --refocus          swap: 已处于合法状态但未聚焦时补一次聚焦 (CMDTERM_SWAP_REFOCUS=1)
      --timeout SEC      启动后等待窗口出现的秒数         (CMDTERM_WAIT_TIMEOUT, 默认 $WAIT_TIMEOUT)
  -d, --debug            输出调试信息                     (CMDTERM_DEBUG=1)
  -h, --help             显示本帮助

模式优先级: --mode > CMDTERM_MODE > 状态文件($MODE_FILE) > swap
EOF
}

is_uint() { [[ $1 =~ ^[0-9]+$ ]]; }

# 执行 i3 命令；同一动作的多条命令合并成一次 i3-msg 调用，减少 IPC 往返
i3cmd() {
    log "i3-msg: $*"
    i3-msg "$*" >/dev/null
}

# ------------------------------------------------------------------------------
# 3. 参数解析与校验
# ------------------------------------------------------------------------------
parse_args() {
    while (( $# )); do
        case $1 in
            show|toggle|launch) ACTION=$1 ;;
            -t|--toggle)    ACTION=toggle ;;
            -m|--mode)      MODE=${2:?"$1 需要参数"};           shift ;;
            --set-mode)     SET_MODE=${2:?"$1 需要参数"};       shift ;;
            -i|--instance)  INSTANCE=${2:?"$1 需要参数"};       shift ;;
            -c|--cmd)       LAUNCH_CMD=${2:?"$1 需要参数"};     shift ;;
            -w|--workspace) WORKSPACE=${2:?"$1 需要参数"};      shift ;;
            -s|--side)      FLOAT_SIDE=${2:?"$1 需要参数"};     shift ;;
            --width)        FLOAT_WIDTH=${2:?"$1 需要参数"};    shift ;;
            --height)       FLOAT_HEIGHT=${2:?"$1 需要参数"};   shift ;;
            --margin-x)     FLOAT_MARGIN_X=${2:?"$1 需要参数"}; shift ;;
            --margin-y)     FLOAT_MARGIN_Y=${2:?"$1 需要参数"}; shift ;;
            --refocus)      SWAP_REFOCUS=1 ;;
            --timeout)      WAIT_TIMEOUT=${2:?"$1 需要参数"};   shift ;;
            -d|--debug)     DEBUG=1 ;;
            -h|--help)      usage; exit 0 ;;
            *)              usage >&2; die "未知参数: $1" ;;
        esac
        shift
    done
}

# 解析"当前模式"：命令行/环境变量 > 状态文件 > 默认 swap
resolve_mode() {
    if [[ -z $MODE && -r $MODE_FILE ]]; then
        read -r MODE <"$MODE_FILE"
    fi
    MODE=${MODE:-swap}
}

# 处理 --set-mode：写状态文件，本次调用随即按新模式召回窗口
apply_set_mode() {
    [[ -z $SET_MODE ]] && return 0
    case $SET_MODE in
        swap|float|workspace) ;;
        *) die "--set-mode 只接受 swap | float | workspace" ;;
    esac
    MODE=$SET_MODE
    ACTION=show
    printf '%s\n' "$MODE" >"$MODE_FILE"
    log "mode -> $MODE"
}

validate() {
    case $MODE in swap|float|workspace) ;; *) die "未知模式: $MODE" ;; esac
    case $FLOAT_SIDE in left|right) ;; *) die "--side 只接受 left | right" ;; esac
    local v
    for v in FLOAT_WIDTH FLOAT_HEIGHT FLOAT_MARGIN_X FLOAT_MARGIN_Y WAIT_TIMEOUT; do
        is_uint "${!v}" || die "$v 必须是非负整数: ${!v}"
    done
    command -v i3-msg >/dev/null || die "缺少依赖: i3-msg"
    command -v jq     >/dev/null || die "缺少依赖: jq"
}

# ------------------------------------------------------------------------------
# 4. 窗口状态查询（整个脚本的核心性能点）
#
# 只调用一次 i3-msg + 一次 jq，递归遍历窗口树，输出两行：
#   第 1 行  当前聚焦 workspace："x y 宽 高 名称"（rect 用于计算浮动窗的绝对坐标）
#   第 2 行  第一个匹配 instance 的窗口："con_id floating focused 所在workspace"
#            （窗口不存在则为空行；找到即停止遍历）
# 设置全局变量 CUR_X CUR_Y CUR_W CUR_H CUR_WS 与 WIN_ID WIN_FLOATING WIN_FOCUSED WIN_WS，
# 窗口存在时返回 0。scratchpad 中的窗口 WIN_WS 以 "__" 开头（如 __i3_scratch）。
# ------------------------------------------------------------------------------
CUR_X="" CUR_Y="" CUR_W="" CUR_H="" CUR_WS=""
WIN_ID="" WIN_FLOATING="" WIN_FOCUSED="" WIN_WS=""

query_window() {
    local out curline winline
    out=$(i3-msg -t get_tree 2>/dev/null | jq -r --arg inst "${INSTANCE,,}" '
        def focusedws(ws):
            (if .type == "workspace" then {name: .name, rect: .rect} else ws end) as $w
            | if .focused == true then $w
              else (.nodes[]?, .floating_nodes[]?) | focusedws($w)
              end;
        def find(ws):
            (if .type == "workspace" then .name else ws end) as $w
            | if ((.window_properties.instance // "" | ascii_downcase) == $inst)
              then "\(.id) \(.floating) \(.focused) \($w)"
              else (.nodes[]?, .floating_nodes[]?) | find($w)
              end;
        ((first(focusedws({})) // {})
            | if .name then "\(.rect.x) \(.rect.y) \(.rect.width) \(.rect.height) \(.name)" else "" end),
        (first(find("")) // "")' 2>/dev/null)

    CUR_X="" CUR_Y="" CUR_W="" CUR_H="" CUR_WS=""
    WIN_ID="" WIN_FLOATING="" WIN_FOCUSED="" WIN_WS=""
    curline="" winline=""
    { IFS= read -r curline; IFS= read -r winline; } <<<"$out"
    [[ -n $curline ]] && read -r CUR_X CUR_Y CUR_W CUR_H CUR_WS <<<"$curline"
    [[ -n $winline ]] || return 1
    read -r WIN_ID WIN_FLOATING WIN_FOCUSED WIN_WS <<<"$winline"
    log "cur_ws=$CUR_WS rect=${CUR_X},${CUR_Y} ${CUR_W}x${CUR_H} | window: id=$WIN_ID floating=$WIN_FLOATING focused=$WIN_FOCUSED ws=$WIN_WS"
}

win_is_floating()   { [[ $WIN_FLOATING == *_on ]]; }
win_is_focused()    { [[ $WIN_FOCUSED == true ]]; }
win_in_scratchpad() { [[ $WIN_WS == __* ]]; }

# ------------------------------------------------------------------------------
# 5. 启动终端并等待窗口出现
# ------------------------------------------------------------------------------
JUST_LAUNCHED=0

launch_term() {
    local cmd=${LAUNCH_CMD//\{instance\}/$INSTANCE}
    log "launch: $cmd"
    # 关闭 fd 9（锁），避免终端进程长期持有锁；setsid 使其脱离本脚本
    ( setsid bash -c "$cmd" 9>&- >/dev/null 2>&1 & )
}

# 以 50ms 间隔轮询，窗口一出现就返回，比固定 sleep 快
wait_window() {
    local i max=$(( WAIT_TIMEOUT * 20 ))
    for (( i = 0; i < max; i++ )); do
        query_window && return 0
        sleep 0.05
    done
    return 1
}

ensure_window() {
    query_window && return 0
    launch_term
    wait_window || die "等待窗口超时 (instance=$INSTANCE)，请检查启动命令"
    JUST_LAUNCHED=1
}

# ------------------------------------------------------------------------------
# 6. 两种"形态"的基本操作（各模式共用）
# ------------------------------------------------------------------------------

# --- 漂浮形态 ---------------------------------------------------------------
# 以"当前聚焦 workspace"的 rect 为基准，计算绝对像素坐标，
# 并用 move absolute position 定位，保证窗体落在当前聚焦的显示器上（多显示器安全）。
# 取不到 rect 时退回 i3 相对定位。
float_geometry() {
    local w h x y
    if [[ -n $CUR_W && -n $CUR_H ]]; then
        w=$(( CUR_W * FLOAT_WIDTH  / 100 ))
        h=$(( CUR_H * FLOAT_HEIGHT / 100 ))
        if [[ $FLOAT_SIDE == right ]]; then
            x=$(( CUR_X + CUR_W - w - FLOAT_MARGIN_X ))
        else
            x=$(( CUR_X + FLOAT_MARGIN_X ))
        fi
        y=$(( CUR_Y + FLOAT_MARGIN_Y ))
        printf 'resize set %d px %d px, move absolute position %d px %d px' "$w" "$h" "$x" "$y"
    else
        if [[ $FLOAT_SIDE == right ]]; then x="$(( 100 - FLOAT_WIDTH )) ppt"; else x="$FLOAT_MARGIN_X px"; fi
        printf 'resize set %s ppt %s ppt, move position %s %s px' \
            "$FLOAT_WIDTH" "$FLOAT_HEIGHT" "$x" "$FLOAT_MARGIN_Y"
    fi
}

# 浮在"当前聚焦 workspace"的左侧（或右侧）并聚焦
float_show() {
    local c="[con_id=$WIN_ID]" geom
    geom=$(float_geometry)
    if win_in_scratchpad; then
        # 从 scratchpad 取出，显示在当前 workspace
        i3cmd "$c scratchpad show, $geom"
    else
        # 无论窗口原来在哪个 workspace、是否平铺：拉到当前 ws，转浮动，定位，聚焦
        i3cmd "$c move container to workspace current, floating enable, $geom, focus"
    fi
}

float_hide() { i3cmd "[con_id=$WIN_ID] move scratchpad"; }

# --- 固定 workspace 形态 ------------------------------------------------------
# 目标 workspace 在 i3 命令中的写法。
# 目标恰好是当前聚焦的 ws 时必须写 current：若写名字，开启了
# workspace_auto_back_and_forth 的 i3 会把 "move container to workspace <当前ws>"
# 重定向到上一个 ws，结果窗体没有被移过来（只执行了后面的 floating disable）。
ws_target() {
    if [[ $CUR_WS == "$WORKSPACE" ]]; then
        printf 'current'
    else
        printf '"%s"' "$WORKSPACE"
    fi
}

# 移入目标 ws 并取消浮动，不切换焦点
ws_place() { i3cmd "[con_id=$WIN_ID] move container to workspace $(ws_target), floating disable"; }

# 移入目标 ws、取消浮动，并用 criteria focus 切过去
# 不用 "workspace X"，同样是为了避开 workspace_auto_back_and_forth 的误跳
ws_show()  { i3cmd "[con_id=$WIN_ID] move container to workspace $(ws_target), floating disable, focus"; }

# ------------------------------------------------------------------------------
# 7. 各模式的处理逻辑
# ------------------------------------------------------------------------------

# swap：始终可见，形态跟随"当前 workspace"，只允许两种合法状态：
#   当前 ws == 指定 ws -> 非浮动，位于指定 ws；已满足则不作动作
#   当前 ws != 指定 ws -> 浮动，位于当前 ws（左侧/右侧）；已满足时再按则推回指定 ws
handle_swap() {
    if [[ $ACTION == launch ]]; then
        (( JUST_LAUNCHED )) && ws_place          # 后台就位，不抢焦点
        return
    fi

    if [[ $CUR_WS == "$WORKSPACE" ]]; then
        if ! win_is_floating && [[ $WIN_WS == "$WORKSPACE" ]]; then
            swap_idle                            # 已是合法状态，不作其它动作
        else
            ws_show
        fi
    else
        # 刚启动的窗口需要先套用位置和大小，所以不算"已浮动在当前 ws"
        if (( ! JUST_LAUNCHED )) && win_is_floating && [[ $WIN_WS == "$CUR_WS" ]]; then
            ws_place                             # 再次执行：推送到指定 ws（不切换焦点）
        else
            float_show
        fi
    fi
}

# 已处于合法状态：不作其它动作；仅当 --refocus 且未聚焦时聚焦
swap_idle() {
    if (( SWAP_REFOCUS )) && ! win_is_focused; then
        i3cmd "[con_id=$WIN_ID] focus"
    fi
    return 0
}

# float：scratchpad 漂浮窗，已聚焦时再按则隐藏
handle_float() {
    if [[ $ACTION == launch ]]; then
        (( JUST_LAUNCHED )) && float_hide
        return
    fi

    if (( JUST_LAUNCHED )) || win_in_scratchpad \
        || ! win_is_floating || ! win_is_focused; then
        float_show
    elif [[ $ACTION == toggle ]]; then
        float_hide
    else
        i3cmd "[con_id=$WIN_ID] focus"
    fi
}

# workspace：固定 workspace，已聚焦时再按则返回上一个 workspace
handle_workspace() {
    if [[ $ACTION == launch ]]; then
        (( JUST_LAUNCHED )) && ws_place
        return
    fi

    if (( JUST_LAUNCHED )) || win_in_scratchpad || win_is_floating \
        || [[ $WIN_WS != "$WORKSPACE" ]]; then
        ws_show
    elif win_is_focused; then
        [[ $ACTION == toggle ]] && i3cmd "workspace back_and_forth"
    else
        i3cmd "[con_id=$WIN_ID] focus"
    fi
}

# ------------------------------------------------------------------------------
# 8. 主流程
# ------------------------------------------------------------------------------
main() {
    parse_args "$@"
    resolve_mode
    apply_set_mode
    validate

    # 防止启动期间连按快捷键导致重复启动多个终端
    if command -v flock >/dev/null; then
        exec 9>"$RUNTIME_DIR/i3-cmd-term-${INSTANCE}.lock"
        flock -n 9 || { log "另一个实例正在运行，退出"; exit 0; }
    fi

    ensure_window

    case $MODE in
        swap)      handle_swap ;;
        float)     handle_float ;;
        workspace) handle_workspace ;;
    esac
}

main "$@"
