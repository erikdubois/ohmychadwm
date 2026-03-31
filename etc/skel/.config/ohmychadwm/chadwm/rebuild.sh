#!/bin/bash

make clean
make
sudo make install
make clean

echo
tput setaf 2
echo "################################################################"
echo "We advise you to reboot your system and not logout"
echo "################################################################"
tput sgr0
echo
