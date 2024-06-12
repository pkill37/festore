#!/bin/sh
set -ex

if [ ! -d /media/$USERNAME/rootfs ]; then
	exit 1
fi

sudo cp -v ./festore/host/optee_festore /media/$USERNAME/rootfs/usr/bin

chmod 444 ./festore/ta/b7e89fc1-5044-431e-b4c5-9fb6ae256423.ta
sudo cp -v ./festore/ta/b7e89fc1-5044-431e-b4c5-9fb6ae256423.ta /media/$USERNAME/rootfs/lib/optee_armtz

umount /media/$USERNAME/rootfs
umount /media/$USERNAME/userfs
umount /media/$USERNAME/vendorfs
umount /media/$USERNAME/bootfs
