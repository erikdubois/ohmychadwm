#!/bin/bash

make clean
make
sudo make install
make clean

echo
tput setaf 2
echo "################################################################"
echo "We advise you to reboot your system and not logout"
echo "Some changes may also work with super + shift + r"
echo "################################################################"
tput sgr0
echo
