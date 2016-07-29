@echo off
rem set some variables
Setlocal EnableDelayedExpansion

set gh_token=insert your token here
set CERT_FILE=insert your code cert file here
set CERT_PASSWORD=insert your cert password here

set workdir=!cd!

:start

cd !workdir!
cls
call storjshare-gui\build-windows-binary.bat

timeout /T 600
goto start
