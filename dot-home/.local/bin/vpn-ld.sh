#!/usr/bin/env bash
#
# *IMPORTANT*
# 1. work with strongswan
# 2. change "/etc/strongswan.d/charon.conf"'s interfaces_use = eth0,wlan0

mode=$1
rcs="sudo rc-service"
vpn_name=vpn-ld
loop_max=6

function add_routes() {
    # wait for interface 
    while true
    do
        output=$(ip l | grep ppp | head -n 1 |  cut -d ':' -f 2 | tr -d ' ')
        if [ -z "$output" ]; then
            echo -e "retry($loop_i) check vpn interface is up?"
            sleep 1

            output=$(ip l | grep ppp | head -n 1 |  cut -d ':' -f 2 | tr -d ' ')
            loop_i=$(echo "$loop_i + 1" | bc)
            if [ $loop_max -ge $loop_i ]; then
                continue
            else
                exit 5
            fi
        fi

        break
    done

    # insert routes
    routes="192.168.70.0/24 192.168.254.0/24 10.88.0.0/16"
    for r in $routes
    do
        sudo ip r add $r dev $1
    done

}

case $mode in
    start)
        
        $rcs ipsec start
        $rcs xl2tpd start

        sleep 1
        sudo ipsec up $vpn_name > /dev/null
        ## check status
        loop_i=0
        while true
        do
            output_status=$(sudo ipsec status $vpn_name | grep -i $vpn_name | grep -i establi)
            if [ -z "$output_status" ]; then
                echo -e "retry($loop_i) ipsec up $vpn_name\n$output_status"
                sleep 1
                sudo ipsec up $vpn_name > /dev/null
                loop_i=$(echo "$loop_i + 1" | bc)
                if [ $loop_max -ge $loop_i ]; then
                    continue
                else
                    echo "ipsec tunnel up fails."
                    exit 1
                fi
            fi

            break
        done

        
        sudo xl2tpd-control connect-lac $vpn_name
        ## chcek xl2tpd connection status
        loop_i=0
        while true
        do
            output_ppp=$(ip a | grep ppp | grep inet)
            if [ -z "$output_ppp" ]; then
                sleep 1
                loop_i=$(echo "$loop_i + 1" | bc)
                if [ $loop_max -ge $loop_i ]; then
                    continue
                else
                    echo "xl2tpd connect lac fails."
                    exit 2
                fi
            fi

            break
        done


        ## insert routings
        interface_name=$(ip l | grep ppp | head -n 1 |  cut -d ':' -f 2 | tr -d ' ')
        add_routes $interface_name
        ip a

        ;;
    stop)
        sudo xl2tpd-control disconnect-lac $vpn_name
        sudo ipsec down $vpn_name
        $rcs xl2tpd stop
        $rcs ipsec stop 
        ;;
        
    route)
        interface_name=$(ip l | grep ppp | head -n 1 |  cut -d ':' -f 2 | tr -d ' ')
        add_routes $interface_name
        ;;

    *)
        echo "start | stop | route"
        ;;
esac
