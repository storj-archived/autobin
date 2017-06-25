#!/bin/bash

#export GH_TOKEN=insert your token here

workdir="$(pwd)"

#endless loop
while true; do

    clear
    cd "$workdir"
    bash storjshare-gui/build-osx-binary.sh

    sleep 600
done
