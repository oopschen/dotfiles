#!/usr/bin/env bash

cmd=$1

cmd_fzf="$FZF_DEFAULT_COMMAND "

case $cmd in
    ## file search in directories, order by mtime desc
    fs )
        opt_dirs=
        for arg in "${@:2}"; do
            opt_dirs="$opt_dirs $arg "
        done

        if [ -z "$opt_dirs" ]; then
            opt_dirs="/tmp"
        fi

        for sel_file in "$($cmd_fzf --sortr modified $opt_dirs \
                | fzf --preview-window=top,20%,wrap  --preview \
                    'file -b {};ls -lh {};' \
            )";
        do
            if [ -z "$sel_file" ];then 
                break
            fi

            echo -e "[FZF-APPS]fs: open file $sel_file "
            #setsid -f xdg-open "$sel_file"
            setsid -f xdg-open "$sel_file"
        done
        ;;

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

#
