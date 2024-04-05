#!/usr/bin/env bash

###
# Extract audio from video using ffmpeg
# @since 2024.03.15
###

USAGE=$(cat << EOF
sh $0 source_dir output_dir
EOF
)


dir_src=$1
dir_dest=$2
dir_base=$(dirname $0)

if [ -z $dir_src ] || [ -z $dir_dest ]; then
    echo $USAGE
    exit 1
fi

IFS=$'\n'
for f in $(find $dir_src -type f)
do
    src_filename=$(basename $f)
    filename_without_suffic=${src_filename%.*}

    audio_fmt=$(ffmpeg -hide_banner -i $f 2>&1 | grep -i audio | sed -r 's/.+audio:\s*([^ ]+).+/\1/ig')

    output_path=$dir_dest/$src_filename.$audio_fmt

    echo "convert $f to format $audio_fmt"
    ffmpeg -hide_banner -i $f -vn -acodec copy $output_path 2>&1 > /dev/null

    if [ 0 -ne $? ]; then
        echo -e "Failt to convert $f"
        ffmpeg -hide_banner -i $f -vn -acodec copy $output_path 
        exit 1
    fi
done
