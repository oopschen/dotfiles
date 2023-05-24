#!/bin/bash

# place this file at /lib64/elogind/system-sleep, must have execute permission

WHEN="$1"
WHAT="$2"

if [[ ! -f /usr/bin/nvidia-sleep.sh ]]; then
  exit 0
fi

if [[ "xpre" = "x$WHEN" ]]; then
  if [[ "xsuspend" = "x$WHAT" ]]; then
    /usr/bin/logger -t "$WHAT" -s "nvidia-sleep.sh $WHEN"
    /usr/bin/nvidia-sleep.sh "suspend"
  else
    /usr/bin/logger -t "$WHAT" -s "nvidia-sleep.sh $WHEN"
    /usr/bin/nvidia-sleep.sh "hibernate"
  fi
elif [[ "xpost" = "x$WHEN" ]]; then
  sleep 1
  /usr/bin/logger -t "$WHAT" -s "nvidia-sleep.sh $WHEN"
  /usr/bin/nvidia-sleep.sh "resume" &
fi

exit 0
