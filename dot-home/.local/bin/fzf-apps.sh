#!/usr/bin/env bash

cmd=$1

cmd_fzf="$FZF_DEFAULT_COMMAND "

case $cmd in
    ## app launcher
    apps )
        sel_lc=${LANG%%.*}
        IFS=$'\n'

        for sel_file in "$(rg -L --no-heading -m 1 -i  -g '*.desktop' \
            "name=|comment=|name[$sel_lc]=|comment[$sel_lc]=" \
                /usr/share/applications ~/.local/share/applications \
                | fzf -d ':'  --preview-window=top,25% --nth=2 --preview \
                \\"grep -iE 'name=|comment=|name[$sel_lc]=|comment[$sel_lc]=' {1}\\" \
        )";
        do
            f=${sel_file%%:*}
            echo -e "[FZF-APPS]fs: Select $f" 
            setsid -f gtk-launch $(basename "$f")
        done
        ;;
    * )
        echo -e "Usage sh $0 fs"
        ;;
esac

