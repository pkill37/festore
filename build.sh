#!/bin/sh
set -ex

workdir=$(pwd)
. ./Developer-Package/SDK/environment-setup-cortexa7t2hf-neon-vfpv4-ostl-linux-gnueabi

cd ./festore
make clean
make
tree
