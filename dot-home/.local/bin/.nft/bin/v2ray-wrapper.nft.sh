#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo -e "mode: A add | D delete | T toggle temporary | S status | I init"
	exit 1
fi

mode=$1

cmd_table="sudo nft"
cmd_ip="sudo ip"

ignore_file=~/.config/.v2ray.ignore.ip
v2ray_config_file=/etc/nftables.d/v2ray.nft.conf
policy_routing_table_name=166

nft_table=$(grep -Ei "add\s+table" $v2ray_config_file | head -n1 | cut -d ' ' -f 3 | tr -d ' ')
nft_ipv4_set_whitelist_set_name=$(grep -Ei "add\s+set\s+ip\s+$nft_table\s+" $v2ray_config_file | tail -n1 | cut -d ' ' -f 5 | tr -d ' ')
v2rayserver=$(grep -Ei "define\s+ipv4_v2r_server" $v2ray_config_file | cut -d '=' -f 2 | tr -d ' ')
localport=$(grep -Ei "define\s+int_tproxy_port" $v2ray_config_file | cut -d '=' -f 2 | tr -d ' ')
packet_mark=$(grep -Ei "define\s+int_tproxy_mark" $v2ray_config_file | cut -d '=' -f 2 | tr -d ' ')

# function definition
function generate_uniq_rand() {
    num=$1
    res=""
    for r in $(shuf -i 0-15 -n $num)
    do
        res="$res$(printf '%x' $r)"
    done

    echo $res
}

## n non-exists, y exists
function has_ip_whitelist() {
    table_name=$1
    set_name=$2
    $cmd_table get element ip $1 $2 "{ $v2rayserver }" > /dev/null 2>&1
    if [ 0 -eq $? ]; then
        echo "y"
    else
        echo "n"
    fi
}

function create_or_swap_ip_whitelist() {
    ignore_file=$1
    temp_nft_conf_file=/tmp/.v2ray-ignore.$(generate_uniq_rand 6).nft.conf
    ## generate ip whitelist file
    cat << EOF > $temp_nft_conf_file 
#!/sbin/nft -f 
# auto generatedby $0 script, please do not change this file.
EOF

    if [ -f "$ignore_file" ]; then
        echo "ignore ips from file[$(wc -l $ignore_file | cut -d " " -f 1)]: $ignore_file"
        for line in $(cat $ignore_file)
        do
            echo "add element ip $nft_table $nft_ipv4_set_whitelist_set_name { $line }" \
                >> $temp_nft_conf_file
        done
    else
        echo "no ignored ips file found !!!"
        exit 1
    fi

    # clean ip whitelist settings
    if [ "y" == "$(has_ip_whitelist \"$nft_table\" \"$nft_ipv4_set_whitelist_set_name\")" ];then
        echo "clean ignore ips"
        $cmd_table flush set ip $nft_table $nft_ipv4_set_whitelist_set_name
        $cmd_table delete set ip $nft_table $nft_ipv4_set_whitelist_set_name
    fi

    # init ip whitelist set
    $cmd_table -f $temp_nft_conf_file
}

function create_v2ray() {
    res=0
    ### 1. init nftable setting
    if [ ! -f "$v2ray_config_file" ]; then
        echo "No \"$v2ray_config_file\" found!!!"
        res=1
    fi

    $cmd_table -f $v2ray_config_file

    if [ 0 -eq $? ]; then
        echo "V2ray VPN init main..."
    else
        echo "V2ray VPN fail to init main(error code = $?)..."
        res=2
    fi

    ### 2. init ignore ip set
    create_or_swap_ip_whitelist $ignore_file

    if [ 0 -eq $? ]; then
        echo "V2ray VPN init ignore-ip..."
    else
        echo "V2ray VPN fail to init ignore-ip(error code = $?)..."
        res=3
    fi

    ### 3. policy routing setting
    has_rpdb=$($cmd_ip rule show fwmark $((packet_mark)) table $policy_routing_table_name)
    if [ -z "$has_rpdb" ]; then
        $cmd_ip rule add fwmark $((packet_mark)) table $policy_routing_table_name
        if [ 0 -eq $? ]; then
            echo "V2ray VPN init policy routing..."
        else
            echo "V2ray VPN fail to init policy routing(error code = $?)..."
            res=4
        fi
    else
        echo "V2ray VPN policy routing is on($has_rpdb)..."
    fi

    has_rpdb_route=$($cmd_ip route show type local 0.0.0.0/0 dev lo table $policy_routing_table_name)
    if [ -z "$has_rpdb_route" ]; then
        $cmd_ip route add local 0.0.0.0/0 dev lo table $policy_routing_table_name
        if [ 0 -eq $? ]; then
            echo "V2ray VPN init routing..."
        else
            echo "V2ray VPN fail to init routing(error code = $?)..."
            res=5
        fi

    else
        echo "V2ray VPN routing is on($has_rpdb_route)..."
    fi

    ## 4. check final result value
    if [ 0 -eq $res ]; then
        echo "V2ray VPN on..."
    fi

    return $res
}

function destroy_v2ray() {
    res=0
    $cmd_table -f ${v2ray_config_file}.destroy

    if [ 0 -eq $? ]; then
        echo "V2ray VPN off..."
    else
        echo "V2ray VPN off fail(error code = $?)..."
        res=1
    fi

    $cmd_ip rule del fwmark $((packet_mark)) table $policy_routing_table_name
    if [ 0 -eq $? ]; then
        echo "V2ray VPN delete policy routing..."
    else
        echo "V2ray VPN fail to delete policy routing(error code = $?)..."
        res=2
    fi

    $cmd_ip route del local 0.0.0.0/0 dev lo table $policy_routing_table_name
    if [ 0 -eq $? ]; then
        echo "V2ray VPN delete routing..."
    else
        echo "V2ray VPN fail to delete routing(error code = $?)..."
        res=3
    fi

    return $res
}


# main proccess
echo -e "Estab sever=$v2rayserver,localport=$localport by mark $packet_mark($((packet_mark))) in $nft_table ignored by set named$nft_ipv4_set_whitelist_set_name"

case $mode in
	A)
		has_table=$($cmd_table list tables ip| grep $nft_table)
		if [ ! -z "$has_table" ]; then
			echo "V2ray is on..."
            exit
		fi

        create_v2ray
        exit $?
	;;

	D)
        destroy_v2ray
        exit $?
	;;

	T)
		has_table=$($cmd_table list tables ip| grep $nft_table)
        st=
		if [ ! -z "$has_table" ]; then
			echo "V2ray is on..."
            st="off"
            destroy_v2ray
		else
			echo "V2ray is off..."
            st="on"
            create_v2ray
		fi

        if [ 0 -eq $? ]; then
			echo "V2ray turns to $st..."
        else
            echo "V2ray fails to turn to $st (error code = $?)..."
            exit 1
        fi
	;;

	S)
		has_table=$($cmd_table list tables ip| grep $nft_table)
		if [ ! -z "$has_table" ]; then
			echo "V2ray Status is on..."
		else
			echo "V2ray Status is off..."
            exit 1
		fi
	;;

    I)
        create_or_swap_ip_whitelist $ignore_file

        if [ 0 -eq $? ]; then
            echo "V2ray ignore ip updated..."
        else
            echo "V2ray ignore ip updating fail(error code = $?)..."
            exit 1
        fi
  ;;

    *)
        echo -e "mode: A add | D delete | S status | T toggle | I update iip"
	;;
esac
