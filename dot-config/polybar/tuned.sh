#!/usr/bin/env bash
# =============================================================================
#  polybar tuned 模块 —— 单文件：显示 + 切换 + 配置
#
#  功能
#    - 事件驱动：监听 tuned 的 DBus 信号 profile_changed，无轮询、近零 CPU 占用
#    - 图标优先：nerd / emoji / text 三套样式，可独立设置每个 profile 的图标与颜色
#    - 点击切换：左键下一个，右键上一个，中键弹出菜单(rofi/wofi/dmenu)，滚轮上下切换
#
#  依赖：bash >= 4.3, tuned-adm, dbus-monitor(可选，没有则退化为 2s 轮询)
#        Nerd Font / Font Awesome 字体(nerd 样式)，rofi|wofi|dmenu(菜单，可选)
#
#  ---------------------------- polybar 配置 ---------------------------------
#  [module/tuned]
#  type = custom/script
#  exec = ~/.config/polybar/scripts/tuned.sh
#  tail = true
#  format = <label>
#  format-padding = 1
#  label = %output%
#  ; 换样式示例：
#  ; exec = env TUNED_STYLE=emoji TUNED_SHOW=icon ~/.config/polybar/scripts/tuned.sh
#
#  并确保 modules-right 等位置加入 tuned，bar 字体里包含 Nerd Font：
#  font-0 = "JetBrainsMono Nerd Font:size=11;2"
#
#  ------------------------------ 权限说明 -----------------------------------
#  切换 profile 需要权限。脚本依次尝试：tuned-adm -> sudo -n -> pkexec。
#  推荐免密 polkit 规则 /etc/polkit-1/rules.d/50-tuned.rules ：
#    polkit.addRule(function(a, s) {
#      if (a.id == "com.redhat.tuned.switch_profile" && s.isInGroup("wheel"))
#        return polkit.Result.YES;
#    });
#
#  ------------------------------ 白名单 -------------------------------------
#  只允许切换 WHITELIST 中的 profile（循环顺序即白名单顺序）。
#  修改脚本配置区的 WHITELIST，或在 polybar 里用环境变量覆盖：
#    exec = env TUNED_WHITELIST="powersave balanced" ~/.config/polybar/scripts/tuned.sh
#  白名单为空字符串 = 不限制。注意：这只限制本脚本，不是安全边界；
#  若要系统级限制，请用 polkit / sudoers 规则（见下）。
#
#  ------------------------------ 命令行 -------------------------------------
#    tuned.sh              常驻输出模式(polybar 用)
#    tuned.sh --next       切换到下一个 profile
#    tuned.sh --prev       切换到上一个 profile
#    tuned.sh --menu       弹出选择菜单
#    tuned.sh --set NAME   切换到指定 profile
#    tuned.sh --once       只输出一次当前状态
# =============================================================================

set -u
[[ ${LANG:-} == *[Uu][Tt][Ff]-8* ]] || export LC_ALL=C.UTF-8

# ============================== 用户配置区 ===================================
STYLE=${TUNED_STYLE:-nerd}       # nerd | emoji | text      图标样式
SHOW=${TUNED_SHOW:-both}         # icon | label | both      显示内容
SHORT=${TUNED_SHORT:-0}          # 1 = label 使用短名称
# 白名单：只允许切换这些 profile（同时也是循环切换的顺序），空格分隔。
# 留空 = 不限制，使用 tuned-adm list 的全部 profile。
# 也可通过环境变量覆盖：TUNED_WHITELIST="powersave balanced throughput-performance"
WHITELIST=${TUNED_WHITELIST:-"powersave laptop-battery-powersave balanced balanced-battery latency-performance"}
NOTIFY=${TUNED_NOTIFY:-0}        # 1 = 切换后 notify-send
FALLBACK=${TUNED_FALLBACK:-60}   # 兜底刷新间隔(秒)，正常情况靠 DBus 事件触发
SEP=${TUNED_SEP:-" "}            # 图标与文字之间的分隔

# 颜色(留空则使用 polybar 默认前景色)；每个 profile 可单独设置
declare -A COLOR=(
  [balanced]="#89b4fa"
  [powersave]="#a6e3a1"
  [throughput-performance]="#fab387"
  [latency-performance]="#f38ba8"
  [accelerator-performance]="#f9e2af"
  [network-latency]="#94e2d5"
  [network-throughput]="#74c7ec"
  [virtual-guest]="#cba6f7"
  [virtual-host]="#cba6f7"
  [desktop]="#89dceb"
  [hpc-compute]="#eba0ac"
  [off]="#6c7086"
  [_default]="#cdd6f4"
)

# --- 样式 1：Nerd Font / Font Awesome 图标 ---
declare -A ICON_NERD=(
  [balanced]=$'\uf24e'               # balance-scale
  [powersave]=$'\uf06c'              # leaf
  [throughput-performance]=$'\uf0e7' # bolt
  [latency-performance]=$'\uf135'    # rocket
  [accelerator-performance]=$'\uf2db' # microchip
  [network-latency]=$'\uf1eb'        # wifi
  [network-throughput]=$'\uf0ac'     # globe
  [virtual-guest]=$'\uf233'          # server
  [virtual-host]=$'\uf233'
  [desktop]=$'\uf108'                # desktop
  [hpc-compute]=$'\uf0e4'            # tachometer
  [off]=$'\uf011'                    # power-off
  [_default]=$'\uf013'               # cog
)

# --- 样式 2：Emoji ---
declare -A ICON_EMOJI=(
  [balanced]="⚖️" [powersave]="🍃" [throughput-performance]="⚡"
  [latency-performance]="🚀" [accelerator-performance]="🔥"
  [network-latency]="📡" [network-throughput]="🌐"
  [virtual-guest]="🖥️" [virtual-host]="🖥️" [desktop]="💻"
  [hpc-compute]="🏎️" [off]="⭕" [_default]="⚙️"
)

# --- 样式 3：纯文本短标签 ---
declare -A ICON_TEXT=(
  [balanced]="BAL" [powersave]="SAVE" [throughput-performance]="THRU"
  [latency-performance]="LAT" [accelerator-performance]="ACC"
  [network-latency]="NLAT" [network-throughput]="NTHR"
  [virtual-guest]="VGST" [virtual-host]="VHST" [desktop]="DESK"
  [hpc-compute]="HPC" [off]="OFF" [_default]="TUNED"
)

# 短名称(SHORT=1 时 label 使用)
declare -A SHORT_NAME=(
  [balanced]="Balanced" [powersave]="Save" [throughput-performance]="Throughput"
  [latency-performance]="Latency" [accelerator-performance]="Accel"
  [network-latency]="Net-Lat" [network-throughput]="Net-Thr"
  [virtual-guest]="Guest" [virtual-host]="Host" [desktop]="Desktop"
  [hpc-compute]="HPC" [off]="Off"
)
# ============================ 用户配置区结束 =================================

SELF=$(readlink -f "$0")
ACTIVE_FILE=/etc/tuned/active_profile
PIDDIR=${XDG_RUNTIME_DIR:-/tmp}/polybar-tuned
ACTIVE=""
LAST=""
PROFILES=()

# ------------------------------ 基础函数 -------------------------------------

# 读取当前 profile -> $ACTIVE（优先读文件，不 fork 进程）
get_active() {
  ACTIVE=""
  [[ -r $ACTIVE_FILE ]] && read -r ACTIVE < "$ACTIVE_FILE"
  if [[ -z $ACTIVE ]]; then
    ACTIVE=$(tuned-adm active 2>/dev/null | sed -n 's/^Current active profile: //p')
  fi
  [[ -z $ACTIVE ]] && ACTIVE=off
}

# 加载可用 profile 列表 -> $PROFILES
load_profiles() {
  local -a installed=() wl=()
  local p q
  mapfile -t installed < <(tuned-adm list 2>/dev/null | sed -n 's/^- \([^ ]\+\).*/\1/p')

  if [[ -z $WHITELIST ]]; then
    PROFILES=("${installed[@]}")
    return
  fi

  # 保持白名单顺序；若能取到已安装列表，则剔除系统里不存在的 profile
  read -ra wl <<< "$WHITELIST"
  PROFILES=()
  for p in "${wl[@]}"; do
    if (( ${#installed[@]} == 0 )); then
      PROFILES+=("$p")
    else
      for q in "${installed[@]}"; do
        [[ $p == "$q" ]] && { PROFILES+=("$p"); break; }
      done
    fi
  done
}

# 判断 profile 是否在白名单内（白名单为空则全部允许）
is_allowed() {
  local p
  [[ -z $WHITELIST ]] && return 0
  for p in $WHITELIST; do
    [[ $p == "$1" ]] && return 0
  done
  return 1
}

# 取图标
icon_of() {
  local p=$1
  case $STYLE in
    emoji) printf '%s' "${ICON_EMOJI[$p]:-${ICON_EMOJI[_default]}}" ;;
    text)  printf '%s' "${ICON_TEXT[$p]:-${ICON_TEXT[_default]}}" ;;
    *)     printf '%s' "${ICON_NERD[$p]:-${ICON_NERD[_default]}}" ;;
  esac
}

# 渲染一行 polybar 输出（内嵌点击/滚轮动作，因此无需在 polybar 里写 click-*）
render() {
  get_active
  local p=$ACTIVE color icon label out
  color=${COLOR[$p]:-${COLOR[_default]}}
  icon=$(icon_of "$p")
  if [[ $SHORT == 1 ]]; then label=${SHORT_NAME[$p]:-$p}; else label=$p; fi

  case $SHOW in
    icon)  out=$icon ;;
    label) out=$label ;;
    *)     out="$icon$SEP$label" ;;
  esac
  [[ -n $color ]] && out="%{F$color}$out%{F-}"

  out="%{A1:$SELF --next:}%{A3:$SELF --prev:}%{A2:$SELF --menu:}%{A4:$SELF --prev:}%{A5:$SELF --next:}${out}%{A}%{A}%{A}%{A}%{A}"

  # 仅在内容变化时输出
  if [[ $out != "$LAST" ]]; then
    printf '%s\n' "$out"
    LAST=$out
  fi
}

# 通知所有常驻实例立即刷新（多 bar 场景也适用）
poke_watchers() {
  local f pid
  [[ -d $PIDDIR ]] || return 0
  for f in "$PIDDIR"/*; do
    [[ -e $f ]] || continue
    pid=${f##*/}
    kill -USR1 "$pid" 2>/dev/null || rm -f "$f"
  done
}

# ------------------------------ 切换逻辑 -------------------------------------

switch_to() {
  local target=$1
  if ! is_allowed "$target"; then
    command -v notify-send >/dev/null \
      && notify-send -a tuned -u normal "Tuned" "$target 不在白名单内，已拒绝切换"
    echo "拒绝: $target 不在白名单 ($WHITELIST)" >&2
    return 1
  fi
  if tuned-adm profile "$target" 2>/dev/null \
     || sudo -n tuned-adm profile "$target" 2>/dev/null \
     || pkexec tuned-adm profile "$target" 2>/dev/null; then
    [[ $NOTIFY == 1 ]] && command -v notify-send >/dev/null \
      && notify-send -a tuned -t 1500 "Tuned" "Profile → $target"
    poke_watchers
  else
    command -v notify-send >/dev/null \
      && notify-send -a tuned -u critical "Tuned" "切换到 $target 失败（权限不足？）"
    return 1
  fi
}

# 按方向循环：+1 下一个，-1 上一个
cycle() {
  local dir=$1 i n idx
  load_profiles
  n=${#PROFILES[@]}
  (( n == 0 )) && return 1
  get_active
  # 当前 profile 不在白名单时：下一个 -> 第一项，上一个 -> 最后一项
  (( dir > 0 )) && idx=-1 || idx=0
  for i in "${!PROFILES[@]}"; do
    [[ ${PROFILES[$i]} == "$ACTIVE" ]] && { idx=$i; break; }
  done
  idx=$(( (idx + dir + n) % n ))
  switch_to "${PROFILES[$idx]}"
}

menu() {
  local choice
  load_profiles
  (( ${#PROFILES[@]} == 0 )) && return 1
  get_active
  if   command -v rofi  >/dev/null; then choice=$(printf '%s\n' "${PROFILES[@]}" | rofi -dmenu -i -p "tuned [$ACTIVE]")
  elif command -v wofi  >/dev/null; then choice=$(printf '%s\n' "${PROFILES[@]}" | wofi --dmenu -p "tuned [$ACTIVE]")
  elif command -v dmenu >/dev/null; then choice=$(printf '%s\n' "${PROFILES[@]}" | dmenu -i -p "tuned:")
  else cycle 1; return; fi
  [[ -n $choice ]] && switch_to "$choice"
}

# ------------------------------ 常驻监听 -------------------------------------

watch() {
  mkdir -p "$PIDDIR"
  : > "$PIDDIR/$$"
  trap 'rm -f "$PIDDIR/$$"; [[ -n ${DBM_PID:-} ]] && kill "$DBM_PID" 2>/dev/null' EXIT
  trap 'exit 0' INT TERM
  trap render USR1

  render

  if command -v dbus-monitor >/dev/null; then
    coproc DBM {
      exec dbus-monitor --system \
        "type='signal',interface='com.redhat.tuned.control',member='profile_changed'" 2>/dev/null
    }
    while :; do
      if read -r -t "$FALLBACK" -u "${DBM[0]}" _; then
        # 一个信号会产生多行输出，合并处理
        while read -r -t 0.15 -u "${DBM[0]}" _; do :; done
        render
      else
        # 超时 / 被 USR1 打断：监听进程挂了就退化为轮询
        kill -0 "$DBM_PID" 2>/dev/null || break
        render
      fi
    done
  fi

  # 退化模式：轻量轮询（可被 USR1 立即唤醒）
  while :; do
    render
    sleep 2 & wait $!
  done
}

# -------------------------------- 入口 ---------------------------------------

case ${1:-watch} in
  --next) cycle 1 ;;
  --prev) cycle -1 ;;
  --menu) menu ;;
  --set)  switch_to "${2:?用法: $0 --set <profile>}" ;;
  --once) render ;;
  watch|"") watch ;;
  *) echo "用法: ${0##*/} [--next|--prev|--menu|--set NAME|--once]" >&2; exit 1 ;;
esac
