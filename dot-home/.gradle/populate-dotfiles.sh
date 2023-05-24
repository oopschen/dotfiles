#!/usr/bin/env bash
#
script_dir=$(dirname $0)

## ~/.local/bin populate
dest_dir=~/.gradle
src_dir=$(realpath $(pwd)/$script_dir)

mkdir -p $dest_dir

ln -sv $src_dir/gradle.properties $dest_dir/
