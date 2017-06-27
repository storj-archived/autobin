@echo off
Setlocal EnableDelayedExpansion

set apiurl=https://api.github.com/repos/Storj/storjshare-gui

curl -H "Accept: application/json" -H "Authorization: token !GH_TOKEN!" !apiurl! > repository.json

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
curl -H "Accept: application/json" -H "Authorization: token !GH_TOKEN!" !releasesurl! > releases.json
curl -H "Accept: application/json" -H "Authorization: token !GH_TOKEN!" !pullurl! > pulls.json
curl -H "Accept: application/json" -H "Authorization: token !GH_TOKEN!" !tagurl! > tags.json

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

for /L %%J in (0, 1, !releases!) do (

    type releases.json | jq --raw-output ".[%%J].tag_name" > temp.dat
    set /p releasetag= < temp.dat
    del temp.dat
    
    rem build binaries for new release tags
    if not !releasetag! == null (

        set assetfound="false"

        type releases.json | jq --raw-output ".[%%J].assets_url" > temp.dat
        set /p asseturl= < temp.dat
        del temp.dat

        curl -H "Accept: application/json" -H "Authorization: token !GH_TOKEN!" !asseturl! > assets.json

        type assets.json | jq ". | length" > temp.dat
        set /p assets= < temp.dat
        del temp.dat
        set /a assets=!assets!-1

        for /L %%K in (0, 1, !assets!) do (
            type assets.json | jq --raw-output ".[%%K].name" > temp.dat
            set /p assetname= < temp.dat
            del temp.dat

            if "!assetname:~14!" == "!extension!.exe" (

                type assets.json | jq --raw-output ".[%%K].state" > temp.dat
                set /p assetstate= < temp.dat
                del temp.dat

                if "!assetstate!" == "new" (
                    type assets.json | jq --raw-output ".[%%K].url" > temp.dat
                    set /p binaryurl= < temp.dat
                    del temp.dat
                    curl -X DELETE -H "Authorization: token !GH_TOKEN!" !binaryurl!
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

            cd !workdir!
            mkdir repos
            cd repos

            rem delete old build files
            rmdir /S /Q !repositoryname!

            echo create and upload binary !repositoryurl! !releasetag!
            git clone "!repositoryurl!" -b "!releasetag!" "!repositoryname!"
            cd !repositoryname!
            cmd /c npm install
            cmd /c npm run release

            cd releases
            ren *.exe *!extension!.exe
            for /R %%F in (*!extension!.exe) do set filename=%%~nxF

            curl -H "Accept: application/json" -H "Content-Type: application/exe" -H "Authorization: token !GH_TOKEN!" --data-binary "@!filename!" "!uploadurl!?name=!filename!"
            cd !workdir!
        )

        rem don't build binaries for old release tags
        goto :Break
    )
)

:Break

for /L %%I in (0, 1, !pulls!) do (

    type pulls.json | jq --raw-output ".[%%I].number" > temp.dat
    set /p pullnumber= < temp.dat
    del temp.dat

    type pulls.json | jq --raw-output ".[%%I].head.sha" > temp.dat
    set /p pullsha= < temp.dat
    del temp.dat

    type pulls.json | jq --raw-output ".[%%I].head.repo.html_url" > temp.dat
    set /p pullrepository= < temp.dat
    del temp.dat

    type pulls.json | jq --raw-output ".[%%I].head.ref" > temp.dat
    set /p pullbranch= < temp.dat
    del temp.dat

    rem refresh github releases (3 build script are running at the same time. Only one should create the new pull request release.)
    curl -H "Accept: application/json" -H "Authorization: token !GH_TOKEN!" !releasesurl! > releases.json

    rem counting releases
    type releases.json | jq ". | length" > temp.dat
    set /p releases= < temp.dat
    del temp.dat
    set /a releases=!releases!-1

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

            curl -H "Accept: application/json" -H "Authorization: token !GH_TOKEN!" !asseturl! > assets.json

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

                if "!assetname:~-10!" == "!extension!.exe" (

                    type assets.json | jq --raw-output ".[%%K].state" > temp.dat
                    set /p assetstate= < temp.dat
                    del temp.dat

                    if !assetlabel! == !pullsha!!extension!.exe (
                        if not "!assetstate!" == "new" (
                            set assetfound="true"
                        ) else (
                            type assets.json | jq --raw-output ".[%%K].url" > temp.dat
                            set /p binaryurl= < temp.dat
                            del temp.dat
                            curl -X DELETE -H "Authorization: token !GH_TOKEN!" !binaryurl!
                        )
                    ) else (
                        type assets.json | jq --raw-output ".[%%K].url" > temp.dat
                        set /p binaryurl= < temp.dat
                        del temp.dat
                        curl -X DELETE -H "Authorization: token !GH_TOKEN!" !binaryurl!
                    )
                )
            )
        )
    )
    rem create new release if not exists
    if not !releasefound! == "true" (
        echo create release autobin pull request !pullnumber!
        curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token !GH_TOKEN!" -X POST -d "{\"tag_name\":\"\",\"name\":\"autobin pull request !pullnumber!\",\"draft\":true}" !releasesurl! | jq --raw-output ".upload_url" > temp.dat
        set /p uploadurl= < temp.dat
        set uploadurl=!uploadurl:{?name,label}=!
        del temp.dat
        echo !uploadurl!
    )
    rem create and upload a new binary if not exists
    if not !assetfound! == "true" (

        cd !workdir!
        mkdir repos
        cd repos

        rem delete old build files
        rmdir /S /Q !repositoryname!

        echo create and upload binary !pullrepository! !pullbranch!
        git clone "!pullrepository!" -b "!pullbranch!" "!repositoryname!"
        cd !repositoryname!
        cmd /c npm install
        cmd /c npm run release

        cd releases
        ren *.exe *!extension!.exe
        for /R %%F in (*!extension!.exe) do set filename=%%~nxF

        curl -H "Accept: application/json" -H "Content-Type: application/exe" -H "Authorization: token !GH_TOKEN!" --data-binary "@!filename!" "!uploadurl!?name=!filename!&label=!pullsha!!extension!.exe"
        cd !workdir!
    )
)
