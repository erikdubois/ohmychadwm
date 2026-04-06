#!/bin/bash

make clean
make
sudo make install
make clean

pkill slstatus
sleep 1
slstatus &
