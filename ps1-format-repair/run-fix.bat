@echo off
if "%~1"=="" (
    echo Please drag and drop a .ps1 file directly onto this .bat file!
    pause
    exit /b
)

powershell -ExecutionPolicy Bypass -File "%~dp0fix-fuse$.ps1" "%~1"
pause