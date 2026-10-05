# Requires PowerShell running as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this script as Administrator."
    Exit
}

Write-Host "Reverting Chrome shims and restoring original state..." -ForegroundColor Cyan

# 1. Remove created directories and linked files
Write-Host "Removing shim directories..." -ForegroundColor Yellow
Remove-Item -Path "C:\Program Files\Google\Chrome" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\Google\Chrome" -Recurse -Force -ErrorAction SilentlyContinue

# Clean up parent Google folders if they are empty
if ((Test-Path "C:\Program Files\Google") -and -not (Get-ChildItem "C:\Program Files\Google")) {
    Remove-Item "C:\Program Files\Google" -Force -ErrorAction SilentlyContinue
}
if ((Test-Path "$env:LOCALAPPDATA\Google") -and -not (Get-ChildItem "$env:LOCALAPPDATA\Google")) {
    Remove-Item "$env:LOCALAPPDATA\Google" -Force -ErrorAction SilentlyContinue
}

# 2. Remove added User Environment Variables
Write-Host "Removing environment variables..." -ForegroundColor Yellow
[System.Environment]::SetEnvironmentVariable('CHROME_PATH', $null, 'User')
[System.Environment]::SetEnvironmentVariable('PLAYWRIGHT_CHROME_PATH', $null, 'User')
[System.Environment]::SetEnvironmentVariable('HOME', $null, 'User')

Write-Host "`nRevert complete! All shim files and environment settings have been removed." -ForegroundColor Green