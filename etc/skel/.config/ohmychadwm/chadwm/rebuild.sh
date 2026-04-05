#!/bin/bash

make clean
make
sudo make install
make clean

echo
read -rp "Do you want to reboot? [y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    systemctl reboot
fi
