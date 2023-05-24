#!/usr/bin/env bash
freeMemBytes=$(free  | grep -i mem | sed 's/mem:\s\+[0-9]\+\s\+\([0-9]\+\).*/\1/ig')
# 100m
cmp=$(echo "$freeMemBytes < 102400 " | bc)

if [ "1" == "$cmp" ]; then
  echo "free memorying"
  sync && echo 3 > /proc/sys/vm/drop_caches
fi
