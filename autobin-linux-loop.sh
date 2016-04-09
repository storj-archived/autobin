#!/bin/bash

export gh_token=insert your token here

workdir="${pwd}"

#endless loop
while true; do

    clear
    cd "$workdir"
    bash dataserv-client/github-comment-bot.sh

    clear
    cd "$workdir"
    bash farmer-gui/github-comment-bot.sh

    clear
    cd "$workdir"
    bash storjnode/github-comment-bot.sh

    clear
    cd "$workdir"
    bash farmer-gui/build-linux-binary.sh

    sleep 600
done
