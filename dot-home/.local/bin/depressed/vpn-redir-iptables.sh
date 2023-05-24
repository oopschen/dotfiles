#!/bin/bash
# @Depressed by nftable
# @Since 2023/05/08

if [ "$#" -lt 1 ]; then
	echo -e "mode: A add server:port | D delete | T toggle temporary | S status | I init server:port"
	exit 1
fi

cmd_iptables="sudo iptables"
cmd_ip="sudo ip"
cmd_ipset="sudo ipset"
socksserver=${2%:*}
localport=${2#*:}
ipset_name="vpncnipset"

echo -e "sever=$socksserver,localport=$localport"

# 0 non-exists, 1 exists
function has_ipset() {
  $cmd_ipset list $1 > /dev/null 2>&1
  if [ 0 -eq $? ]; then
    echo "y"
  else
    echo "n"
  fi
}

function create_or_swap_ipset() {
  ipset_tname=${ipset_name}_t
  if [ "y" == "$(has_ipset $ipset_tname)" ];then
    echo "delete existed temporary ipset name: $ipset_tname"
    $cmd_ipset destroy $ipset_tname
  fi
  $cmd_ipset create $ipset_tname hash:net hashsize 16384

  # ignore private ips
  echo "add internal private ips and server ips"
  $cmd_ipset add $ipset_tname $socksserver
	$cmd_ipset add $ipset_tname 0.0.0.0/8
	$cmd_ipset add $ipset_tname 10.0.0.0/8
	$cmd_ipset add $ipset_tname 127.0.0.0/8
	$cmd_ipset add $ipset_tname 169.254.0.0/16
	$cmd_ipset add $ipset_tname 172.16.0.0/12
	$cmd_ipset add $ipset_tname 192.168.0.0/16
	$cmd_ipset add $ipset_tname 224.0.0.0/4
	$cmd_ipset add $ipset_tname 240.0.0.0/4

  # ignore ip in files
  ignoreFile=~/.config/.shadowsocks-redir-ignore
  echo "add ips from ignore file: $ignoreFile"
  if [ -f "$ignoreFile" ]; then
    echo "ignoring ips:  $(wc -l $ignoreFile)"
    for line in $(cat $ignoreFile)
    do
      $cmd_ipset add $ipset_tname $line
    done
  fi

  # swap ip
  if [ "y" == "$(has_ipset $ipset_name)" ];then
    echo "swap ipset"
    $cmd_ipset swap $ipset_tname $ipset_name
    $cmd_ipset destroy $ipset_tname
  else
    echo "create ipset"
    $cmd_ipset rename $ipset_tname $ipset_name
  fi
}

chainName=VPNCNCHAIN
mode=$1

case $mode in
	A)
  if [ "n" == "$(has_ipset $ipset_name)" ]; then
    echo "ipset $ipset_name not found"
    exit 1
  fi

	# ignore ip in ipset and redirect all tcp to vpn
	$cmd_iptables -t nat -N $chainName
	$cmd_iptables -t nat -A $chainName -m set --match-set $ipset_name dst -j RETURN
	$cmd_iptables -t nat -A $chainName -p tcp -j REDIRECT --to-ports $localport
	$cmd_iptables -t nat -A OUTPUT -p tcp -j $chainName

  # udp
	$cmd_iptables -t mangle -N $chainName
	$cmd_iptables -t mangle -N ${chainName}_MASK

  $cmd_iptables -t mangle -A $chainName -p udp \
    -m set --match-set $ipset_name dst --dport 53 -j ACCEPT
  $cmd_iptables -t mangle -A ${chainName}_MASK -p udp \
    -m set --match-set $ipset_name dst --dport 53 -j ACCEPT

  $cmd_ip route add local default dev lo table 100
  $cmd_ip rule add fwmark 1 lookup 100

  $cmd_iptables -t mangle -A $chainName -p udp --dport 53 \
    -j TPROXY --on-port $localport --tproxy-mark 0x01/0x01
  $cmd_iptables -t mangle -A ${chainName}_MASK -p udp --dport 53 -j MARK --set-mark 1
  $cmd_iptables -t mangle -A PREROUTING -j $chainName
  $cmd_iptables -t mangle -A OUTPUT -j ${chainName}_MASK
	echo "Done......"
	;;

	D)
  $cmd_ip route del local default dev lo table 100
  $cmd_ip rule del fwmark 1 lookup 100

	$cmd_iptables -t nat -D OUTPUT -p tcp -j $chainName
	$cmd_iptables -t nat -F $chainName
	$cmd_iptables -t nat -X $chainName

  $cmd_iptables -t mangle -D PREROUTING -j $chainName
	$cmd_iptables -t mangle -F $chainName
	$cmd_iptables -t mangle -X $chainName

  $cmd_iptables -t mangle -D OUTPUT -j ${chainName}_MASK
	$cmd_iptables -t mangle -F ${chainName}_MASK
	$cmd_iptables -t mangle -X ${chainName}_MASK

	echo "Done......"

	;;

	T)
		inText=$($cmd_iptables -t nat -L OUTPUT -n| grep $chainName)
		msg=
		if [ -z "$inText" ]; then
      $cmd_iptables -t nat -A OUTPUT -p tcp -j $chainName
      $cmd_iptables -t mangle -A PREROUTING -j $chainName
      $cmd_iptables -t mangle -A OUTPUT -j ${chainName}_MASK
			msg=UP
		else
      $cmd_iptables -t nat -D OUTPUT -p tcp -j $chainName
      $cmd_iptables -t mangle -D PREROUTING -j $chainName
      $cmd_iptables -t mangle -D OUTPUT -j ${chainName}_MASK
			msg=DOWN
		fi
		echo "$msg Done......"
	;;

	S)
		inText=$($cmd_iptables -t nat -L OUTPUT -n| grep $chainName)
		if [ -z "$inText" ]; then
			echo "Status Done..."
		else
			echo "Status UP..."
		fi
	;;

  I)
    create_or_swap_ipset
    echo "Done"
  ;;

	*)
	echo -e "mode: A add | D delete | S status | T toggle"
	;;
esac
