#!/bin/bash
basedir=$(dirname $0)

name=ss-client

if [ ! -z "$(docker ps -aq -f "name=$name")" ]; then
  docker stop $name
  docker rm $name
fi

configfile=$(realpath ${1:-$basedir/.shadowsocks.json})
echo "using config $configfile"
docker run -d --name $name \
  -v $configfile:/etc/config/shadowsocks.json  -p 127.0.0.1:2480:2480 \
  -u root shadowsocks/shadowsocks-libev ss-redir \
  -u -c /etc/config/shadowsocks.json -f /tmp/shadownsocks.pid
