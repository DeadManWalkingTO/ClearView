@echo off
pushd %~dp0
.\external\AutoHotkey64.exe .\submacros\main.ahk
echo ExitCode=%errorlevel%
pause