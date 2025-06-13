#!/usr/bin/env bash

destfile=/home/work/.config/.proxy-ip.ignore
tmpdestfile=/tmp/$(basename "$destfile").tmp
downloadfile=/tmp/.apnic-lastest
timeouts_sec=300

curl -L --connect-timeout $timeouts_sec -m $timeouts_sec \
    -o $downloadfile "http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest"

if [ 0 -ne $? ] || [ 0 -eq $(wc -l $downloadfile | cut -d ' ' -f 1) ]; then
  echo "Download latest apnic fail"
  exit 1
fi

ripquerier -i $downloadfile -t ipv4 -s allocated -s assigned -c HK -c CN \
  | tail -n +5 > $tmpdestfile

if [ 0 -eq $(wc -l $tmpdestfile | cut -d ' ' -f 1) ]; then
    echo "No entry found."
    exit 2
fi

mv $tmpdestfile $destfile
