#!/usr/bin/env bash

### copy file into volumes to ease volume initialization
### Usage:
###     script

# DV_SRC DV_VOLNAME
srcDir=${DV_SRC:=/tmp/docker-vol-init-src}
absDestDir=/mnt
volumeName=${DV_VOLNAME:=docker-vol-init}
srcDirMappingName=/media/dest-$(echo $RANDOM | tr -d '\n')

if [ ! -d $(realpath $srcDir) ]; then
  echo "source directory '${srcDir}' not found"
  exit 1
fi

if [ ! -z "$(docker volume ls | grep ${volumeName})" ]; then
  read -p "delete exists volume $volumeName[Y/N]" deleteFlag
  case "$deleteFlag" in
    y|Y)
      docker volume rm $volumeName > /dev/null 2>&1
      ;;
    *)
      echo "volume $volumeName exists"
      exit 1
  esac
fi

docker run --rm -v "$volumeName:$absDestDir" \
  -v "$(realpath $srcDir):$srcDirMappingName" alpine cp -pr $srcDirMappingName/. $absDestDir
if [ 0 -eq $? ]; then
  echo "initialization succeed"
else
  echo "initialization failes"
fi
