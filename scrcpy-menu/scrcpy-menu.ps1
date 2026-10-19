<#
.SYNOPSIS
    Dynamic Interactive Scrcpy Controller Script
.DESCRIPTION
    Portable launcher with persistent JSON configuration for scrcpy and adb locations.
#>

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent ($MyInvocation.MyCommand.Path)
$ConfigFile = Join-Path ($ScriptDir) "config.json"

function Show-Header {
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "             SCRCPY CONTROLLER MENU                 " -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
}

function Load-Config {
    if (Test-Path -LiteralPath ($ConfigFile)) {
        try {
            $loaded = Get-Content -LiteralPath ($ConfigFile) -Raw | ConvertFrom-Json
            if ($loaded) {
                return $loaded
            }
        } catch {
            return ([PSCustomObject]@{})
        }
    }
    return ([PSCustomObject]@{})
}

function Save-Config ($configData) {
    $configData | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ($ConfigFile) -Encoding utf8 -Force
}

function Prompt-ToolPath {
    param (
        [string] $ToolName,
        [string] $ExeName,
        [string] $ExistingPath = ""
    )
    Show-Header
    Write-Host ("[!] {0} directory is not configured or could not be found." -f $ToolName) -ForegroundColor Yellow
    if ($ExistingPath) {
        Write-Host ("Current invalid path: {0}" -f $ExistingPath) -ForegroundColor DarkGray
    }
    Write-Host ("Enter the full folder path where '{0}' is located:" -f $ExeName) -ForegroundColor Cyan

    while ($true) {
	$userInput = Read-Host ("`n{0} Folder Path" -f $ToolName)
        $cleanedPath = $userInput.Trim('"', "'", " ")

        if ($cleanedPath -like ("*{0}" -f $ExeName) -and (Test-Path -LiteralPath ($cleanedPath) -PathType Leaf)) {
            return (Split-Path -Parent ($cleanedPath))
        }

        if ($cleanedPath -and (Test-Path -LiteralPath (Join-Path ($cleanedPath) $ExeName) -PathType Leaf)) {
            return $cleanedPath
        } else {
            Write-Host ("[ERROR] '{0}' was not found in '{1}'." -f $ExeName, $cleanedPath) -ForegroundColor Red
            Write-Host "Please verify the folder path and try again." -ForegroundColor Yellow
        }
    }
}

# 1. Load or Initialize Configuration
$Config = Load-Config

# 2. Resolve ADB Path (Config -> System PATH -> Prompt User)
$AdbDir = $Config.AdbPath

if (-not $AdbDir -or -not (Test-Path -LiteralPath (Join-Path ($AdbDir) "adb.exe"))) {
    $cmdAdb = Get-Command "adb" -ErrorAction SilentlyContinue
    if ($cmdAdb) {
        $AdbDir = Split-Path -Parent ($cmdAdb.Source)
    } else {
        $AdbDir = Prompt-ToolPath -ToolName "ADB (Platform-Tools)" -ExeName "adb.exe" -ExistingPath ($AdbDir)
    }
    $Config | Add-Member -Name "AdbPath" -Value ($AdbDir) -MemberType NoteProperty -Force
    Save-Config ($Config)
}

$env:Path = ("{0};{1}" -f $AdbDir, $env:Path)

# 3. Resolve Scrcpy Path (Config -> System PATH -> Prompt User)
$ScrcpyDir = $Config.ScrcpyPath

if (-not $ScrcpyDir -or -not (Test-Path -LiteralPath (Join-Path ($ScrcpyDir) "scrcpy.exe"))) {
    $cmdScrcpy = Get-Command "scrcpy" -ErrorAction SilentlyContinue
    if ($cmdScrcpy) {
        $ScrcpyDir = Split-Path -Parent ($cmdScrcpy.Source)
    } else {
        $ScrcpyDir = Prompt-ToolPath -ToolName "Scrcpy" -ExeName "scrcpy.exe" -ExistingPath ($ScrcpyDir)
    }
    $Config | Add-Member -Name "ScrcpyPath" -Value ($ScrcpyDir) -MemberType NoteProperty -Force
    Save-Config ($Config)
}

$env:Path = ("{0};{1}" -f $ScrcpyDir, $env:Path)

# Prevent bundled ADB collisions inside Scrcpy folder if ADB lives elsewhere
if (($ScrcpyDir -ne $AdbDir) -and (Test-Path -LiteralPath (Join-Path ($ScrcpyDir) "adb.exe"))) {
    Rename-Item -LiteralPath (Join-Path ($ScrcpyDir) "adb.exe") -NewName "adb.exe.bak" -Force -ErrorAction SilentlyContinue
}

# 4. Device Enumeration
function Get-TargetDevice {
    $rawDevices = adb devices | Where-Object { $_ -match '\t(device|unauthorized)$' }

    if (-not $rawDevices) {
        Show-Header
        Write-Host "[!] No connected devices found." -ForegroundColor Yellow
        Write-Host "Connect your device via USB with USB Debugging enabled, then press any key to scan..."
        Pause
        $rawDevices = adb devices | Where-Object { $_ -match '\t(device|unauthorized)$' }
        if (-not $rawDevices) {
            Write-Host "[ERROR] Still no devices detected." -ForegroundColor Red
            return $null
        }
    }

    $validDevices = @($rawDevices | Where-Object { $_ -match '\tdevice$' } | ForEach-Object { ($_ -split '\t')[0] })

    if ($validDevices.Count -gt 1) {
        Show-Header
        Write-Host "Multiple devices detected. Select a target:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $validDevices.Count; $i++) {
            $model = (adb -s ($validDevices[$i]) shell getprop ro.product.model 2>$null).Trim()
            Write-Host ("  [{0}] {1} ({2})" -f ($i + 1), $validDevices[$i], $model)
        }
        Write-Host "====================================================" -ForegroundColor Cyan
        $devIndex = Read-Host ("Enter device number (1-{0})" -f $validDevices.Count)
        $selectedSerial = $validDevices[[int]$devIndex - 1]
        return @("-s", $selectedSerial)
    } elseif ($validDevices.Count -eq 1) {
        return @("-s", $validDevices[0])
    }
    return $null
}

$deviceArg = Get-TargetDevice

# 5. Interactive Main Menu
while ($true) {
    Show-Header
    Write-Host ("Scrcpy Path   : {0}" -f $ScrcpyDir) -ForegroundColor DarkGray
    Write-Host ("ADB Path      : {0}" -f $AdbDir) -ForegroundColor DarkGray
    if ($deviceArg -and $deviceArg.Count -gt 1) {
        Write-Host ("Active Device : {0}" -f $deviceArg[1]) -ForegroundColor Green
    } else {
        Write-Host "Active Device : None (Select Option 7 to scan)" -ForegroundColor Yellow
    }
    Write-Host "----------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [1] Screen Mirroring + Microphone (Screen + Mic Pass)"
    Write-Host "  [2] Screen Mirroring + Internal Audio (Screen + System Sound)"
    Write-Host "  [3] Microphone Only (Headless PC Mic, No Screen)"
    Write-Host "  [4] Screen Mirroring Only (Mute Audio)"
    Write-Host "  [5] Internal Audio Only (Headless System Sound)"
    Write-Host "  [6] Camera Mirroring (Android Camera as Webcam)"
    Write-Host "  [7] Re-scan / Switch Connected Device"
    Write-Host "  [8] Configure Scrcpy / ADB Paths"
    Write-Host "  [9] Exit"
    Write-Host "====================================================" -ForegroundColor Cyan

    $selection = Read-Host "Select an option [1-9]"

    if ($selection -in "1","2","3","4","5","6" -and -not $deviceArg) {
        Write-Host "`n[!] No active device selected. Scanning now..." -ForegroundColor Yellow
        $deviceArg = Get-TargetDevice
        if (-not $deviceArg) {
            Write-Host "Press any key to return to menu..." -ForegroundColor DarkGray
            [Console]::ReadKey($true) | Out-Null
            continue
        }
    }

    $scrcpyArgs = @() + ($deviceArg)

    switch ($selection) {
        "1" {
            Write-Host "`nLaunching Mirroring with Mic Passthrough..." -ForegroundColor Green
            $scrcpyArgs += "--audio-source=mic"
            & scrcpy @scrcpyArgs
        }
        "2" {
            Write-Host "`nLaunching Mirroring with Internal Audio..." -ForegroundColor Green
            & scrcpy @scrcpyArgs
        }
        "3" {
            Write-Host "`nStreaming Microphone Only (Headless)..." -ForegroundColor Green
            $scrcpyArgs += @("--audio-source=mic", "--no-video")
            & scrcpy @scrcpyArgs
        }
        "4" {
            Write-Host "`nLaunching Screen Only (Mute Audio)..." -ForegroundColor Green
            $scrcpyArgs += "--no-audio"
            & scrcpy @scrcpyArgs
        }
        "5" {
            Write-Host "`nStreaming Internal Audio Only (Headless)..." -ForegroundColor Green
            $scrcpyArgs += @("--audio-source=playback", "--no-video")
            & scrcpy @scrcpyArgs
        }
        "6" {
            Write-Host "`nStreaming Camera..." -ForegroundColor Green
            $scrcpyArgs += @("--video-source=camera")
            & scrcpy @scrcpyArgs
        }
        "7" {
            $deviceArg = Get-TargetDevice
            continue
        }
        "8" {
            Show-Header
            Write-Host ("  [1] Change Scrcpy Path (Current: {0})" -f $ScrcpyDir)
            Write-Host ("  [2] Change ADB Path    (Current: {0})" -f $AdbDir)
            Write-Host "  [3] Cancel"
            $pathChoice = Read-Host "`nSelect option [1-3]"
            if ($pathChoice -eq "1") {
                $ScrcpyDir = Prompt-ToolPath -ToolName "Scrcpy" -ExeName "scrcpy.exe" -ExistingPath ($ScrcpyDir)
                $Config | Add-Member -Name "ScrcpyPath" -Value ($ScrcpyDir) -MemberType NoteProperty -Force
                Save-Config ($Config)
                $env:Path = ("{0};{1}" -f $ScrcpyDir, $env:Path)
            } elseif ($pathChoice -eq "2") {
                $AdbDir = Prompt-ToolPath -ToolName "ADB (Platform-Tools)" -ExeName "adb.exe" -ExistingPath ($AdbDir)
                $Config | Add-Member -Name "AdbPath" -Value ($AdbDir) -MemberType NoteProperty -Force
                Save-Config ($Config)
                $env:Path = ("{0};{1}" -f $AdbDir, $env:Path)
            }
            continue
        }
        "9" {
            Write-Host "`nExiting." -ForegroundColor Yellow
            Exit
        }
        Default {
            Write-Host "`nInvalid selection." -ForegroundColor Red
        }
    }

    Write-Host "`nSession closed. Press any key to return to menu..." -ForegroundColor DarkGray
    [Console]::ReadKey($true) | Out-Null
}
