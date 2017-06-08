@echo off
chcp 65001

rem set some variables
Setlocal EnableDelayedExpansion

rem setx gh_token
rem setx CERT_FILE
rem setx CERT_PASSWORD

set workdir=!cd!

:start

set path=%path:;C:\Program Files (x86)\nodejs=%
set path=%path:;C:\Program Files\nodejs=%

cd !workdir!
cls
set path=%path%;C:\Program Files (x86)\nodejs
set extension=.win32
call storjshare-gui\build-windows-binary.bat

set path=%path:;C:\Program Files (x86)\nodejs=%
set path=%path:;C:\Program Files\nodejs=%

cd !workdir!
cls
set path=%path%;C:\Program Files\nodejs
set extension=.win64
call storjshare-gui\build-windows-binary.bat

set path=%path:;C:\Program Files (x86)\nodejs=%
set path=%path:;C:\Program Files\nodejs=%

timeout /T 600
goto start
