#!/usr/bin/env bash

### 用于tmux 操作的指南

if [ $# -lt 1 ];then
  echo -e "sh script command ..."
  exit 1
fi

case $1 in
  ssh)
    shift 1
    r=$(date +%H-%M-%S)
    sname=ssh
    echo "args $*"
    tmux has -t $sname || tmux new -ds $sname
    tmux switchc -t $sname: \; \
      neww -t $sname: -n rofi$r $* \; \
      selectw -t $sname:rofi$r
    ;;
esac
