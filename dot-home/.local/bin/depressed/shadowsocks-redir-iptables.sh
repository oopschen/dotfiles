#!/bin/bash

if [ "$#" -lt 1 ]; then
	echo -e "mode: A add | D delete | T toggle temporary"
	exit 1
fi

cmd_iptables="sudo iptables"
cmd_ip="sudo ip"
basedir=$(dirname $0)
cfgfile=${2:-/etc/shadowsocks-libev/shadowsocks.json}
socksserver=$(grep '"server":' $cfgfile | sed -re 's/.*\s*:\s*"([^"]+)".*/\1/ig')
localport=$(grep 'local_port' $cfgfile | sed -re 's/.*:\s*([^, ]+).*/\1/ig')
echo -e "sever=$socksserver,localport=$localport,cfg=$cfgfile, udp_mode=$(test -z \"${USE_UDP}\" && 0)"



chainName=SSOCKS
mode=$1
case $mode in
	A)
	# create rules
	echo "create chain $chainName"
	$cmd_iptables -t nat -N $chainName

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

  # ignore ip in files
  ignoreFile=$(dirname "$cfgfile")/.shadowsocks-redir-ignore
  echo "check ignore file: $ignoreFile"
  if [ -f "$ignoreFile" ]; then
    echo "ignoring ips:  $(wc -l $ignoreFile)"
    for line in $(cat $ignoreFile)
    do
      $cmd_iptables -t nat -A $chainName -d $line -j RETURN
    done
  fi

	# redirect to local port
	echo "chain $chainName: redirect all tcp"
	$cmd_iptables -t nat -A $chainName -p tcp -j REDIRECT --to-ports $localport

	# Apply the rules
	echo "chain $chainName: apply rules"
	# for desktop
	$cmd_iptables -t nat -A OUTPUT -p tcp -j $chainName
	echo "Done......"

	;;

	D)
	echo "chain $chainName: flush chains"
	$cmd_iptables -t nat -F $chainName

	echo "chain $chainName: delete chains"
	$cmd_iptables -t nat -D OUTPUT -p tcp -j $chainName

	$cmd_iptables -t nat -X $chainName
	echo "Done......"

	;;

	T)
		inText=$($cmd_iptables -t nat -L OUTPUT -n| grep $chainName)
		msg=
		if [ -z "$inText" ]; then
			$cmd_iptables -t nat -A OUTPUT -p tcp -j $chainName
			msg=UP
		else
			$cmd_iptables -t nat -D OUTPUT -p tcp -j $chainName
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

	*)
	echo -e "mode: A add | D delete"
	;;
esac
