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

        for sel_file in $($cmd_fzf $opt_dirs --sortr modified | fzf);
        do
            echo -e "[FZF-APPS]fs: open file $sel_file"
            xdg-mime query filetype $sel_file
            xdg-open $sel_file
        done
        ;;

    ## app launcher
    apps )
        for sel_file in $($cmd_fzf /usr/share/applications ~/.local/share/applications \
            -g '**/*.desktop' | fzf);
        do
            echo -e "[FZF-APPS]fs: launch file $sel_file"
            setsid -f gtk-launch $(basename "$sel_file")
        done
        ;;
    * )
        echo -e "Usage sh $0 fs"
        ;;
esac
