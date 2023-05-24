#!/usr/bin/env bash

fromdir=$1
workdir=$fromdir/.scel2dict.fcitx5.work
destdir=~/.local/share/fcitx5/pinyin/dictionaries

function clean_up () {
    echo "clean up work dir: $workdir"
    rm -rf $workdir
}

mkdir -p $workdir

for f in $(find "$fromdir" -type f -iname "*.scel")
do
    bname=$(basename $f)
    temp_text_file=$workdir/${bname%.scel}.txt
    scel2org5 $f -o $temp_text_file
    if [ 0 -ne $? ];then
        echo "convert scel to text fail($?)"
        clean_up
        exit 1
    fi


    libime_pinyindict $temp_text_file $destdir/${bname%.scel}.dict
    if [ 0 -ne $? ];then
        echo "convert text to dict fail($?)"
        clean_up
        exit 1
    fi

    echo "convert sec2dict success: $f"
done

clean_up
