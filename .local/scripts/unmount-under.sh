#!/bin/sh

# Unmount all datasets under input

dataset_parent=$1

for dataset in `zfs list -H -o name | grep ${dataset_parent}`; do 
  mounted=`zfs get -H -o value mounted ${dataset}`
  #echo "${dataset} mounted: ${mounted}"
  if [ "${mounted}" = "yes" ]; then
    zfs umount ${dataset}
  fi
done
