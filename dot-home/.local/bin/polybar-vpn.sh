#!/usr/bin/env bash
#
output=

function check_v2ray() {
    ## TODO fIX
    st_v2ray=$(pgrep -x v2ray)
    st_dns=$(pgrep -x dnsmasq)
    st_nft=$(v2ray-nft S | grep -iE "\bon\b")
    st_nft_server=$(v2ray-nft S | grep -i server | sed -r 's/.+server=([^,]+).+/\1/ig')
    if [ ! -z "$st_v2ray" ] && [ ! -z "$st_dns" ] && [ ! -z "$st_nft" ]; then
        echo -e "%{T3}%{F#F0C674}$st_nft_server(V2R)%{F-}%{T-}"
    else
        echo ""
    fi
}

###
# 1. check nft tables
# 2. check ip route
###
function check_tproxy_hysteria2() {
    proxy_mark=$1
    table_id=$2
    nft_table_name=$3

    fwmark_rule=$(ip rule | grep "fwmark")
    has_target_mark=$(echo "$fwmark_rule" | grep -iE "\b$proxy_mark\b")
    has_target_table=$(echo "$fwmark_rule" | grep -iE "\b$table_id\b")
    has_nft_table=$(sudo nft list tables | grep -iE "$nft_table_name")

    if [ ! -z "$fwmark_rule" ] && [ ! -z "$has_target_mark" ] \
        && [ ! -z "$has_target_table" ] \
        && [ ! -z "$has_nft_table" ]; then
        echo "0"
        return
    fi

    echo "1"
}

function check_proxy_serv_hyseteria2() {
    if [[ -z "$(sudo rc-service hysteria-client status | grep -iE 'status.+started')" ]]; then
        echo 1
        return
    fi

    echo 0
}

function check_tproxy_hysteria2_main() {
    ## service off
    color="63F3CF"
    if [[  "0" != "$(check_proxy_serv_hyseteria2)" ]]; then
        color="FF2171"
    elif [[  "0" != $(check_tproxy_hysteria2 "0x67" "102" "tbl_hysteria") ]]; then
    ## tproxy off
        color="FFCA03"
    fi

    echo -e "%{T3}%{F#$color}\uf135%{F-}%{T-}"
}

## call functions
output="$output $(check_tproxy_hysteria2_main)"

if [ -z "$output" ]; then
    echo -e "%{T3}%{F#FF2171}\uf135%{F-}%{T-}"
else
    echo -e "$output"
fi
