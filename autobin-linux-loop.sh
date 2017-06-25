#!/bin/bash

#export GH_TOKEN=insert your token here

workdir="$(pwd)"

#endless loop
while true; do

    clear
    cd "$workdir"
    bash storjshare-gui/build-linux-binary.sh

    if [ "$(dpkg --print-architecture)" = "amd64" ]; then
        clear
        cd "$workdir"
        bash storjshare-gui/github-comment-bot.sh
    fi

    sleep 600
done
