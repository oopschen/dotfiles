#!/usr/bin/env bash

if [ ! -z "$NETN" ]; then
  NETOPTS="--network $NETN"
fi

docker run --rm -it -v `mktemp`:/tim:ro \
  -v /etc/localtime:/etc/localtime:ro \
  -v $(pwd):/$(basename $(pwd)) -w /$(basename $(pwd)) \
  $NETOPTS $DNOPTS snode:8
