#!/bin/bash

apiurl=https://api.github.com/repos/Storj/dataserv-client

repository=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $apiurl)

repositoryurl=$(echo $repository | jq --raw-output ".html_url")
releasesurl=$(echo $repository | jq --raw-output ".releases_url")
releasesurl=${releasesurl//\{\/id\}/}
pullurl=$(echo $repository | jq --raw-output ".pulls_url")
pullurl=${pullurl//\{\/number\}/}

#get releases and pull requests from github
releases=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $releasesurl)
pulls=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $pullurl)

#generate github comments for pull request
for ((i=0; i < $(echo $pulls | jq ". | length"); i++)); do

    pullnumber=$(echo $pulls | jq --raw-output ".[$i].number")
    pullsha=$(echo $pulls | jq --raw-output ".[$i].merge_commit_sha")
    commenturl=$(echo $pulls | jq --raw-output ".[$i]._links.comments.href")
    comments=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $commenturl)
    autobincomment="[autobin](https://github.com/Storj/autobin) binaries (only available for team members)\r\nlast commit: $pullsha"

    waitforbinaries=false
    for ((j=0; j < $(echo $releases | jq ". | length"); j++)); do

        releasename=$(echo $releases | jq --raw-output ".[$j].name")

        if [ "$releasename" = "autobin pull request $pullnumber" ]; then

            for ((k=0; k < $(echo $releases | jq ".[$j].assets | length"); k++)); do

                assetlabel=$(echo $releases | jq --raw-output ".[$j].assets[$k].label")
                assetname=$(echo $releases | jq --raw-output ".[$j].assets[$k].name")
                downloadurl=$(echo $releases | jq --raw-output ".[$j].assets[$k].browser_download_url")

                if [ "${assetlabel:0:-10}" = "$pullsha" ]; then
                    autobincomment="$autobincomment\r\n[$assetname]($downloadurl)"

                    # calculate the time difference between binary upload and now
                    uploaddate=$(echo $releases | jq --raw-output ".[$j].assets[$k].updated_at")
                    uploaddate=$(date -d $uploaddate +%s)
                    datediff=$(($(date +%s)-uploaddate))
                    if [ "$datediff" -le  "300" ]; then
                        waitforbinaries=true
                    fi
                fi
            done
        fi
    done

    if [ "$(printf "$autobincomment" | wc -l)" -eq "3" ]; then
        # all binaries uploaded. no reason to wait
        waitforbinaries=false
    elif [ "$(printf "$autobincomment" | wc -l)" -eq "1" ]; then
        # no binaries uploaded. wait for it.
        waitforbinaries=true
    fi

    commentfound=false
    for ((l=0; l < $(echo $comments | jq ". | length"); l++)); do
        comment=$(echo $comments | jq ".[$l].body")
        if [ "$comment" = "\"$autobincomment\"" ]; then
            echo comment is up to date
            commentfound=true
        elif [ "$(printf "$comment" | head -1)" = "$(printf "\"$autobincomment\"" | head -1)" ]; then
            commenturl=$(echo $comments | jq --raw-output ".[$l].url")

            if [ "$(printf "$comment" | head -2)" = "$(printf "\"$autobincomment\"" | head -2)" ]; then
                echo update comment
                commentfound=true
                curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token $gh_token" -X PATCH -d "{\"body\":\"$autobincomment\"}" $commenturl
            else
                echo delete to old comment
                curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token $gh_token" -X DELETE $commenturl
            fi
        fi
    done

    if [ $commentfound = false ] && [ $waitforbinaries = false ]; then
        echo create a new comment
        commenturl=$(echo $pulls | jq --raw-output ".[$i]._links.comments.href")
        curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token $gh_token" -X POST -d "{\"body\":\"$autobincomment\"}" $commenturl
    fi
done

# delete release if pull request closed
for ((j=0; j < $(echo $releases | jq ". | length"); j++)); do

    releasename=$(echo $releases | jq --raw-output ".[$j].name")

    if [ "${releasename:0:21}" = "autobin pull request " ]; then
        pullnumber=${releasename:21}

        pullstate=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $pullurl/$pullnumber | jq --raw-output ".state")
        if [ "$pullstate" == "closed" ]; then
            releaseid=$(echo $releases | jq --raw-output ".[$j].id")
            curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token $gh_token" -X DELETE $releasesurl/$releaseid
        fi
    fi
done
