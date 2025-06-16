#!/usr/bin/env bash

opt=$1

case $opt in
  w)
    sudo rc-service net.eth0 stop
    servs="net.wlan0 dnsmasq"
    for srv in $servs
    do
      sudo rc-service $srv restart
    done
  ;;

  e)
    sudo rc-service net.wlan0 stop
    servs="net.eth0 dnsmasq"
    for srv in $servs
    do
      sudo rc-service $srv restart
    done
  ;;

  d)
    servs="net.eth0 net.wlan0 dnsmasq"
    for srv in $servs
    do
      sudo rc-service $srv stop
    done
    ;;

  v)
    if [[ -z "$(sudo rc-service hysteria-client status | grep -iE 'status.+started')" ]]; then
        echo -e "no proxy client service found and restart it"
        sudo rc-service hysteria-client restart
    fi

    if [[ "1" -gt "$(pgrep -fc hysteria | bc)" ]]; then
        echo -e "no proxy client proc found and restart it"
        sudo rc-service hysteria-client restart
    fi

    hysteria2-wrapper.nft.sh T
    ;;

  *)
    echo -e "Usage:\n\tsh net-wrapper.sh w(wlan)|e(eth)|v(vpn toggle)|d(down)"
    ;;
esac
