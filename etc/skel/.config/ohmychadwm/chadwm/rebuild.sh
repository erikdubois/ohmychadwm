#!/bin/bash

make clean
make
make install
make clean

## xdotool key super+shift+r

echo
tput setaf 2
echo "################################################################"
echo "Press super + shift + r to reload your new Chadwm build"
echo "################################################################"
tput sgr0
echo
