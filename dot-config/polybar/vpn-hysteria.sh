#!/usr/bin/env bash
# polybar-vpn v2 — Hysteria + nftables(tproxy) + dnsmasq 状态模块（单节点，全自动发现）
# 需要 bash >= 4.2（>= 4.4 时少一次 fork）
#
# 用法: vpn.sh [watch|status|toggle|up|down|restart|refresh|info]
#   watch  : 给 polybar (tail=true) 使用，事件驱动，实时刷新
#   toggle : 点击切换 开/关（通过 hook 实现）
#   info   : 打印自动发现结果（终端输出，非终端则 notify-send）
#
# 自动发现:
#   hysteria : 扫描 /proc 找到客户端进程 -> 解析 -c/--config -> 读取 server(VPS)、tproxy 监听端口
#              进程未运行时: 使用上次缓存 -> systemd 单元 / openrc 配置里的 -c 参数
#   转发规则 : 扫描 nft 脚本目录(VPN_NFT_DIRS) 中含 tproxy 的规则 -> 表名/端口/mark/脚本文件
#              目录中没有时，有权限则读取运行中的 nft ruleset
#   dnsmasq  : 进程 + 端口检测
#
# 本脚本只做"检测 + 展示 + 调用 hook"，不直接操作 hysteria / nft / 服务。
# hook: up down on_change     查找顺序: VPN_HOOK_<NAME>(文件或命令) -> $VPN_HOOK_DIR/<name>
#   重启 = 先 down 再 up
# hook 环境变量: VPN_ACTION VPN_NODE VPN_CONFIG VPN_SERVER VPN_INIT VPN_SERVICE
#   VPN_SERVICE_SCOPE VPN_BIN VPN_NFT_TABLE VPN_NFT_FAMILY VPN_NFT_NAME VPN_NFT_FILE
#   VPN_TPROXY_PORT VPN_TPROXY_MARK VPN_DNS_PORT   (on_change 额外: VPN_OLD_STATE VPN_NEW_STATE)

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 2) )); then
  echo "bash >= 4.2 required" >&2; exit 1
fi
shopt -u patsub_replacement 2>/dev/null

############################ 配置区（均可用环境变量覆盖）############################

: "${VPN_STYLE:=compact}"          # icon | compact | full | fwd | dots (见 FORMATS，可自行添加)
: "${VPN_FORMAT:=}"             # 自定义格式，优先于 VPN_STYLE，如 '{icon} {name}'
: "${VPN_THEME:=catppuccin}"    # catppuccin | nord | gruvbox | dracula | mono
: "${VPN_ICON_MODE:=icon}"      # icon(Nerd Font/FontAwesome) | text(用显示名前两个字符)
: "${VPN_ICON_FONT:=2}"         # 图标字体在 polybar 中的 font-N 序号，0=不切换字体
: "${VPN_SHOW_SERVER:=host}"    # host | full(host:port) | none
: "${VPN_SERVER_MAX:=24}"       # VPS 地址最大显示长度
: "${VPN_LABEL_MAX:=15}"         # 自动生成的显示名最大长度

# 固定覆盖（留空=自动）。图标/名称自动来源: 配置文件注释 "# vpn: name=HK icon=rocket"
# -> 配置文件名/服务器域名中的关键词(AUTO_ICON) -> 按名称哈希从 AUTO_POOL 选择
: "${VPN_NAME:=}"
: "${VPN_ICON:=}"
: "${VPN_VPS:=}"                # 自动发现不到 VPS 地址(如配置不可读)时手动指定

: "${VPN_INTERVAL:=2}"          # 常态兜底轮询(秒)；netlink 事件/点击会立即唤醒
: "${VPN_FAST_INTERVAL:=0.5}"   # 状态切换中的快速轮询
: "${VPN_PENDING_TIMEOUT:=20}"  # 切换中状态超时(秒)

: "${VPN_CHECK_PORT:=1}"        # 检查 hysteria 是否在监听 tproxy 端口
: "${VPN_CHECK_NFT:=1}"         # 检查 nft tproxy 规则
: "${VPN_CHECK_DNS:=1}"         # 检查 dnsmasq
: "${VPN_DNS_PORT:=53}"
: "${VPN_NFT_TTL:=2}"           # nft 检测结果缓存(秒)

# nft 脚本目录(冒号分隔，条目可为目录或文件，支持 ~)，靠前优先
: "${VPN_NFT_DIRS:=/etc/nftables.d:/etc/nftables:/etc/nft:/etc/nftables.conf:/usr/local/etc/nftables.d:$HOME/.config/nftables:/etc/hysteria:$HOME/.config/hysteria}"
: "${VPN_NFT_GLOB:=*.nft *.nftables *.conf *.rules *.sh}"
: "${VPN_RESCAN:=1}"            # watch 中检测脚本/配置变化并自动重新发现

# 覆盖自动发现（留空=自动）
: "${VPN_NFT_TABLE:=}"          # 如 "inet hysteria"
: "${VPN_TPROXY_PORT:=}"
: "${VPN_TPROXY_MARK:=}"
: "${VPN_NFT_CHECK_CMD:=}"      # 自定义 nft 检测命令(返回0=规则已加载)

: "${VPN_INIT:=auto}"           # auto | systemd | openrc | process
: "${VPN_SERVICE:=auto}"        # 服务名；auto 自动探测
: "${VPN_BIN:=auto}"            # hysteria 可执行文件
: "${VPN_NOTIFY:=1}"            # 操作失败时 notify-send
: "${VPN_HOOK_DIR:=${XDG_CONFIG_HOME:-$HOME/.config}/polybar/vpn-hooks}"

# 图标 (Nerd Font 内含的 FontAwesome 码点)
declare -A ICONS=(
  [lock]=f023 [unlock]=f09c [shield]=f132 [rocket]=f135 [bolt]=f0e7 [plane]=f072
  [paper-plane]=f1d8 [globe]=f0ac [cloud]=f0c2 [fire]=f06d [diamond]=f219
  [star]=f005 [heart]=f004 [moon]=f186 [server]=f233 [leaf]=f06c [bug]=f188
  [warning]=f071
)
# 文件名/域名关键词 -> 图标 (按 - _ . 空格 分词后匹配)，可自行扩充
declare -A AUTO_ICON=(
  [hk]=rocket [hongkong]=rocket [jp]=bolt [japan]=bolt [us]=plane [usa]=plane
  [sg]=paper-plane [singapore]=paper-plane [tw]=leaf [taiwan]=leaf [kr]=fire
  [korea]=fire [uk]=diamond [de]=star [fr]=heart [ru]=moon [au]=cloud [ca]=globe
)
# 无关键词命中时，按名称哈希从池中挑选（同名稳定，不同节点图标不同）
AUTO_POOL=(rocket bolt plane paper-plane globe cloud fire diamond star heart moon leaf server)

# 主题（颜色）。状态: up down pending partial error，另有 text muted
declare -A THEMES=(
  [catppuccin]="up=#a6e3a1 down=#6c7086 pending=#f9e2af partial=#fab387 error=#f38ba8 text=#cdd6f4 muted=#7f849c"
  [nord]="up=#a3be8c down=#4c566a pending=#ebcb8b partial=#d08770 error=#bf616a text=#d8dee9 muted=#616e88"
  [gruvbox]="up=#b8bb26 down=#665c54 pending=#fabd2f partial=#fe8019 error=#fb4934 text=#ebdbb2 muted=#928374"
  [dracula]="up=#50fa7b down=#6272a4 pending=#f1fa8c partial=#ffb86c error=#ff5555 text=#f8f8f2 muted=#6272a4"
  [mono]="up=#ffffff down=#555555 pending=#aaaaaa partial=#999999 error=#ffffff text=#dddddd muted=#777777"
)
# 单色覆盖: VPN_COLOR_UP / _DOWN / _PENDING / _PARTIAL / _ERROR / _TEXT / _MUTED

# 样式（占位符: {icon} {name} {server} {tproxy} {state} {dots}）
declare -A FORMATS=(
  [icon]='{icon}'
  [compact]='{icon} {name} {dots}'
  [full]='{icon} {name} {server} {dots}'
  [fwd]='{icon} {name} {server} {tproxy} {dots}'
  [dots]='{name} {dots}'
)
declare -A STATE_TXT=([up]=ON [down]=OFF [pending]='...' [partial]=PART [error]=ERR)

############################ 实现 ############################

declare -A C NOTCLIENT
NFT_TABLES=(); SCAN_PATHS=(); ARGV=()

u8() {  # 十六进制码点 -> UTF-8 字节(与 locale 无关)，结果放 REPLY
  local c=$((16#$1)) s
  if   (( c < 0x80 ));    then printf -v s '\\x%02x' "$c"
  elif (( c < 0x800 ));   then printf -v s '\\x%02x\\x%02x' $((0xC0|c>>6)) $((0x80|c&0x3F))
  elif (( c < 0x10000 )); then printf -v s '\\x%02x\\x%02x\\x%02x' $((0xE0|c>>12)) $((0x80|((c>>6)&0x3F))) $((0x80|c&0x3F))
  else printf -v s '\\x%02x\\x%02x\\x%02x\\x%02x' $((0xF0|c>>18)) $((0x80|((c>>12)&0x3F))) $((0x80|((c>>6)&0x3F))) $((0x80|c&0x3F))
  fi
  printf -v REPLY "$s"
}

glyph() {
  if [[ -n ${ICONS[$1]-} ]]; then u8 "${ICONS[$1]}"
  elif [[ $1 =~ ^[0-9a-fA-F]{4,5}$ ]]; then u8 "$1"
  else REPLY=$1; fi
}

notify() { (( VPN_NOTIFY )) && command -v notify-send >/dev/null 2>&1 && notify-send -a polybar-vpn "$@"; }
now() { printf -v NOW '%(%s)T' -1; }
hash_str() {
  local s=$1 i c h=0
  for ((i=0; i<${#s}; i++)); do printf -v c '%d' "'${s:i:1}"; h=$(( (h*31 + c) & 0x7fffffff )); done
  REPLY=$h
}

if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
  read_cmdline() { ARGV=(); mapfile -d '' -t ARGV <"$1" 2>/dev/null; }
else
  read_cmdline() { ARGV=(); mapfile -t ARGV < <(tr '\0' '\n' <"$1" 2>/dev/null); }
fi

# ---- hysteria 配置解析 (v1 JSON / v2 YAML) -> P_SRV P_TP P_NAME P_ICON ----
probe_cfg() {
  P_SRV=""; P_TP=""; P_NAME=""; P_ICON=""
  [[ -r $1 ]] || return 1
  local line v w ws tp=0
  local re_srv='^[[:space:]]*"?server"?[[:space:]]*[:=][[:space:]]*(.+)$'
  local re_meta='^[[:space:]#/]*vpn:[[:space:]]*(.*)$'
  local re_tpk='"?((tcp|udp)[Tt][Pp]roxy|tproxy_(tcp|udp))"?[[:space:]]*:'
  local re_lis='"?listen"?[[:space:]]*:[[:space:]]*"?([^"[:space:],]*)'
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ $re_meta ]]; then
      read -ra ws <<<"${BASH_REMATCH[1]}"
      for w in "${ws[@]}"; do
        case ${w%%=*} in name) P_NAME=${w#*=};; icon) P_ICON=${w#*=};; esac
      done
    elif [[ -z $P_SRV && $line =~ $re_srv ]]; then
      v=${BASH_REMATCH[1]}; v=${v//[\"\']/}; v=${v%%,*}; v=${v%% *}
      v=${v#*://}; v=${v##*@}; v=${v%%/*}; v=${v%%\?*}
      P_SRV=$v
    fi
    if [[ $line =~ $re_tpk ]]; then tp=4
    elif (( tp > 0 )); then
      (( tp-- ))
      if [[ -z $P_TP && $line =~ $re_lis ]]; then v=${BASH_REMATCH[1]##*:}; [[ $v =~ ^[0-9]+$ ]] && P_TP=$v; fi
    fi
  done <"$1"
  return 0
}

srv_fmt() {  # 按 VPN_SHOW_SERVER 格式化 $1 -> REPLY
  local s=$1
  case $VPN_SHOW_SERVER in
    none) REPLY=""; return;;
    host) if [[ $s == \[*\]* ]]; then s=${s%%]*}; s=${s#[}; else s=${s%:*}; fi;;
  esac
  if (( ${#s} > VPN_SERVER_MAX )); then u8 2026; s="${s:0:VPN_SERVER_MAX-1}$REPLY"; fi
  REPLY=$s
}

# 名称/图标: 注释 > 配置文件名 > 服务器域名；图标: 注释 > 关键词 > 哈希
make_identity() {
  local base host toks t n
  SRV=${VPN_VPS:-$HY_SERVER}
  host=$SRV
  if [[ $host == \[*\]* ]]; then host=${host%%]*}; host=${host#[}; else host=${host%:*}; fi
  base=${HY_CFG##*/}; base=${base%.*}
  [[ $base =~ ^[0-9]+[-_.]+(.+)$ ]] && base=${BASH_REMATCH[1]}
  case ${base,,} in client|config|hysteria|hysteria2|"") base="";; esac

  if   [[ -n $VPN_NAME ]]; then NAME=$VPN_NAME
  elif [[ -n $HY_NAME  ]]; then NAME=${HY_NAME//_/ }
  else
    t=$base
    if [[ -z $t ]]; then
      if [[ $host =~ ^[0-9.]+$ || $host == *:* ]]; then t=$host; else t=${host%%.*}; fi
    fi
    NAME=${t^^}; NAME=${NAME:0:VPN_LABEL_MAX}
  fi
  [[ -n $NAME ]] || NAME=VPN

  ICON=${VPN_ICON:-$HY_ICON}
  if [[ -z $ICON ]]; then
    IFS='-_. ' read -ra toks <<<"${base,,} ${host,,}"
    for t in "${toks[@]}"; do
      [[ -n $t && -n ${AUTO_ICON[$t]+x} ]] && { ICON=${AUTO_ICON[$t]}; break; }
    done
  fi
  if [[ -z $ICON ]]; then
    if [[ -z $base$host ]]; then ICON=shield
    else hash_str "$base$host"; n=${#AUTO_POOL[@]}; ICON=${AUTO_POOL[REPLY % n]}; fi
  fi
}

# ---- hysteria 发现 ----
hy_refresh() {  # 重新读取 HY_CFG 内容并刷新显示信息
  if [[ -n $HY_CFG ]] && probe_cfg "$HY_CFG"; then
    HY_SERVER=$P_SRV; HY_TP=$P_TP; HY_NAME=$P_NAME; HY_ICON=$P_ICON
  fi
  make_identity
}
save_cache() { printf '%s\n%s\n%s\n' "$HY_CFG" "$HY_SERVER" "$HY_TP" >"$STATE_DIR/last" 2>/dev/null; }

hy_inspect() {  # $1=pid；是客户端进程返回0，并更新 HY_*
  local pid=$1 a prev="" sub="" cfg="" cwd="" x
  read_cmdline "/proc/$pid/cmdline"; (( ${#ARGV[@]} )) || return 1
  for a in "${ARGV[@]}"; do
    if [[ -n $prev ]]; then [[ $prev == -c || $prev == --config ]] && cfg=$a; prev=""; continue; fi
    case $a in
      -c|--config|-l|--log-level|--log-format) prev=$a;;
      --config=*|-c=*) cfg=${a#*=};;
      server|ping|speedtest|share|version|update|completion|help) [[ -z $sub ]] && sub=$a;;
      client) [[ -z $sub ]] && sub=client;;
    esac
  done
  [[ -z $sub || $sub == client ]] || return 1       # 排除 server/ping/speedtest 等
  if [[ -z $cfg ]]; then
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null)
    for x in config.yaml config.yml config.json; do
      [[ -n $cwd && -f $cwd/$x ]] && { cfg=$cwd/$x; break; }
    done
  elif [[ $cfg != /* ]]; then
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null); [[ -n $cwd ]] && cfg=$cwd/${cfg#./}
  fi
  [[ -n $cfg ]] || cfg=$HY_CFG
  HY_PID=$pid
  if [[ $cfg != "$HY_CFG" ]]; then HY_SERVER=""; HY_TP=""; HY_NAME=""; HY_ICON=""; fi
  HY_CFG=$cfg
  hy_refresh; save_cache
  [[ -n $VPN_BIN ]] || VPN_BIN=$(readlink "/proc/$pid/exe" 2>/dev/null)
  return 0
}

cfg_from_args() {  # "$@" 中的 -c/--config 值 -> REPLY
  local a prev=""
  REPLY=""
  for a in "$@"; do
    a=${a//[\"\']/}
    if [[ $prev == -c || $prev == --config ]]; then REPLY=$a; return 0; fi
    case $a in --config=*|-c=*) REPLY=${a#*=}; return 0;; esac
    prev=$a
  done
  return 1
}

service_cfg() {  # 未运行时，从 systemd 单元 / openrc 配置中找配置文件路径 -> REPLY
  local f d line w
  local -a files=() words=()
  local re_kv='^[[:space:]]*[A-Za-z_]*[Cc][Oo][Nn][Ff][A-Za-z_]*=["'\'']?([^"'\'' ]+\.(yaml|yml|json))'
  [[ -n $VPN_SERVICE ]] || return 1
  case $VPN_INIT in
    systemd) for d in /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system "$HOME/.config/systemd/user"; do
               files+=("$d/$VPN_SERVICE.service"); done;;
    openrc)  files=("/etc/init.d/$VPN_SERVICE" "/etc/conf.d/$VPN_SERVICE");;
    *) return 1;;
  esac
  for f in "${files[@]}"; do
    [[ -r $f ]] || continue
    while IFS= read -r line || [[ -n $line ]]; do
      [[ $line =~ ^[[:space:]]*# ]] && continue
      read -ra words <<<"$line"
      if cfg_from_args "${words[@]}" && [[ -n $REPLY && $REPLY != *%* && $REPLY != -* ]]; then return 0; fi
      if [[ $line =~ $re_kv ]]; then REPLY=${BASH_REMATCH[1]}; return 0; fi
    done <"$f"
  done
  REPLY=""; return 1
}

init_hy() {
  HY_PID=""; HY_CFG=""; HY_SERVER=""; HY_TP=""; HY_NAME=""; HY_ICON=""
  [[ -r $STATE_DIR/last ]] && { IFS= read -r HY_CFG; IFS= read -r HY_SERVER; IFS= read -r HY_TP; } <"$STATE_DIR/last"
  if [[ -z $HY_CFG ]] && service_cfg; then HY_CFG=$REPLY; fi
  hy_refresh
}

# ---- nft 脚本目录发现: 找含 tproxy 的规则 -> 表 / 端口 / mark / 来源文件 ----
nft_parse() {  # stdin=nft 文本; $1=来源标识
  local src=$1 line fam="" tbl="" port mark m2="" v t dup
  local -A defs=()
  local re_def='^[[:space:]]*define[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*([^[:space:]#]+)'
  local re_tbl='^[[:space:]]*(nft[[:space:]]+)?((add|create)[[:space:]]+)?table[[:space:]]+(ip6|ip|inet|arp|bridge|netdev)[[:space:]]+([A-Za-z0-9_.-]+)'
  local re_rule='^[[:space:]]*(nft[[:space:]]+)?(add|insert)[[:space:]]+(rule|chain)[[:space:]]+(ip6|ip|inet|arp|bridge|netdev)[[:space:]]+([A-Za-z0-9_.-]+)'
  local re_tp='(^|[^A-Za-z_])tproxy([^A-Za-z_]|$)'
  local re_port='[[:space:]]to[[:space:]]+[^[:space:]]*:([0-9]+|\$[A-Za-z_][A-Za-z0-9_]*)'
  local re_mark='mark[[:space:]]+(set[[:space:]]+)?(0x[0-9a-fA-F]+|[0-9]+|\$[A-Za-z_][A-Za-z0-9_]*)'
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*# ]] && continue
    if [[ $line =~ $re_def ]]; then defs[${BASH_REMATCH[1]}]=${BASH_REMATCH[2]}; continue; fi
    if   [[ $line =~ $re_tbl  ]]; then fam=${BASH_REMATCH[4]}; tbl=${BASH_REMATCH[5]}
    elif [[ $line =~ $re_rule ]]; then fam=${BASH_REMATCH[4]}; tbl=${BASH_REMATCH[5]}; fi
    if [[ -z $m2 && $line =~ $re_mark ]]; then m2=${BASH_REMATCH[2]}; fi
    [[ $line =~ $re_tp ]] || continue
    [[ $line =~ $re_port ]] || continue
    port=${BASH_REMATCH[1]}
    mark=""; [[ $line =~ $re_mark ]] && mark=${BASH_REMATCH[2]}
    [[ -n $tbl ]] || continue
    [[ $port == \$* ]] && port=${defs[${port#\$}]-}
    [[ $mark == \$* ]] && mark=${defs[${mark#\$}]-}
    [[ $port =~ ^[0-9]+$ ]] || continue
    dup=0; for t in "${NFT_TABLES[@]}"; do [[ $t == "$fam $tbl" ]] && dup=1; done
    (( dup )) || NFT_TABLES+=("$fam $tbl")
    [[ -n $NFT_PORT ]] || NFT_PORT=$port
    [[ -n $NFT_FILE ]] || NFT_FILE=$src
    if [[ -z $NFT_MARK && -n $mark ]]; then NFT_MARK=$mark; fi
  done
  if [[ -z $NFT_MARK && -n $m2 ]]; then
    [[ $m2 == \$* ]] && m2=${defs[${m2#\$}]-}
    NFT_MARK=$m2
  fi
  if [[ $NFT_MARK =~ ^(0x[0-9a-fA-F]+|[0-9]+)$ ]]; then
    if [[ $NFT_MARK == 0x* ]]; then v=$((NFT_MARK)); else v=$((10#$NFT_MARK)); fi
    printf -v NFT_MARK '0x%x' "$v"
  else NFT_MARK=""; fi
}

nft_scan() {
  NFT_TABLES=(); NFT_PORT=""; NFT_MARK=""; NFT_FILE=""; SCAN_PATHS=()
  local -a dirs gl
  local d f g
  IFS=: read -ra dirs <<<"$VPN_NFT_DIRS"
  read -ra gl <<<"$VPN_NFT_GLOB"
  for d in "${dirs[@]}"; do
    d=${d/#\~/$HOME}; d=${d%/}; [[ -n $d ]] || continue
    if [[ -f $d ]]; then
      SCAN_PATHS+=("$d"); [[ -r $d ]] && nft_parse "$d" <"$d"
    elif [[ -d $d ]]; then
      SCAN_PATHS+=("$d")
      for g in "${gl[@]}"; do
        for f in "$d"/$g; do
          [[ -f $f && -r $f ]] || continue
          SCAN_PATHS+=("$f"); nft_parse "$f" <"$f"
        done
      done
    fi
  done
  if (( ${#NFT_TABLES[@]} == 0 )) && [[ $NFT_MODE == priv ]]; then   # 兜底: 运行中的规则
    nft_parse "(live ruleset)" < <($NFT_PRIV nft list ruleset 2>/dev/null)
  fi
  [[ -n $OV_TABLE ]] && NFT_TABLES=("$OV_TABLE")
  return 0
}

eff() {  # 生效的 tproxy 端口 / mark: 手动覆盖 > hysteria 配置 > nft 脚本
  TP_PORT=${OV_PORT:-${HY_TP:-$NFT_PORT}}
  MARK=${OV_MARK:-${NFT_MARK:-0x1}}
  [[ $MARK =~ ^[0-9]+$ ]] && printf -v MARK '0x%x' "$((10#$MARK))"
  return 0
}

# ---- 环境探测（兼容多发行版 / 多 init）----
detect_env() {
  local d f n
  if [[ $VPN_INIT == auto ]]; then
    if   [[ -d /run/systemd/system ]]; then VPN_INIT=systemd
    elif [[ -d /run/openrc || -x /sbin/openrc-run || -x /usr/sbin/openrc-run ]]; then VPN_INIT=openrc
    else VPN_INIT=process; fi
  fi
  VPN_SERVICE_SCOPE=system
  if [[ $VPN_SERVICE == auto ]]; then
    VPN_SERVICE=""
    case $VPN_INIT in
      systemd)
        for d in /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system "$HOME/.config/systemd/user"; do
          for f in "$d"/hysteria*.service; do
            [[ -e $f ]] || continue
            n=${f##*/}; n=${n%.service}
            [[ $n == *@ || $n == *server* ]] && continue
            VPN_SERVICE=$n; [[ $d == "$HOME"/* ]] && VPN_SERVICE_SCOPE=user
            break 2
          done
        done;;
      openrc)
        for f in /etc/init.d/hysteria*; do
          [[ -x $f && $f != *server* ]] || continue
          VPN_SERVICE=${f##*/}; break
        done;;
    esac
  fi
  [[ $VPN_INIT == process ]] && VPN_SERVICE=""
  if [[ $VPN_BIN == auto ]]; then
    VPN_BIN=""
    for n in hysteria2 hysteria; do
      command -v "$n" >/dev/null 2>&1 && { VPN_BIN=$(command -v "$n"); break; }
    done
  fi
  # nft 检测权限: root / sudo -n / doas -n，否则退回 ip rule fwmark 检测
  NFT_PRIV=""; NFT_MODE=iprule
  if command -v nft >/dev/null 2>&1; then
    if (( EUID == 0 )); then NFT_MODE=priv
    elif command -v sudo >/dev/null 2>&1 && sudo -n nft list tables >/dev/null 2>&1; then NFT_MODE=priv; NFT_PRIV="sudo -n"
    elif command -v doas >/dev/null 2>&1 && doas -n nft list tables >/dev/null 2>&1; then NFT_MODE=priv; NFT_PRIV="doas -n"
    fi
  fi
  HAVE_IP=0; command -v ip >/dev/null 2>&1 && HAVE_IP=1
  HAVE_LISTEN=1
  if   command -v ss >/dev/null 2>&1;      then LISTEN_CMD="ss -H -lntu"
  elif command -v netstat >/dev/null 2>&1; then LISTEN_CMD="netstat -lntu"
  else LISTEN_CMD=""; HAVE_LISTEN=0; fi
}

init_theme() {
  local kv k v
  for kv in ${THEMES[$VPN_THEME]:-${THEMES[catppuccin]}}; do C[${kv%%=*}]=${kv#*=}; done
  for k in up down pending partial error text muted; do
    v=VPN_COLOR_${k^^}; [[ -n ${!v-} ]] && C[$k]=${!v}
  done
  u8 25cf; DOT=$REPLY
}

init_env() {
  if [[ -n ${XDG_RUNTIME_DIR-} ]]; then RUN=$XDG_RUNTIME_DIR/polybar-vpn; else RUN=/tmp/polybar-vpn-$UID; fi
  STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/polybar-vpn
  LOG=$RUN/hook.log
  mkdir -p -m 700 "$RUN" "$RUN/w" "$STATE_DIR"
  SELF=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "$0")
  SETSID=$(command -v setsid)
  OV_PORT=$VPN_TPROXY_PORT; OV_MARK=$VPN_TPROXY_MARK; OV_TABLE=$VPN_NFT_TABLE
  NFT_TS=0; NFT_CACHE=0
  detect_env; init_theme; nft_scan; init_hy
  : >"$RUN/scan.stamp"
}

maybe_reload() {  # 脚本目录/配置有变化才重新发现；全部 bash 内建判断，无 fork
  (( VPN_RESCAN )) || return 0
  local p
  for p in "${SCAN_PATHS[@]}" ${HY_CFG:+"$HY_CFG"}; do
    [[ -e $p && $p -nt $RUN/scan.stamp ]] || continue
    nft_scan; hy_refresh; NFT_TS=0; : >"$RUN/scan.stamp"; return 0
  done
}

# ---- 状态探测（尽量零 fork：/proc + 一次 ss）----
listening() { [[ $LISTEN =~ :$1[[:space:]] ]]; }

nft_probe() {
  local t
  if [[ -n $VPN_NFT_CHECK_CMD ]]; then bash -c "$VPN_NFT_CHECK_CMD" >/dev/null 2>&1; return; fi
  if [[ $NFT_MODE == priv ]]; then
    for t in "${NFT_TABLES[@]}"; do $NFT_PRIV nft list table $t >/dev/null 2>&1 || return 1; done
    return 0
  fi
  local r; r=$(ip rule show 2>/dev/null)
  [[ $r == *"fwmark $MARK "* || $r == *"fwmark $MARK/"* ]]
}

compute() {
  local f c d pid
  HY_PROC=0; DNS_PROC=0; LISTEN=""
  for f in /proc/[0-9]*/comm; do
    { read -r c <"$f"; } 2>/dev/null || continue
    case $c in
      hysteria*)
        (( HY_PROC )) && continue
        d=${f%/comm}; pid=${d#/proc/}
        [[ -n ${NOTCLIENT[$pid]+x} ]] && continue
        if [[ $pid == "$HY_PID" ]]; then HY_PROC=1
        elif hy_inspect "$pid"; then HY_PROC=1
        else NOTCLIENT[$pid]=1; fi;;
      dnsmasq) DNS_PROC=1;;
    esac
  done
  (( HY_PROC )) || HY_PID=""
  eff
  (( HAVE_LISTEN && (HY_PROC || DNS_PROC) )) && LISTEN=$($LISTEN_CMD 2>/dev/null)

  H=$HY_PROC
  (( VPN_CHECK_PORT && HAVE_LISTEN && HY_PROC )) && [[ -n $TP_PORT ]] && ! listening "$TP_PORT" && H=0

  T=-1
  if (( VPN_CHECK_NFT )) && { (( ${#NFT_TABLES[@]} )) || [[ -n $VPN_NFT_CHECK_CMD ]]; } \
     && { [[ $NFT_MODE == priv ]] || (( HAVE_IP )) || [[ -n $VPN_NFT_CHECK_CMD ]]; }; then
    now
    if (( NOW - NFT_TS >= VPN_NFT_TTL )); then nft_probe && NFT_CACHE=1 || NFT_CACHE=0; NFT_TS=$NOW; fi
    T=$NFT_CACHE
  fi
  D=-1
  if (( VPN_CHECK_DNS )); then
    D=0
    if (( DNS_PROC )); then (( HAVE_LISTEN )) && ! listening "$VPN_DNS_PORT" || D=1; fi
  fi

  local need=1 ok=$H
  (( T >= 0 )) && { need=$((need+1)); ok=$((ok+T)); }
  (( D >= 0 )) && { need=$((need+1)); ok=$((ok+D)); }
  if   (( ok == need ));          then RAW=up
  elif (( !HY_PROC && T != 1 ));  then RAW=down      # 仅 dnsmasq 在跑也算 down
  else RAW=partial; fi
}

resolve_state() {
  local rc=0 tgt ts
  STATE=$RAW
  [[ -r $RUN/rc ]] && read -r rc <"$RUN/rc"
  if [[ $RAW != up ]] && (( rc != 0 )); then STATE=error
  elif [[ $RAW == down && $VPN_INIT == systemd && -n $VPN_SERVICE ]]; then
    if [[ $VPN_SERVICE_SCOPE == user ]]; then systemctl --user is-failed --quiet "$VPN_SERVICE" 2>/dev/null && STATE=error
    else systemctl is-failed --quiet "$VPN_SERVICE" 2>/dev/null && STATE=error; fi
  fi
  if [[ -r $RUN/pending ]] && read -r tgt ts <"$RUN/pending"; then
    now
    if (( NOW - ts > VPN_PENDING_TIMEOUT )); then rm -f "$RUN/pending"
    else
      case $tgt in
        up)   if [[ $RAW == up ]];   then rm -f "$RUN/pending"; else STATE=pending; fi;;
        down) if [[ $RAW == down ]]; then rm -f "$RUN/pending"; else STATE=pending; fi;;
      esac
    fi
  fi
}

# ---- 渲染 ----
dot() {
  local col
  if (( $1 == 1 )); then col=${C[up]}; elif [[ $RAW == down ]]; then col=${C[down]}; else col=${C[error]}; fi
  dots+="${dots:+ }%{F$col}$DOT%{F-}"
}

render() {
  local c=${C[$STATE]:-${C[down]}} tc g fmt out ti="" te="" srv="" tp="" dots=""
  if [[ $VPN_ICON_MODE == text ]]; then g=${NAME:0:2}
  else
    glyph "$ICON"; g=$REPLY
    (( VPN_ICON_FONT > 0 )) && { ti="%{T$VPN_ICON_FONT}"; te="%{T-}"; }
  fi
  case $STATE in up|partial|pending) tc=${C[text]};; *) tc=${C[muted]};; esac
  srv_fmt "$SRV"; [[ -n $REPLY ]] && srv="%{F${C[muted]}}$REPLY%{F-}"
  [[ -n $TP_PORT ]] && tp="%{F${C[muted]}}:$TP_PORT%{F-}"
  dot "$H"; (( T >= 0 )) && dot "$T"; (( D >= 0 )) && dot "$D"

  local P_icon="$ti%{F$c}$g%{F-}$te"
  local P_name="%{F$tc}$NAME%{F-}"
  local P_state="%{F$c}${STATE_TXT[$STATE]}%{F-}"

  fmt=${VPN_FORMAT:-${FORMATS[$VPN_STYLE]:-${FORMATS[full]}}}
  out=${fmt//\{icon\}/$P_icon}
  out=${out//\{name\}/$P_name}
  out=${out//\{server\}/$srv}
  out=${out//\{tproxy\}/$tp}
  out=${out//\{state\}/$P_state}
  out=${out//\{dots\}/$dots}
  while [[ $out == *"  "* ]]; do out=${out//  / }; done
  out=${out# }; OUT=${out% }
}

refresh_state() { compute; resolve_state; render; }

# ---- hook ----
hook_cmd() {
  local v=VPN_HOOK_${1^^} c
  c=${!v-}
  [[ -z $c && -f $VPN_HOOK_DIR/$1 && -x $VPN_HOOK_DIR/$1 ]] && c=$VPN_HOOK_DIR/$1
  REPLY=$c
}

export_env() {
  eff
  local fam="" nm=""
  (( ${#NFT_TABLES[@]} )) && read -r fam nm <<<"${NFT_TABLES[0]}"
  export VPN_NODE=$NAME VPN_CONFIG=$HY_CFG VPN_SERVER=$SRV
  export VPN_INIT VPN_SERVICE VPN_SERVICE_SCOPE VPN_BIN VPN_DNS_PORT
  export VPN_NFT_FAMILY=$fam VPN_NFT_NAME=$nm VPN_NFT_TABLE=${fam:+$fam $nm} VPN_NFT_FILE=$NFT_FILE
  export VPN_TPROXY_PORT=$TP_PORT VPN_TPROXY_MARK=$MARK
}

exec_hook() { if [[ -f $1 && -x $1 ]]; then "$1"; else bash -c "$1"; fi; }

cmd_run() {  # 内部: 后台串行执行 hook，结果写入 $RUN/rc
  local h rc=0
  command -v flock >/dev/null 2>&1 && { exec 9>"$RUN/lock"; flock 9; }
  compute; export_env
  for h in "$@"; do
    hook_cmd "$h"
    [[ -n $REPLY ]] || { echo "hook '$h' undefined"; rc=127; break; }
    export VPN_ACTION=$h
    echo "[$(date +%T)] hook $h: $REPLY"
    exec_hook "$REPLY" 9>&-
    rc=$?
    (( rc == 0 )) || break
  done
  printf '%s\n' "$rc" >"$RUN/rc"
  if (( rc )); then rm -f "$RUN/pending"; notify -u critical "VPN" "hook '$h' failed (rc=$rc)"; fi
  cmd_refresh
}

dispatch() {  # dispatch <up|down> <hook...>
  local tgt=$1 h; shift
  for h in "$@"; do
    hook_cmd "$h"
    [[ -n $REPLY ]] || { notify -u critical "VPN" "hook '$h' not defined ($VPN_HOOK_DIR/$h)"; return 1; }
  done
  now; rm -f "$RUN/rc"
  printf '%s %s\n' "$tgt" "$NOW" >"$RUN/pending"
  ( ${SETSID:+setsid} "$SELF" _run "$@" </dev/null >>"$LOG" 2>&1 & )
  cmd_refresh
}

cmd_refresh() {  # 唤醒所有 watch 实例
  local f p
  for f in "$RUN"/w/*.fifo; do
    [[ -p $f ]] || continue
    p=${f##*/}; p=${p%.fifo}
    if kill -0 "$p" 2>/dev/null; then ( echo r >"$f" ) & else rm -f "$f"; fi
  done
}

cmd_toggle() {
  refresh_state
  [[ $STATE == pending ]] && return 0              # 切换中忽略重复点击
  case $RAW in up|partial) dispatch down down;; *) dispatch up up;; esac
}

cmd_info() {
  local ver="" t tbls="" x hu hd
  refresh_state
  [[ -n $VPN_BIN ]] && ver=$("$VPN_BIN" version 2>&1 | head -n 2 | tr '\n' ' ')
  for x in "${NFT_TABLES[@]}"; do tbls+="[$x] "; done
  hook_cmd up; hu=${REPLY:-MISSING}; hook_cmd down; hd=${REPLY:-MISSING}
  t="State   : $STATE (raw: $RAW)
Node    : $NAME  icon=$ICON
VPS     : ${SRV:-?}
Hysteria: pid=${HY_PID:--} proc=$HY_PROC  bin=${VPN_BIN:-not found} $ver
  config: ${HY_CFG:-not found}
  tproxy: port=${TP_PORT:-?} (config=${HY_TP:-?} nft=${NFT_PORT:-?}) listening-ok=$H
nft     : tables=${tbls:-none} mark=$MARK ok=$T mode=$NFT_MODE
  script: ${NFT_FILE:-none}
  dirs  : $VPN_NFT_DIRS
dnsmasq : proc=$DNS_PROC port:$VPN_DNS_PORT ok=$D
Init    : $VPN_INIT  service=${VPN_SERVICE:-none} ($VPN_SERVICE_SCOPE)
Hooks   : up=$hu  down=$hd
Env     : bash ${BASH_VERSION%%(*}  listen-cmd=${LISTEN_CMD:-none}  nft=$(command -v nft || echo no)  ip=$(command -v ip || echo no)"
  if [[ -t 1 ]]; then printf '%s\n' "$t"; else notify "VPN" "$t"; fi
}

fire_change() {  # 状态变化 -> on_change hook（多个 bar 实例只触发一次）
  local last=""
  [[ -r $RUN/last_state ]] && read -r last <"$RUN/last_state"
  [[ $last == "$STATE" ]] && return
  printf '%s\n' "$STATE" >"$RUN/last_state"
  [[ -n $last ]] || return
  hook_cmd on_change
  [[ -n $REPLY ]] || return
  local cmd=$REPLY
  ( export_env; export VPN_ACTION=on_change VPN_OLD_STATE=$last VPN_NEW_STATE=$STATE
    ${SETSID:+setsid} bash -c "$(declare -f exec_hook); exec_hook \"\$1\"" _ "$cmd" </dev/null >>"$LOG" 2>&1 & )
}

cmd_watch() {
  local fifo=$RUN/w/$$.fifo last="" iv FD MON=""
  mkfifo "$fifo" || exit 1
  exec {FD}<>"$fifo"
  cleanup() { [[ -n $MON ]] && kill "$MON" 2>/dev/null; rm -f "$fifo"; }
  trap cleanup EXIT; trap 'exit 0' INT TERM HUP
  # netlink 事件: 网卡/路由/策略路由变化即时唤醒(hook 增删 ip rule 立刻可见)，几乎零开销
  (( HAVE_IP )) && { ip -o monitor link route rule >&"$FD" 2>/dev/null & MON=$!; }
  while :; do
    maybe_reload
    refresh_state
    if [[ $OUT != "$last" ]]; then printf '%s\n' "$OUT"; last=$OUT; fi
    fire_change
    iv=$VPN_INTERVAL; [[ -e $RUN/pending ]] && iv=$VPN_FAST_INTERVAL
    if read -r -t "$iv" -u "$FD" _; then
      while read -r -t 0.25 -u "$FD" _; do :; done      # 去抖
    fi
  done
}

usage() { sed -n '2,/^[^#]/p' "$SELF" 2>/dev/null | sed '$d; s/^# \{0,1\}//'; }

main() {
  local cmd=${1:-watch}; shift 2>/dev/null
  init_env
  case $cmd in
    watch)   cmd_watch;;
    status)  refresh_state; printf '%s\n' "$OUT";;
    toggle)  cmd_toggle;;
    up)      refresh_state; dispatch up up;;
    down)    refresh_state; dispatch down down;;
    restart) refresh_state; dispatch up down up;;
    refresh) cmd_refresh;;
    info)    cmd_info;;
    _run)    cmd_run "$@";;
    *)       usage;;
  esac
}
main "$@"
