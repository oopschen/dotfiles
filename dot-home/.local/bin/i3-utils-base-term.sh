#!/usr/bin/env bash

nohup st -f \
    'FiraCode Nerd Font:style=Regular:pixelsize=15:antialias=true:hinting:true' $@ \
    2>&1 1>/dev/null &
