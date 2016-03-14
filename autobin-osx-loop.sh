#!/bin/bash

export gh_token=insert your token here

workdir="${pwd}"

#endless loop
while true; do

    clear
    cd "$workdir"
    bash driveshare-gui/build-osx-binary.sh

    clear
    cd "$workdir"
    bash storjnode/build-osx-binary.sh

    clear
    cd "$workdir"
    bash dataserv-client/build-osx-binary.sh

    sleep 600
done
