@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM --- Force UTF-8 for proper Greek output in console ---
for /f "tokens=2 delims=:." %%G in ('chcp') do set "_OLDCP=%%G"
chcp 65001 >nul

REM ---------------------------------------------------------------------------
REM update.bat
REM Χρήση:
REM   update.bat "<FULL_PATH_TO_ZIP>" "<APP_ROOT>"
REM Παράδειγμα:
REM   update.bat "C:\Users\you\AppData\Local\Temp\ClearView-main.zip" "C:\Projects\ClearView"
REM
REM Σύνοψη:
REM 1) Αποσυμπίεση ZIP (PowerShell Expand-Archive -Force).
REM 2) Mirroring ΟΛΩΝ των αρχείων στο APP_ROOT, ΕΚΤΟΣ του φακέλου "submacros".
REM 3) Δημιουργία και εκκίνηση post-update .bat (ενημέρωση "submacros" & cleanup).
REM 4) Επιστρέφει κωδικό 0 στο επιτυχημένο τέλος.
REM ---------------------------------------------------------------------------

REM ==== ΕΙΣΟΔΟΙ ==============================================================
set "ZIP=%~1"
set "APPROOT=%~2"
if "%ZIP%"=="" (
  echo [Updater] ERROR: Λείπει 1o όρισμα: FULL_PATH_TO_ZIP
  call :_restorecp & exit /b 2
)
if "%APPROOT%"=="" (
  echo [Updater] ERROR: Λείπει 2o όρισμα: APP_ROOT
  call :_restorecp & exit /b 2
)

REM Έλεγχος ύπαρξης αρχείου ZIP
if not exist "%ZIP%" (
  echo [Updater] ERROR: Δεν βρέθηκε ZIP: "%ZIP%"
  call :_restorecp & exit /b 3
)

REM Έλεγχος PowerShell
where powershell >nul 2>&1
if errorlevel 1 (
  echo [Updater] ERROR: Δεν βρέθηκε powershell.exe στο PATH.
  call :_restorecp & exit /b 4
)

REM ==== ΠΡΟΣΩΡΙΝΟΙ ΦΑΚΕΛΟΙ ==================================================
set "_RAND=%RANDOM%_%TIME::=%"
set "TMPDIR=%TEMP%\cv_update_extract_%_RAND%"
set "LOGPREFIX=[Updater]"
echo %LOGPREFIX% Προσωρινός φάκελος: "%TMPDIR%"
if exist "%TMPDIR%" rd /s /q "%TMPDIR%"
mkdir "%TMPDIR%" || (
  echo %LOGPREFIX% ERROR: Αδυναμία δημιουργίας "%TMPDIR%"
  call :_restorecp & exit /b 5
)

REM ==== 1) ΑΠΟΣΥΜΠΙΕΣΗ ZIP ===================================================
echo %LOGPREFIX% Αποσυμπίεση ZIP...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%TMPDIR%' -Force" 1>nul
if errorlevel 1 (
  echo %LOGPREFIX% ERROR: Αποτυχία Expand-Archive.
  rd /s /q "%TMPDIR%" >nul 2>&1
  call :_restorecp & exit /b 6
)

REM Εντόπισε ριζικό φάκελο που προκύπτει από το zip (συνήθως <repo>-main)
set "SRCDIR="
for /d %%D in ("%TMPDIR%\*") do (
  set "SRCDIR=%%~fD"
  goto :found_src
)
:found_src
if "%SRCDIR%"=="" (
  echo %LOGPREFIX% ERROR: Δεν βρέθηκε ριζικός φάκελος μέσα στο ZIP.
  rd /s /q "%TMPDIR%" >nul 2>&1
  call :_restorecp & exit /b 7
)
echo %LOGPREFIX% Πηγή για αντιγραφή: "%SRCDIR%"

REM ==== 2) MIRROR ΟΛΩΝ ΕΚΤΟΣ "submacros" =====================================
echo %LOGPREFIX% Mirroring στο APP_ROOT (εξαίρεση: submacros)...
robocopy "%SRCDIR%" "%APPROOT%" /MIR /XD "%SRCDIR%\submacros" "%APPROOT%\submacros" ^
 /R:2 /W:1 /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
  echo %LOGPREFIX% ERROR: Αποτυχία robocopy (κωδικός %ERRORLEVEL%).
  REM σημ.: robocopy επιστρέφει 1/2 για μικρά warnings—θεωρούνται επιτυχία.
  rd /s /q "%TMPDIR%" >nul 2>&1
  call :_restorecp & exit /b 8
)

REM ==== 3) POST-UPDATE (ενημέρωση "submacros" & cleanup) =====================
set "POSTBAT=%TEMP%\cv_post_update_%_RAND%.bat"
(
  echo @echo off
  echo setlocal EnableExtensions
  echo chcp 65001 ^>nul
  echo rem Περιμένουμε το τρέχον update.bat να τερματίσει
  echo timeout /t 1 /nobreak ^>nul
  echo rem Mirror του submacros (πλέον δεν τρέχει το αρχικό .bat)
  echo robocopy "%SRCDIR%\submacros" "%APPROOT%\submacros" /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS /NP ^>nul
  echo rem Καθαρισμός προσωρινών
  echo rd /s /q "%TMPDIR%" ^>nul 2^>^&1
  echo rem Αυτο-διαγραφή
  echo del "%%~f0" ^>nul 2^>^&1
) > "%POSTBAT%"

if not exist "%POSTBAT%" (
  echo %LOGPREFIX% WARNING: Αποτυχία δημιουργίας post-update batch. Θα παραμείνουν tmp αρχεία.
) else (
  echo %LOGPREFIX% Τερματισμός 1ης φάσης. Προγραμματίστηκε ενημέρωση "submacros" & cleanup.
  start "" "%POSTBAT%"
)

echo %LOGPREFIX% Ολοκληρώθηκε ο προγραμματισμός αναβάθμισης.
call :_restorecp
endlocal
exit /b 0

REM ==== ΒΟΗΘΗΤΙΚΑ ============================================================
:_restorecp
if defined _OLDCP chcp %_OLDCP% >nul
goto :eof