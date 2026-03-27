#!/bin/bash

make clean
make
sudo make install
make clean

echo
tput setaf 2
echo "################################################################"
echo "Launch st"
echo "################################################################"
tput sgr0
echo
