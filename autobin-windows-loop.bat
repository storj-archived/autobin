@echo off
rem set some variables
Setlocal EnableDelayedExpansion

set gh_token=insert your token here

set workdir=!cd!

:start

cd !workdir!
cls
call farmer-gui\build-windows-binary.bat

cd !workdir!
cls
call storjnode\build-windows-binary.bat

cd !workdir!
cls
call dataserv-client\build-windows-binary.bat

timeout /T 600
goto start
