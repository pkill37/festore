#!/bin/sh
set -e

workdir=$(pwd)

echo "Please insert the microSD card into the host computer now, and press ENTER..."
read _ 
rootfs_dir="/media/$USERNAME/rootfs"

sudo cp -v ./fekeystore/host/optee_fekeystore $rootfs_dir/usr/bin

chmod 444 ./fekeystore/ta/b7e89fc1-5044-431e-b4c5-9fb6ae256423.ta
sudo cp -v ./fekeystore/ta/b7e89fc1-5044-431e-b4c5-9fb6ae256423.ta $rootfs_dir/lib/optee_armtz

echo "Please unmount all partitions, remove the microSD card, put it back in the board and boot it up"
