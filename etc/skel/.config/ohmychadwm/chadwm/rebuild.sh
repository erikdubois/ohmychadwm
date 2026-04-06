#!/bin/bash

make clean
make
sudo make install
make clean

echo
read -rp "Do you want to reboot? [Y/n] " answer
if [[ "${answer:-Y}" =~ ^[Yy]$ ]]; then
    systemctl reboot
fi
