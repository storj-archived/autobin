@echo off
rem set some variables
Setlocal EnableDelayedExpansion

set gh_token=insert your token here

set workdir=!cd!

:start

cd !workdir!
cls
call storjshare-gui\build-windows-binary.bat

timeout /T 600
goto start
