# Requires PowerShell running as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run this script as Administrator."
    Exit
}

Write-Host "Setting up Chrome shims for Brave..." -ForegroundColor Cyan

# Define paths
$braveAppDir = "C:\Program Files\BraveSoftware\Brave-Browser\Application"
$braveExe = "$braveAppDir\brave.exe"
$chromeSysDir = "C:\Program Files\Google\Chrome\Application"
$chromeLocalDir = "$env:LOCALAPPDATA\Google\Chrome\Application"

# Verify Brave exists
if (-not (Test-Path $braveExe)) {
    Write-Error "Brave executable not found at '$braveExe'."
    Exit
}

# 1. Create target directories
New-Item -ItemType Directory -Path $chromeSysDir -Force | Out-Null
New-Item -ItemType Directory -Path $chromeLocalDir -Force | Out-Null

# 2. Copy Brave supporting files/folders into Program Files Google directory
Write-Host "Copying dependencies to Program Files..." -ForegroundColor Yellow
Copy-Item -Path "$braveAppDir\*" -Destination $chromeSysDir -Recurse -Force -Exclude "brave.exe" -ErrorAction SilentlyContinue

# 3. Create Hardlinks for chrome.exe
Write-Host "Creating hardlinks for chrome.exe..." -ForegroundColor Yellow
Remove-Item "$chromeSysDir\chrome.exe" -Force -ErrorAction SilentlyContinue
Remove-Item "$chromeLocalDir\chrome.exe" -Force -ErrorAction SilentlyContinue

cmd /c mklink /H "$chromeSysDir\chrome.exe" "$braveExe"
cmd /c mklink /H "$chromeLocalDir\chrome.exe" "$braveExe"

# 4. Set Environment Variables
Write-Host "Configuring User Environment Variables..." -ForegroundColor Yellow
[System.Environment]::SetEnvironmentVariable('HOME', "$env:USERPROFILE", 'User')
[System.Environment]::SetEnvironmentVariable('CHROME_PATH', $braveExe, 'User')
[System.Environment]::SetEnvironmentVariable('PLAYWRIGHT_CHROME_PATH', $braveExe, 'User')

Write-Host "`nSetup completed successfully! Please restart Antigravity IDE." -ForegroundColor Green