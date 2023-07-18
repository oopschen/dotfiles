#!/usr/bin/env bash
#
if [ 1 -gt $# ]; then
    echo -e "sh $(basename $0) mode.\n\tmode value: v2ray"
    exit 1
fi

typ=$1

case $typ in
    v2ray)
        st_v2ray=$(pgrep -x v2ray)
        st_dns=$(pgrep -x dnsmasq)
        st_nft=$(v2ray-nft S | grep -iE "\bon\b")
        if [ ! -z "$st_v2ray" ] && [ ! -z "$st_dns" ] && [ ! -z "$st_nft" ]; then
            echo -e "%{F#63F3CF}\uf205%{F-}"
            exit 0
        fi
        ;;

esac

echo -e "%{F#A54242}\uf204%{F-}"
