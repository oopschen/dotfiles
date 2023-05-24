#!/usr/bin/env bash
sharedir=$(realpath ~/share)
diskdir=$(realpath ~/vm/win10-c.qcow2)

cpufeaturesintel="pcid spec-ctrl stibp ssbd pdpe1gb md-clear mds-no taa-no tsx-ctrl"

existedcpufeatures=""
for f in $cpufeaturesintel
do
  finfo=$(grep "$f" /proc/cpuinfo)
  if [ ! -z "$finfo" ]; then
    existedcpufeatures="$existedcpufeatures,+$f"
  fi
done

cpuinfo="Skylake-Client-noTSX-IBRS"

# sound card
#-soundhw hda \
qemu-system-x86_64 --enable-kvm --name win10 -m 6G -machine pc,accel=kvm \
  -drive file=${diskdir},format=qcow2,index=1,media=disk \
  -nic user,ipv6=off,smb=${sharedir}  -boot c \
  -display sdl -vga std \
  -device qemu-xhci \
  -device usb-host,vendorid=0x05ac,productid=0x12a8 \
  -device usb-host,vendorid=0x1ff7,productid=0x0200 \
  -device usb-host,vendorid=0x05ac,productid=0x12a8 \
  -cpu $cpuinfo$existedcpufeatures -smp sockets=1,cores=3,threads=2 \
  -object memory-backend-ram,size=6G,id=m0 \
  -numa node,nodeid=0,memdev=m0 -numa cpu,node-id=0 \
  $@

# iphone 8
# wzga tou ping
