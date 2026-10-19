@echo off
title Scrcpy Controller Launcher
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scrcpy-menu.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Script execution halted with error code %ERRORLEVEL%.
    pause
)