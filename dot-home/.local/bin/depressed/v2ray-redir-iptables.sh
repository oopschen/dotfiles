#!/bin/bash
# @Depressed by nftable
# @Since 2023/05/08

if [ "$#" -lt 1 ]; then
	echo -e "mode: A add | D delete | T toggle temporary"
	exit 1
fi

function delete_chain_by_num() {
  for n in $($cmd_iptables -t $1 -L $2 --line-number | grep $3 | cut -d ' ' -f 1)
  do
    $cmd_iptables -t $1 -D $2 $n
  done
}

function disable_redir() {
	echo "chain $chainName: disable"
  delete_chain_by_num nat OUTPUT $chainName
  delete_chain_by_num mangle PREROUTING $chainName
  delete_chain_by_num mangle OUTPUT ${chainName}_MASK
}

function enable_redir() {
	echo "chain $chainName: enable"
	$cmd_iptables -t nat -A OUTPUT -p tcp -j $chainName
  $cmd_iptables -t mangle -A PREROUTING -j $chainName
  $cmd_iptables -t mangle -A OUTPUT -j ${chainName}_MASK
}

cmd_iptables="sudo iptables"
cmd_ip="sudo ip"
basedir=$(dirname $0)
socksserver=45.136.185.61
localport=1280
dnsIgnoreIP="114.114.114.114,115.115.115.115,223.6.6.6,223.5.5.5,127.0.0.1"
echo -e "server=$socksserver,localport=$localport"

chainName=V2RAY
mode=$1
case $mode in
	A)
	# create rules
	echo "create chain $chainName"
	$cmd_iptables -t nat -N $chainName
	$cmd_iptables -t mangle -N $chainName
	$cmd_iptables -t mangle -N ${chainName}_MASK

	# Ignore your $chainName server's addresses
	echo "chain $chainName: ignore socks server: $socksserver"
	$cmd_iptables -t nat -A $chainName -d $socksserver -j RETURN

	# Ignore lan
	echo "chain $chainName: ignore LAN"
	$cmd_iptables -t nat -A $chainName -d 0.0.0.0/8 -j RETURN
	$cmd_iptables -t nat -A $chainName -d 10.0.0.0/8 -j RETURN
	$cmd_iptables -t nat -A $chainName -d 127.0.0.0/8 -j RETURN
	$cmd_iptables -t nat -A $chainName -d 169.254.0.0/16 -j RETURN
	$cmd_iptables -t nat -A $chainName -d 172.16.0.0/12 -j RETURN
	$cmd_iptables -t nat -A $chainName -d 192.168.0.0/16 -j RETURN
	$cmd_iptables -t nat -A $chainName -d 224.0.0.0/4 -j RETURN
	$cmd_iptables -t nat -A $chainName -d 240.0.0.0/4 -j RETURN
  ## udp
  $cmd_iptables -t mangle -A $chainName -p udp -d $dnsIgnoreIP --dport 53 -j ACCEPT
  $cmd_iptables -t mangle -A ${chainName}_MASK -p udp -d $dnsIgnoreIP --dport 53 -j ACCEPT

  # ignore ip in files
  ignoreFile=~/.config/.shadowsocks-redir-ignore
  echo "check ignore file: $ignoreFile"
  if [ -f "$ignoreFile" ]; then
    echo "ignoring ips:  $(wc -l $ignoreFile)"
    for line in $(cat $ignoreFile)
    do
      $cmd_iptables -t nat -A $chainName -d $line -j RETURN
    done
  fi

	# Apply the rules
	echo "chain $chainName: apply rules"
  ## tcp
	$cmd_iptables -t nat -A $chainName -p tcp -j REDIRECT --to-ports $localport

  ## udp
  $cmd_ip route add local default dev lo table 100
  $cmd_ip rule add fwmark 1 lookup 100

  $cmd_iptables -t mangle -A $chainName -p udp --dport 53 \
    -j TPROXY --on-port $localport --tproxy-mark 0x01/0x01
  $cmd_iptables -t mangle -A ${chainName}_MASK -p udp --dport 53 -j MARK --set-mark 1

	# for desktop
  enable_redir
	echo "Done......"

	;;

	D)
  disable_redir

  $cmd_ip route del local default dev lo table 100
  $cmd_ip rule del fwmark 1 lookup 100
	echo "Done......"

	;;

	T)
		inText=$($cmd_iptables -t nat -L OUTPUT| grep $chainName)
		msg=
		if [ -z "$inText" ]; then
      enable_redir
			msg=UP
		else
      disable_redir
			msg=DOWN
		fi
		echo "$msg done......"
	;;

	S)
		inText=$($cmd_iptables -t nat -L OUTPUT| grep $chainName)
		if [ -z "$inText" ]; then
			echo "Status Down..."
		else
			echo "Status UP..."
		fi
	;;

	*)
	echo -e "mode: A add | D delete"
	;;
esac
