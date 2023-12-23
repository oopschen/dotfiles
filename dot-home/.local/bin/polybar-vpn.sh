#!/usr/bin/env bash
#
prefix_output="%{T2}%{F#63F3CF}󰖂 %{F-}%{T-}"
output=""

function check_v2ray() {
    st_v2ray=$(pgrep -x v2ray)
    st_dns=$(pgrep -x dnsmasq)
    st_nft=$(v2ray-nft S | grep -iE "\bon\b")
    st_nft_server=$(v2ray-nft S | grep -i server | sed -r 's/.+server=([^,]+).+/\1/ig')
    if [ ! -z "$st_v2ray" ] && [ ! -z "$st_dns" ] && [ ! -z "$st_nft" ]; then
        echo -e "%{T1}%{F#F0C674}$st_nft_server(V2R)%{F-}%{T-}"
    else
        echo ""
    fi
}

function check_ld_vpn() {
    # check ipsec
    st_ipsec_server=$(sudo ipsec status | grep -i "===" | cut -d "="  -f 4 | sed -r 's/\s+([^/]+).+/\1/ig')
    st_xl2tp=$(ps -ef | grep xl2tpd)
    st_ppt_interface=$(ip l | grep ppp | head -n 1 |  cut -d ':' -f 2 | tr -d ' ')
    if [ ! -z "$st_ipsec_server" ] && [ ! -z "$st_xl2tp" ] && [ ! -z "$st_ppt_interface" ]; then
        echo -e "%{T1}%{F#F0C674}$st_ipsec_server(LD)%{F-}%{T-}"
    else
        echo ""
    fi
}

## call functions
output=$(check_v2ray)
if [ ! -z "$output" ]; then
    output="$output $(check_ld_vpn)"
else
    output="$(check_ld_vpn)"
fi


if [ -z "$output" ]; then
    echo -e "\n"
else
    echo -e "$prefix_output $output"
fi
