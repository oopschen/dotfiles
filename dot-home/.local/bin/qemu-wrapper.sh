#!/usr/bin/env bash
# 通过 QMP(HMP 透传) 向运行中的 QEMU guest 热插拔宿主机 USB 设备
#
# 环境变量:
#   QMP_SERVER    QMP unix socket 路径 (默认 /tmp/qmp-shell.sock)
#   QEMU_USB_BUS  guest 内 USB 总线, 例如 xhci.0 (可选, 不设则用默认总线)

qmp_sock=${QMP_SERVER:-/tmp/qmp-shell.sock}
usb_bus=${QEMU_USB_BUS:-}

usage() {
    cat <<EOF
Usage: $0 <command>
Commands:
    usb-p   passthrough usb device to vm
    usb-d   del usb device from vm
Environment:
    QMP_SERVER    QMP unix socket (default: /tmp/qmp-shell.sock)
    QEMU_USB_BUS  guest usb bus for usb-p, e.g. xhci.0 (optional)
EOF
}

die() {
    local code=$1
    shift
    echo "$*" >&2
    exit "$code"
}

## 执行一条 HMP 命令, 输出清理过的结果 (去 \r、提示符、banner、空行)
## arg1: HMP command
hmp() {
    printf '%s\n' "$1" | qmp-shell -H "$qmp_sock" 2>&1 \
        | tr -d '\r' \
        | sed -E 's/^\(QEMU\) *//' \
        | grep -vE '^(Welcome to the QMP|Connected to|$)'
}

## 列出宿主机 USB 设备, 每行: bus|port|vid|pid|name
list_host_usb() {
    # info usbhost 输出格式:
    #   Bus 4, Addr 20, Port 1.1.3, Speed 5000 Mb/s
    #     Class 00: USB device 0951:1666, DataTraveler 3.0
    hmp "info usbhost" | awk '
        /Bus [0-9]+, Addr [0-9]+, Port / {
            bus = $0;  sub(/^.*Bus /,  "", bus);  sub(/,.*$/, "", bus)
            port = $0; sub(/^.*Port /, "", port); sub(/,.*$/, "", port)
            next
        }
        /USB device [0-9a-fA-F]+:[0-9a-fA-F]+/ {
            rest = $0; sub(/^.*USB device /, "", rest)
            ids = rest; sub(/,.*$/, "", ids); gsub(/[ \t]/, "", ids)
            name = ""
            if (index(rest, ",") > 0) {
                name = substr(rest, index(rest, ",") + 1)
                sub(/^[ \t]+/, "", name)
            }
            split(ids, a, ":")
            if (tolower(a[1]) == "1d6b") next   # 跳过 root hub
            printf "%s|%s|%s|%s|%s\n", bus, port, a[1], a[2], name
        }' | sort -t '|' -k5,5f
}

## 列出 guest 内带 id 的 USB 设备, 每行: id|product
list_guest_usb() {
    # info usb 输出格式:
    #   Device 0.1, Port 1, Speed 480 Mb/s, Product QEMU USB Tablet, ID: tablet
    hmp "info usb" \
        | sed -nE 's/^.*Product (.*), ID: *([^ ]+) *$/\2|\1/p' \
        | sort -t '|' -k2,2f
}

## 让用户从 $@ 中选一项, 结果放在全局变量 CHOSEN_INDEX (1-based)
choose_index() {
    local count=$1 idx
    read -r -p "Please input device number: " idx
    if ! [[ $idx =~ ^[0-9]+$ ]] || ((10#$idx < 1 || 10#$idx > count)); then
        die 1 "No device chosen."
    fi
    CHOSEN_INDEX=$((10#$idx))
}

## 宿主机上该 USB 设备若有已挂载的分区, 给出警告 (透传前应先卸载)
## arg1: bus  arg2: port
warn_if_mounted() {
    local blkpath blk
    for blkpath in /sys/bus/usb/devices/"$1"-"$2"/*/host*/target*/*/block/*; do
        [ -e "$blkpath" ] || continue
        blk=${blkpath##*/}
        if awk -v b="/dev/$blk" '$1 ~ "^" b "(p?[0-9]+)?$" { f = 1 } END { exit !f }' /proc/mounts; then
            echo "Warning: /dev/$blk (or its partitions) is mounted on the host, umount it first." >&2
        fi
    done
}

usb_passthrough() {
    local -a devs
    mapfile -t devs < <(list_host_usb)
    ((${#devs[@]} > 0)) || die 1 "No host usb device found."

    local i=0 line bus port vid pid name
    echo "Host usb devices:"
    for line in "${devs[@]}"; do
        IFS='|' read -r bus port vid pid name <<<"$line"
        i=$((i + 1))
        printf '\t%d. %s [%s:%s] (bus %s, port %s)\n' \
            "$i" "${name:-unnamed}" "$vid" "$pid" "$bus" "$port"
    done

    choose_index "${#devs[@]}"
    IFS='|' read -r bus port vid pid name <<<"${devs[CHOSEN_INDEX - 1]}"

    warn_if_mounted "$bus" "$port"

    local dev_id
    dev_id="usb-${vid}-${pid}-$(printf '%04d' $((RANDOM % 10000)))"

    # 用 bus+port 精确定位物理端口, 同时带上 vid/pid 防止端口上换了别的设备
    local cmd="device_add driver=usb-host,id=${dev_id},hostbus=${bus},hostport=${port},vendorid=0x${vid},productid=0x${pid}"
    if [ -n "$usb_bus" ]; then
        cmd+=",bus=${usb_bus}"
    fi

    echo "Add device: name=${name:-unnamed}, vendor-product=${vid}:${pid}, bus=${bus}, port=${port}, device-id=${dev_id}"
    local res
    res=$(hmp "$cmd")
    if [ -n "$res" ]; then
        echo "$res" >&2
        exit 1
    fi
    echo "Done."
}

usb_delete() {
    local -a devs
    mapfile -t devs < <(list_guest_usb)
    ((${#devs[@]} > 0)) || {
        echo "No usb device found"
        exit 0
    }

    local i=0 line id product
    echo "VM usb devices:"
    for line in "${devs[@]}"; do
        IFS='|' read -r id product <<<"$line"
        i=$((i + 1))
        printf '\t%d. %s (id: %s)\n' "$i" "$product" "$id"
    done

    choose_index "${#devs[@]}"
    IFS='|' read -r id product <<<"${devs[CHOSEN_INDEX - 1]}"

    echo "Delete device: ${product} (id: ${id})"
    local res
    res=$(hmp "device_del ${id}")
    if [ -n "$res" ]; then
        echo "$res" >&2
        exit 1
    fi
    echo "Done."
}

cmd=${1:-}
case $cmd in
    usb-p | usb-d) ;;
    *)
        usage
        exit 1
        ;;
esac

command -v qmp-shell >/dev/null 2>&1 || die 101 "qmp-shell not found in PATH"
[ -S "$qmp_sock" ] || die 100 "QMP sock path not found: $qmp_sock"

case $cmd in
    usb-p) usb_passthrough ;;
    usb-d) usb_delete ;;
esac
