#!/usr/bin/env bash
#
script_dir=$(dirname $0)

## ~/.local/bin populate
dest_dir=~/.local/bin
src_dir=$(realpath $(pwd)/$script_dir/bin)

mkdir -p $dest_dir

ln -sv $src_dir/v2ray-wrapper.nft.sh $dest_dir/v2ray-nft 
ln -sv $src_dir/auto-rip $dest_dir/auto-rip
ln -sv $src_dir/container_as_cmd.sh $dest_dir/container_as_cmd 
ln -sv $src_dir/hdmi-hotplug.sh $dest_dir/
ln -sv $src_dir/i3-move-position.sh $dest_dir/
ln -sv $src_dir/i3-utils-cmd-term.sh $dest_dir/
ln -sv $src_dir/monitor-op.sh $dest_dir/monitor-op
ln -sv $src_dir/net-wrapper.sh $dest_dir/netrp
ln -sv $src_dir/tmuxpcmd.sh $dest_dir/tcmd
