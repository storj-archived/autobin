@echo off
rem set some variables
Setlocal EnableDelayedExpansion

set gh_token=insert your token here

:start

cls
call driveshare-gui\build-windows-binary.bat

cls
call storjnode\build-windows-binary.bat

timeout /T 60
goto start
