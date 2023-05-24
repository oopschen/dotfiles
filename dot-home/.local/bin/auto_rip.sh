#!/usr/bin/env bash

destfile=/home/work/.config/.shadowsocks-redir-ignore
downloadfile=/tmp/apnic-lastest

curl -L -o $downloadfile "http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest"

if [ 0 -ne $? ]; then
  echo "Download latest apnic fail"
  exit 1
fi

ripquerier -i $downloadfile -t ipv4 -s allocated -s assigned -c HK -c CN \
  | tail -n +5 > $destfile

# update ipset
sudo ipset save > /tmp/.rule-save
