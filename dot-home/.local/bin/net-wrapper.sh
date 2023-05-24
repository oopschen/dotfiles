#!/usr/bin/env bash

opt=$1

case $opt in
  w)
    sudo rc-service net.eth0 stop
    servs="net.wlan0 v2ray dnsmasq"
    for srv in $servs
    do
      sudo rc-service $srv restart
    done
  ;;

  e)
    sudo rc-service net.wlan0 stop
    servs="net.eth0 v2ray dnsmasq"
    for srv in $servs
    do
      sudo rc-service $srv restart
    done
  ;;

  *)
    echo -e "Usage:\n\tsh net-wrapper.sh w|e"
  ;;
esac
