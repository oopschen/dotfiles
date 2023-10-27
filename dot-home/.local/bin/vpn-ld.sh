#!/usr/bin/env bash

mode=$1
rcs="sudo rc-service"

case $mode in
    start)
        $rcs ipsec start
        $rcs xl2tpd start
        sudo ipsec up vpn-ld
        sudo xl2tpd-control connect-lac vpn-ld
        sleep 5

        routes="192.168.70.0/24 192.168.254.0/24"
        interface_name=$(ip l | grep ppp | head -n 1 |  cut -d ':' -f 2 | tr -d ' ')
        for r in $routes
        do
            sudo ip r add $r dev $interface_name
        done

        ;;
    stop)
        sudo xl2tpd-control disconnect-lac vpn-ld
        sudo ipsec down vpn-ld
        $rcs xl2tpd stop
        $rcs ipsec stop 
        ;;

    *)
        echo "start | stop"
        ;;
esac
