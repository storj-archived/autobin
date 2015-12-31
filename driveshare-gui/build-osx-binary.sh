#!/bin/bash

#set some variables
gh_token=insert your token here
apiurl=https://api.github.com/repos/Storj/driveshare-gui

repository=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $apiurl)

repositoryname=$(echo $repository | jq --raw-output ".name")
repositoryurl=$(echo $repository | jq --raw-output ".html_url")
releasesurl=$(echo $repository | jq --raw-output ".releases_url")
releasesurl=${releasesurl//\{\/id\}/}
pullurl=$(echo $repository | jq --raw-output ".pulls_url")
pullurl=${pullurl//\{\/number\}/}

#endless loop
while true; do
    clear

    #get releases and pull requests from github
    releases=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $releasesurl)
    pulls=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $pullurl)

    #build binary for pull request
    for ((i=0; i < $(echo $pulls | jq ". | length"); i++)); do

        pullnumber=$(echo $pulls | jq --raw-output ".[$i].number")
        pullsha=$(echo $pulls | jq --raw-output ".[$i].merge_commit_sha")
        pullrepository=$(echo $pulls | jq --raw-output ".[$i].head.repo.html_url")
        pullbranch=$(echo $pulls | jq --raw-output ".[$i].head.ref")
        commenturl=$(echo $pulls | jq --raw-output ".[$i]._links.comments.href")

        releasefound=false
        assetfound=false

        for ((j=0; j < $(echo $releases | jq ". | length"); j++)); do

            releasename=$(echo $releases | jq --raw-output ".[$j].name")

            if [ "$releasename" = "autobin pull request $pullnumber" ]; then

                releasefound=true

                uploadurl=$(echo $releases | jq --raw-output ".[$j].upload_url")
                uploadurl=${uploadurl//\{?name,label\}/}

                for ((k=0; k < $(echo $releases | jq ".[$j].assets | length"); k++)); do

                    assetlabel=$(echo $releases | jq --raw-output ".[$j].assets[$k].label")

                    if [ "$assetlabel" = "$pullsha.dmg" ]; then
                        assetfound=true
                    fi
                done
            fi
        done

        if [ $releasefound = false ]; then
            echo create release autobin pull request $pullnumber
            uploadurl=$(curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token $gh_token" -X POST -d "{\"tag_name\":\"\",\"name\":\"autobin pull request $pullnumber\",\"draft\":true}" $releasesurl | jq --raw-output ".upload_url")
            uploadurl=${uploadurl//\{?name,label\}/}
        fi

        if [ $assetfound = false ]; then

            rm -rf $repositoryname

            echo $pullrepository
            echo create and upload binary $pullrepository $pullbranch
            git clone $pullrepository -b $pullbranch
            cd $repositoryname
            npm install
            npm run release
            cd releases

            filename=$(ls)
            for ((j=0; j < $(echo $releases | jq ". | length"); j++)); do
                for ((k=0; k < $(echo $releases | jq ".[$j].assets | length"); k++)); do

                    assetname=$(echo $releases | jq --raw-output ".[$j].assets[$k].name")

                    if [ "$assetname" = "$filename" ]; then
                        asseturl=$(echo $releases | jq --raw-output ".[$j].assets[$k].url")
                        curl -X DELETE -H "Authorization: token $gh_token" $asseturl
                    fi
                done
            done

            downloadurl=$(curl -H "Accept: application/json" -H "Content-Type: application/octet-stream" -H "Authorization: token $gh_token" --data-binary "@$filename" "$uploadurl?name=$filename&label=$pullsha.dmg" | jq --raw-output ".browser_download_url")
            echo curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token $gh_token" -X POST -d "{\"body\":\"autobin binary \(only available for team members\): [$filename]\($downloadurl\) sha: $pullsha.dmg\"}" $commenturl
            curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token $gh_token" -X POST -d "{\"body\":\"autobin binary (only available for team members): [$filename]($downloadurl) sha: $pullsha.dmg\"}" $commenturl
        fi
    done

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

        if [ "$releasename" = "autobin draft release" ]; then
            assetfound=false
            for ((k=0; k < $(echo $releases | jq ".[$j].assets | length"); k++)); do

                assetname=$(echo $releases | jq --raw-output ".[$j].assets[$k].name")

                if [ "${assetname: -4}" = ".dmg" ]; then
                    assetfound=true
                fi
            done

            if [ $assetfound = false ]; then

                uploadurl=$(echo $releases | jq --raw-output ".[$j].upload_url")
                uploadurl=${uploadurl//\{?name,label\}/}

                rm -rf $repositoryname

                targetbranch=$(echo $releases | jq --raw-output ".[$j].target_commitish")
                targettag=$(echo $releases | jq --raw-output ".[$j].tag_name")
                if [ "$targettag" != "null" ]; then
                    targetbranch=$targettag
                fi

                echo create and upload binary $repositoryurl $targetbranch
                git clone $repositoryurl -b $targetbranch
                cd $repositoryname
                npm install
                npm run release
                cd releases

                filename=$(ls)
                curl -H "Accept: application/json" -H "Content-Type: application/octet-stream" -H "Authorization: token $gh_token" --data-binary "@$filename" "$uploadurl?name=$filename"
                cd ../..
            fi
        fi
    done
    sleep 60
done
