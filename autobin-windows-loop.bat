@echo off
rem set some variables
Setlocal EnableDelayedExpansion

rem setx gh_token
rem setx CERT_FILE
rem setx CERT_PASSWORD

set workdir=!cd!

:start

cd !workdir!
cls
call storjshare-gui\build-windows-binary.bat

timeout /T 600
goto start
