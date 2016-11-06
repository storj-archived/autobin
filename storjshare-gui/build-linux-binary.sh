#!/bin/bash

apiurl=https://api.github.com/repos/Storj/storjshare-gui

repository=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $apiurl)

repositoryname=$(echo $repository | jq --raw-output ".name")
repositoryurl=$(echo $repository | jq --raw-output ".html_url")
releasesurl=$(echo $repository | jq --raw-output ".releases_url")
releasesurl=${releasesurl//\{\/id\}/}
pullurl=$(echo $repository | jq --raw-output ".pulls_url")
pullurl=${pullurl//\{\/number\}/}
tagurl=$(echo $repository | jq --raw-output ".tags_url")

#get releases and pull requests from github
releases=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $releasesurl)
pulls=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $pullurl)
tags=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $tagurl)

for ((j=0; j < $(echo $releases | jq ". | length"); j++)); do

    releasename=$(echo $releases | jq --raw-output ".[$j].name")

    if [ "$releasename" = "autobin draft release" ]; then
        assetfound=false
        asseturl=$(echo $releases | jq --raw-output ".[$j].assets_url")
        assets=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $asseturl)
        for ((k=0; k < $(echo $assets | jq ". | length"); k++)); do

            assetname=$(echo $assets | jq --raw-output ".[$k].name")

            if [ "${assetname: -4}" = ".deb" ]; then
                assetstate=$(echo $assets | jq --raw-output ".[$k].state")
                if [ "$assetstate" = "new" ]; then
                    binaryurl=$(echo $assets | jq --raw-output ".[$k].url")
                    curl -X DELETE -H "Authorization: token $gh_token" $binaryurl
                else
                    assetfound=true
                fi
            fi
        done

        if [ $assetfound = false ]; then

            uploadurl=$(echo $releases | jq --raw-output ".[$j].upload_url")
            uploadurl=${uploadurl//\{?name,label\}/}

            # existing build tag or branch
            targetbranch=$(echo $releases | jq --raw-output ".[$j].target_commitish")
            targettag=$(echo $releases | jq --raw-output ".[$j].tag_name")
            if [ "$targettag" != "null" ]; then
                for ((l=0; l < $(echo $tags | jq ". | length"); l++)); do
                    tag=$(echo $tags | jq --raw-output ".[$l].name")
                    if [ "$targettag" = "$tag" ]; then
                        targetbranch=$targettag
                    fi 
                done
            fi
                
            mkdir repos
            cd repos

            rm -rf $repositoryname

            echo create and upload binary $repositoryurl $targetbranch
            git clone $repositoryurl -b $targetbranch $repositoryname
            cd $repositoryname

            # run script as root
            #npm install --unsafe-perm
            #npm run release --unsafe-perm

            # run script as normal user
            npm install
            npm run release
            cd releases

            filename=$(ls)
            curl -H "Accept: application/json" -H "Content-Type: application/octet-stream" -H "Authorization: token $gh_token" --data-binary "@$filename" "$uploadurl?name=$filename"
        fi
    fi
done

#build binary for pull request
for ((i=0; i < $(echo $pulls | jq ". | length"); i++)); do

    pullnumber=$(echo $pulls | jq --raw-output ".[$i].number")
    pullsha=$(echo $pulls | jq --raw-output ".[$i].merge_commit_sha")
    pullrepository=$(echo $pulls | jq --raw-output ".[$i].head.repo.html_url")
    pullbranch=$(echo $pulls | jq --raw-output ".[$i].head.ref")

    rem refresh github releases (3 build script are running at the same time. Only one should create the new pull request release.)
    releases=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $releasesurl)

    releasefound=false
    assetfound=false

    for ((j=0; j < $(echo $releases | jq ". | length"); j++)); do

        releasename=$(echo $releases | jq --raw-output ".[$j].name")

        if [ "$releasename" = "autobin pull request $pullnumber" ]; then

            releasefound=true

            uploadurl=$(echo $releases | jq --raw-output ".[$j].upload_url")
            uploadurl=${uploadurl//\{?name,label\}/}

            asseturl=$(echo $releases | jq --raw-output ".[$j].assets_url")
            assets=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $asseturl)

            for ((k=0; k < $(echo $assets | jq ". | length"); k++)); do

                assetlabel=$(echo $assets | jq --raw-output ".[$k].label")
                assetname=$(echo $assets | jq --raw-output ".[$k].name")

                if [ "${assetname: -4}" = ".deb" ]; then
                    assetstate=$(echo $assets | jq --raw-output ".[$k].state")
                    if [ "$assetlabel" = "$pullsha.deb" ] && [ "$assetstate" != "new" ]; then
                        assetfound=true
                    else
                        binaryurl=$(echo $assets | jq --raw-output ".[$k].url")
                        curl -X DELETE -H "Authorization: token $gh_token" $binaryurl
                    fi
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
        mkdir repos
        cd repos

        rm -rf $repositoryname

        echo $pullrepository
        echo create and upload binary $pullrepository $pullbranch
        git clone $pullrepository -b $pullbranch $repositoryname
        cd $repositoryname
        
        # run script as root
        #npm install --unsafe-perm
        #npm run release --unsafe-perm

        # run script as normal user
        npm install
        npm run release

        cd releases

        filename=$(ls)

        curl -H "Accept: application/json" -H "Content-Type: application/octet-stream" -H "Authorization: token $gh_token" --data-binary "@$filename" "$uploadurl?name=$filename&label=$pullsha.deb"
    fi
done
