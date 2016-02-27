#!/bin/bash

apiurl=https://api.github.com/repos/Storj/storjnode

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

#build binary for pull request
for ((i=0; i < $(echo $pulls | jq ". | length"); i++)); do

    pullnumber=$(echo $pulls | jq --raw-output ".[$i].number")
    pullsha=$(echo $pulls | jq --raw-output ".[$i].merge_commit_sha")
    pullrepository=$(echo $pulls | jq --raw-output ".[$i].head.repo.html_url")
    pullbranch=$(echo $pulls | jq --raw-output ".[$i].head.ref")

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

                if [ "${assetname: -10}" = ".osx64.zip" ]; then
                    assetstate=$(echo $assets | jq --raw-output ".[$k].state")
                    if [ "$assetlabel" = "$pullsha.osx64.zip" ] && [ "$assetstate" != "new" ]; then
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

        echo create and upload binary $pullrepository $pullbranch
        git clone $pullrepository -b $pullbranch
        cd $repositoryname
        virtualenv -p python2.7 pythonenv

        source pythonenv/bin/activate

        pip2 install py2app
        # workaround for http://stackoverflow.com/questions/25394320/py2app-modulegraph-missing-scan-code
        sed -i '' 's/scan_code/_scan_code/g' pythonenv/lib/python2.7/site-packages/py2app/recipes/virtualenv.py
        sed -i '' 's/load_module/_load_module/g' pythonenv/lib/python2.7/site-packages/py2app/recipes/virtualenv.py

        pip2 install -r requirements.txt
        python2 setup.py install
        rm -r dist

        python2 setup.py py2app
        deactivate

        # workaround for lib2to3 issue (https://github.com/Storj/storjnode/issues/102)
        cd dist/storjnode.app/Contents/Resources/lib/python2.7/
        mv site-packages.zip unzipme.zip
        mkdir site-packages.zip
        mv unzipme.zip site-packages.zip/
        cd site-packages.zip/
        unzip unzipme.zip
        rm unzipme.zip
        cd ../../../../../../
        
        zip -r -9 storjnode.osx64.zip storjnode.app

        filename=storjnode.osx64.zip

        curl -H "Accept: application/json" -H "Content-Type: application/octet-stream" -H "Authorization: token $gh_token" --data-binary "@$filename" "$uploadurl?name=$filename&label=$pullsha.osx64.zip"
    fi
done

for ((j=0; j < $(echo $releases | jq ". | length"); j++)); do

    releasename=$(echo $releases | jq --raw-output ".[$j].name")

    if [ "$releasename" = "autobin draft release" ]; then
        assetfound=false
        asseturl=$(echo $releases | jq --raw-output ".[$j].assets_url")
        assets=$(curl -H "Accept: application/json" -H "Authorization: token $gh_token" $asseturl)
        for ((k=0; k < $(echo $assets | jq ". | length"); k++)); do

            assetname=$(echo $assets | jq --raw-output ".[$k].name")

            if [ "${assetname: -10}" = ".osx64.zip" ]; then
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
            git clone $repositoryurl -b $targetbranch
            cd $repositoryname

            virtualenv -p python2.7 pythonenv

            source pythonenv/bin/activate

            pip2 install py2app
            # workaround for http://stackoverflow.com/questions/25394320/py2app-modulegraph-missing-scan-code
            sed -i '' 's/scan_code/_scan_code/g' pythonenv/lib/python2.7/site-packages/py2app/recipes/virtualenv.py
            sed -i '' 's/load_module/_load_module/g' pythonenv/lib/python2.7/site-packages/py2app/recipes/virtualenv.py

            pip2 install -r requirements.txt
            python2 setup.py install
            rm -r dist

            python2 setup.py py2app
            deactivate

            # workaround for lib2to3 issue (https://github.com/Storj/storjnode/issues/102)
            cd dist/storjnode.app/Contents/Resources/lib/python2.7/
            mv site-packages.zip unzipme.zip
            mkdir site-packages.zip
            mv unzipme.zip site-packages.zip/
            cd site-packages.zip/
            unzip unzipme.zip
            rm unzipme.zip
            cd ../../../../../../
        
            zip -r -9 storjnode.osx64.zip storjnode.app

            filename=storjnode.osx64.zip
            curl -H "Accept: application/json" -H "Content-Type: application/octet-stream" -H "Authorization: token $gh_token" --data-binary "@$filename" "$uploadurl?name=$filename"
        fi
    fi
done
