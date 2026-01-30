@echo off
pushd %~dp0

REM Εκκίνηση της εφαρμογής AHK ως ανεξάρτητης διεργασίας και έξοδος του .bat αμέσως
start "" ".\external\AutoHotkey64.exe" ".\submacros\main.ahk"

popd
exit /b
