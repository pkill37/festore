#!/bin/sh
set -e

workdir=$(pwd)

echo "Please insert the microSD card into the host computer now and enter the mount point of the rootfs: (e.g. /media/fabio/rootfs)"
read rootfs_dir

sudo cp -v ./fekeystore/host/optee_fekeystore $rootfs_dir/usr/bin
sudo cp -v ./fekeystore/ta/8aaaf200-2450-11e4-abe2-0002a5d5c51b.ta $rootfs_dir/lib/optee_armtz

echo "Please unmount all partitions, remove the microSD card, put it back in the board and boot it up"
