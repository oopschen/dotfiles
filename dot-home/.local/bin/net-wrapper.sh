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
    servs="net.eth0 net.wlan0 dnsmasq hysteria-client"
    for srv in $servs
    do
      sudo rc-service $srv stop
    done
    hysteria2-wrapper.nft.sh D
    ;;

  v)
    sudo rc-service hysteria-client start
    hysteria2-wrapper.nft.sh T
    ;;

  *)
    echo -e "Usage:\n\tsh net-wrapper.sh w|e|v(vpn)|d"
    ;;
esac
