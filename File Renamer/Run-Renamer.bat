@echo off
title Universal Anime File Renamer
color 0B

:: Capture the dragged file or folder (if any)
set "TARGET=%~1"

:MENU
cls
echo ==========================================
echo    UNIVERSAL FILE RENAMER - MODE SELECT
echo ==========================================

:: Flat IF statements to prevent parenthesis crashing
if "%TARGET%"=="" echo Target: Current Folder (Default)
if not "%TARGET%"=="" echo Target: "%TARGET%"

echo ==========================================
echo [1] Dry Run (Preview changes safely)
echo [2] Normal Run (Apply changes live)
echo [3] Exit
echo.

:: Pre-load 1 so pressing Enter automatically runs the Dry Run
set "choice=1"
set /p choice="Select an option (1-3) [Default: 1]: "

if "%choice%"=="1" goto DRYRUN
if "%choice%"=="2" goto REALRUN
if "%choice%"=="3" exit
goto MENU

:DRYRUN
echo.
echo Running Dry Run Preview...
powershell -ExecutionPolicy Bypass -File "%~dp0Rename-AnimeFiles.ps1" "DRY" "%TARGET%"
echo.
pause
goto MENU

:REALRUN
echo.
echo [WARNING] Running Live Rename...
powershell -ExecutionPolicy Bypass -File "%~dp0Rename-AnimeFiles.ps1" "LIVE" "%TARGET%"
echo.
pause
exit