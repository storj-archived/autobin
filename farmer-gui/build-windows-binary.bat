@echo off
Setlocal EnableDelayedExpansion

set apiurl=https://api.github.com/repos/Storj/farmer-gui

curl -H "Accept: application/json" -H "Authorization: token !gh_token!" !apiurl! > repository.json

type repository.json | jq --raw-output ".name" > temp.dat
set /p repositoryname= < temp.dat
del temp.dat

type repository.json | jq --raw-output ".html_url" > temp.dat
set /p repositoryurl= < temp.dat
del temp.dat

type repository.json | jq --raw-output ".releases_url" > temp.dat
set /p releasesurl= < temp.dat
set releasesurl=!releasesurl:{/id}=!
del temp.dat

type repository.json | jq --raw-output ".pulls_url" > temp.dat
set /p pullurl= < temp.dat
set pullurl=!pullurl:{/number}=!
del temp.dat

type repository.json | jq --raw-output ".tags_url" > temp.dat
set /p tagurl= < temp.dat
del temp.dat

rem get releases and pull requests from github
curl -H "Accept: application/json" -H "Authorization: token !gh_token!" !releasesurl! > releases.json
curl -H "Accept: application/json" -H "Authorization: token !gh_token!" !pullurl! > pulls.json
curl -H "Accept: application/json" -H "Authorization: token !gh_token!" !tagurl! > tags.json

rem counting releases
type releases.json | jq ". | length" > temp.dat
set /p releases= < temp.dat
del temp.dat
set /a releases=!releases!-1

rem counting pull request
type pulls.json | jq ". | length" > temp.dat
set /p pulls= < temp.dat
del temp.dat
set /a pulls=!pulls!-1

for /L %%I in (0, 1, !pulls!) do (

    type pulls.json | jq --raw-output ".[%%I].number" > temp.dat
    set /p pullnumber= < temp.dat
    del temp.dat

    type pulls.json | jq --raw-output ".[%%I].merge_commit_sha" > temp.dat
    set /p pullsha= < temp.dat
    del temp.dat

    type pulls.json | jq --raw-output ".[%%I].head.repo.html_url" > temp.dat
    set /p pullrepository= < temp.dat
    del temp.dat

    type pulls.json | jq --raw-output ".[%%I].head.ref" > temp.dat
    set /p pullbranch= < temp.dat
    del temp.dat

    set releasefound="false"
    set assetfound="false"
    for /L %%J in (0, 1, !releases!) do (

        type releases.json | jq --raw-output ".[%%J].name" > temp.dat
        set /p releasename= < temp.dat
        del temp.dat

        rem search for a release with autobin and pull request number
        if "!releasename!" == "autobin pull request !pullnumber!" (

            set releasefound="true"

            type releases.json | jq --raw-output ".[%%J].upload_url" > temp.dat
            set /p uploadurl= < temp.dat
            set uploadurl=!uploadurl:{?name,label}=!
            del temp.dat

            type releases.json | jq --raw-output ".[%%J].assets_url" > temp.dat
            set /p asseturl= < temp.dat
            del temp.dat

            curl -H "Accept: application/json" -H "Authorization: token !gh_token!" !asseturl! > assets.json

            type assets.json | jq ". | length" > temp.dat
            set /p assets= < temp.dat
            del temp.dat
            set /a assets=!assets!-1

            for /L %%K in (0, 1, !assets!) do (
                type assets.json | jq --raw-output ".[%%K].label" > temp.dat
                set /p assetlabel= < temp.dat
                del temp.dat

                type assets.json | jq --raw-output ".[%%K].name" > temp.dat
                set /p assetname= < temp.dat
                del temp.dat

                if "!assetname:~-4!" == ".exe" (

                    type assets.json | jq --raw-output ".[%%K].state" > temp.dat
                    set /p assetstate= < temp.dat
                    del temp.dat

                    if !assetlabel! == !pullsha!.exe (
                        if not "!assetstate!" == "new" (
                            set assetfound="true"
                        ) else (
                            type assets.json | jq --raw-output ".[%%K].url" > temp.dat
                            set /p binaryurl= < temp.dat
                            del temp.dat
                            curl -X DELETE -H "Authorization: token !gh_token!" !binaryurl!
                        )
                    ) else (
                        type assets.json | jq --raw-output ".[%%K].url" > temp.dat
                        set /p binaryurl= < temp.dat
                        del temp.dat
                        curl -X DELETE -H "Authorization: token !gh_token!" !binaryurl!
                    )
                )
            )
        )
    )
    rem create new release if not exists
    if not !releasefound! == "true" (
        echo create release autobin pull request !pullnumber!
        curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token !gh_token!" -X POST -d "{\"tag_name\":\"\",\"name\":\"autobin pull request !pullnumber!\",\"draft\":true}" !releasesurl! | jq --raw-output ".upload_url" > temp.dat
        set /p uploadurl= < temp.dat
        set uploadurl=!uploadurl:{?name,label}=!
        del temp.dat
        echo !uploadurl!
    )
    rem create and upload a new binary if not exists
    if not !assetfound! == "true" (
        mkdir repos
        cd repos

        rem delete old build files
        rmdir /S /Q !repositoryname!

        echo create and upload binary !pullrepository! !pullbranch!
        git clone "!pullrepository!" -b "!pullbranch!"
        cd !repositoryname!
        cmd /c npm install
        cmd /c npm run release

        cd releases
        ren *.exe *.win32.exe
        for /R %%F in (*win32.exe) do set filename=%%~nxF

        curl -H "Accept: application/json" -H "Content-Type: application/exe" -H "Authorization: token !gh_token!" --data-binary "@!filename!" "!uploadurl!?name=!filename!&label=!pullsha!.exe"
    )
)

for /L %%J in (0, 1, !releases!) do (

    type releases.json | jq --raw-output ".[%%J].name" > temp.dat
    set /p releasename= < temp.dat
    del temp.dat
    
    rem build binaries for new draft release
    if "!releasename!" == "autobin draft release" (

        set assetfound="false"

        type releases.json | jq --raw-output ".[%%J].assets_url" > temp.dat
        set /p asseturl= < temp.dat
        del temp.dat

        curl -H "Accept: application/json" -H "Authorization: token !gh_token!" !asseturl! > assets.json

        type assets.json | jq ". | length" > temp.dat
        set /p assets= < temp.dat
        del temp.dat
        set /a assets=!assets!-1

        for /L %%K in (0, 1, !assets!) do (
            type assets.json | jq --raw-output ".[%%K].name" > temp.dat
            set /p assetname= < temp.dat
            del temp.dat

            if "!assetname:~-4!" == ".exe" (

                type assets.json | jq --raw-output ".[%%K].state" > temp.dat
                set /p assetstate= < temp.dat
                del temp.dat

                if "!assetstate!" == "new" (
                    type assets.json | jq --raw-output ".[%%K].url" > temp.dat
                    set /p binaryurl= < temp.dat
                    del temp.dat
                    curl -X DELETE -H "Authorization: token !gh_token!" !binaryurl!
                ) else (
                    set assetfound="true"
                )
            )
        )

        if not !assetfound! == "true" (
            type releases.json | jq --raw-output ".[%%J].upload_url" > temp.dat
            set /p uploadurl= < temp.dat
            set uploadurl=!uploadurl:{?name,label}=!
            del temp.dat

            type releases.json | jq --raw-output ".[%%J].target_commitish" > temp.dat
            set /p targetbranch= < temp.dat
            del temp.dat

            type releases.json | jq --raw-output ".[%%J].tag_name" > temp.dat
            set /p targettag= < temp.dat
            del temp.dat

            if not !targettag! == null (

                type tags.json | jq ". | length" > temp.dat
                set /p tags= < temp.dat
                del temp.dat
                set /a tags=!tags!-1

                for /L %%L in (0, 1, !tags!) do (

                    type tags.json | jq --raw-output ".[%%L].name" > temp.dat
                    set /p tag= < temp.dat
                    del temp.dat

                    if !targettag! == !tag! (
                        set targetbranch=!targettag!
                    )
                )
            )

            mkdir repos
            cd repos

            rem delete old build files
            rmdir /S /Q !repositoryname!

            echo create and upload binary !repositoryurl! !targetbranch!
            git clone !repositoryurl! -b "!targetbranch!"
            cd !repositoryname!
            cmd /c npm install
            cmd /c npm run release

            cd releases
            ren *.exe *.win32.exe
            for /R %%F in (*win32.exe) do set filename=%%~nxF

            curl -H "Accept: application/json" -H "Content-Type: application/exe" -H "Authorization: token !gh_token!" --data-binary "@!filename!" "!uploadurl!?name=!filename!" > upload.json
        )
    )
)
