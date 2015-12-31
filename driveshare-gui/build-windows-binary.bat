@echo off
rem set some variables
Setlocal EnableDelayedExpansion

set gh_token=e31421a94f89ce411e366fed0487286b7619aba7
set apiurl=https://api.github.com/repos/Storj/driveshare-gui

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

:start
cls

rem get releases and pull requests from github
curl -H "Accept: application/json" -H "Authorization: token !gh_token!" !releasesurl! > releases.json
curl -H "Accept: application/json" -H "Authorization: token !gh_token!" !pullurl! > pulls.json

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

    type pulls.json | jq --raw-output ".[%%I]._links.comments.href" > temp.dat
    set /p commenturl= < temp.dat
    del temp.dat

    set releasefound="false"
    set assetfound="false"
    for /L %%J in (0, 1, !releases!) do (

        type releases.json | jq --raw-output ".[%%J].name" > temp.dat
        set /p releasename= < temp.dat
        del temp.dat

        rem search for a release with automatic builds and pull request number
        if "!releasename!" == "automatic builds pull request !pullnumber!" (

            set releasefound="true"

            type releases.json | jq --raw-output ".[%%J].upload_url" > temp.dat
            set /p uploadurl= < temp.dat
            set uploadurl=!uploadurl:{?name,label}=!
            del temp.dat

            type releases.json | jq ".[%%J].assets | length" > temp.dat
            set /p assets= < temp.dat
            del temp.dat
            set /a assets=!assets!-1

            for /L %%K in (0, 1, !assets!) do (
                type releases.json | jq --raw-output ".[%%J].assets[%%K].label" > temp.dat
                set /p assetlabel= < temp.dat
                del temp.dat

                if !assetlabel! == !pullsha! (
                    set assetfound="true"
                )
            )
        )
    )
    rem create new release if not exists
    if not !releasefound! == "true" (
        echo create release automatic builds pull request !pullnumber!
        curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token !gh_token!" -X POST -d "{\"tag_name\":\"\",\"name\":\"automatic builds pull request !pullnumber!\",\"draft\":true}" !releasesurl! | jq ".upload_url" > temp.dat
        set /p uploadurl= < temp.dat
        set uploadurl=!uploadurl:{?name,label}=!
        del temp.dat
        echo !uploadurl!
    )
    rem create and upload a new binary if not exists
    if not !assetfound! == "true" (
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

        cd ../..
        for /L %%J in (0, 1, !releases!) do (
            for /L %%K in (0, 1, !assets!) do (
                type releases.json | jq --raw-output ".[%%J].assets[%%K].name" > temp.dat
                set /p assetname= < temp.dat
                del temp.dat

                if !assetname! == !filename! (
                    type releases.json | jq --raw-output ".[%%J].assets[%%K].url" > temp.dat
                        set /p asseturl= < temp.dat
                        del temp.dat
                        curl -X DELETE -H "Authorization: token !gh_token!" !asseturl!
                )
            )
        )
        cd !repositoryname!/releases

        curl -H "Accept: application/json" -H "Content-Type: application/exe" -H "Authorization: token !gh_token!" --data-binary "@!filename!" "!uploadurl!?name=!filename!&label=!pullsha!" > upload.json
        type upload.json | jq --raw-output ".browser_download_url" > temp.dat
        set /p downloadurl= < temp.dat
        del temp.dat

        curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token !gh_token!" -X POST -d "{\"body\":\"Automatic build binary ^(only available for team members^): [!filename!]^(!downloadurl!^) sha: !pullsha!\"}" !commenturl!
        cd ../..
    )
)

for /L %%J in (0, 1, !releases!) do (

    type releases.json | jq --raw-output ".[%%J].name" > temp.dat
    set /p releasename= < temp.dat
    del temp.dat

    rem delete binaries for closed pull request
    if "!releasename:~0,30!" == "automatic builds pull request " (

        set pullnumber=!releasename:automatic builds pull request =!
        curl -H "Accept: application/json" -H "Authorization: token !gh_token!" !pullurl!/!pullnumber! | jq --raw-output ".state" > temp.dat
        set /p pullstate= < temp.dat
        del temp.dat

        if "!pullstate!" == "closed" (
            type releases.json | jq ".[%%J].id" > temp.dat
            set /p releaseid= < temp.dat
            del temp.dat

            curl -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: token !gh_token!" -X DELETE !releasesurl!/!releaseid!
        )
    )
    
    rem build binaries for new draft release
    if "!releasename!" == "automatic builds draft release" (

        set assetfound="false"

        type releases.json | jq ".[%%J].assets | length" > temp.dat
        set /p assets= < temp.dat
        del temp.dat
        set /a assets=!assets!-1

        for /L %%K in (0, 1, !assets!) do (
            type releases.json | jq --raw-output ".[%%J].assets[%%K].name" > temp.dat
            set /p assetname= < temp.dat
            del temp.dat

            if "!assetname:~-4!" == ".exe" (
                set assetfound="true"
            )
        )

        if not !assetfound! == "true" (
            type releases.json | jq --raw-output ".[%%J].upload_url" > temp.dat
            set /p uploadurl= < temp.dat
            set uploadurl=!uploadurl:{?name,label}=!
            del temp.dat

            rem delete old build files
            rmdir /S /Q !repositoryname!

            type releases.json | jq --raw-output ".[%%J].target_commitish" > temp.dat
            set /p targetbranch= < temp.dat
            del temp.dat

            type releases.json | jq --raw-output ".[%%J].tag_name" > temp.dat
            set /p targettag= < temp.dat
            del temp.dat

            if not !targettag! == null (
                set targetbranch=!targettag!
            )

            echo create and upload binary !repositoryurl! !targetbranch!
            git clone !repositoryurl! -b "!targetbranch!"
            cd !repositoryname!
            cmd /c npm install
            cmd /c npm run release

            cd releases
            ren *.exe *.win32.exe
            for /R %%F in (*win32.exe) do set filename=%%~nxF

            curl -H "Accept: application/json" -H "Content-Type: application/exe" -H "Authorization: token !gh_token!" --data-binary "@!filename!" "!uploadurl!?name=!filename!" > upload.json
            cd ../..
        )
    )
)
timeout /T 60
goto start
