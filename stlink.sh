#!/bin/sh
set -ex

which picocom || sudo apt install -y picocom
mkdir -p logs || true

sudo picocom --flow soft --baud 115200 /dev/ttyACM0 --log ./logs/logs_$(date +%s).txt
