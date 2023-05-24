#!/usr/bin/env bash

if [ 1 -gt $# ]; then
  echo -e "Usage: \n\trunApp command line"
  exit 1
fi

hashVal=$(echo "$@-$(date +%Y%m%d%H%M%S)" | sha1sum -t)
nohup $@ > /tmp/runApp${1//\//-}-${hashVal:0:10}.out 2>&1 &
