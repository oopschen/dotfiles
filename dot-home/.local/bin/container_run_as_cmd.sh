#!/usr/bin/env bash

## run container as commandline
##  sh script command_name command_args...

if [ 1 -gt $# ]; then
    echo "sh script command_name command_args..."
    exit 1
fi

cmd=$1

## remove 2
shift
args=$@

## container setups, --user $(id -u):$(id -g)
container_cmd=podman
runargs="--rm --userns=keep-id $EXTRA_RUN_ARGS "

## end

case $cmd in
    pandoc)
        $container_cmd run $runargs -v $(pwd):/data -v /tmp:/data/.tmp \
            docker.io/pandoc/extra:latest-alpine $args 
        exit $?
        ;;

    *)
        echo "command $cmd not found, please check."
        exit 99
        ;;


esac
