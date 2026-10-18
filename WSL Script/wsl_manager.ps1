# Ensure console output handles formatting cleanly
$Choices = @{}

function Show-MainMenu {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "               WSL AUTOMATED MANAGER               " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "  [1] List installed WSL distributions"
    Write-Host "  [2] Import a new WSL instance from tar.gz"
    Write-Host "  [3] Unregister / Delete a WSL instance"
    Write-Host "  [4] Exit"
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $choice = Read-Host "Select an option [1-4]"
    switch ($choice) {
        "1" { Invoke-ListWSL }
        "2" { Invoke-ImportWSL }
        "3" { Invoke-UnregisterWSL }
        "4" { Exit }
        Default { Show-MainMenu }
    }
}

function Invoke-ListWSL {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "             CURRENTLY INSTALLED DISTROS            " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    wsl.exe --list --verbose
    Write-Host ""
    Write-Host "===================================================" -ForegroundColor Cyan
    Read-Host "Press Enter to return to main menu..."
    Show-MainMenu
}

function Invoke-UnregisterWSL {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "            UNREGISTER / DELETE WSL INSTANCE        " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Fetching installed environments..."
    Write-Host "---------------------------------------------------"
    
    # Run WSL directly and clean up text output lines
    $wslOutput = wsl.exe --list --quiet
    
    $wslList = @()
    foreach ($line in $wslOutput) {
        if ($line -match '\S') {
            # Strip out any lingering null spacing or default indicators safely
            $cleanName = $line.Replace("*", "").Replace("`0", "").Trim()
            
            # Filter out headers, empty lines, or system error logs
            if ($cleanName -and $cleanName -notlike "NAME" -and $cleanName -notlike "The WSL*") {
                $wslList += $cleanName
            }
        }
    }
    
    if ($wslList.Count -eq 0) {
        Write-Host "[!] No WSL instances found to remove." -ForegroundColor Yellow
        Read-Host "Press Enter to return to main menu..."
        Show-MainMenu
        return
    }
    
    # Display the filtered names (perfectly gap-free)
    $i = 1
    foreach ($distro in $wslList) {
        Write-Host "  [$i] $distro"
        $i++
    }
    $cancelIndex = $wslList.Count + 1
    Write-Host "  [$cancelIndex] Cancel and return to menu"
    Write-Host "---------------------------------------------------"
    Write-Host ""
    
    $selection = Read-Host "Select the instance number to completely DELETE"
    if ([string]::IsNullOrEmpty($selection) -or $selection -eq $cancelIndex) { 
        Show-MainMenu 
        return
    }
    
    # Validate selection bounds securely against the true count
    if ($selection -match '^\d+$' -and [int]$selection -le $wslList.Count -and [int]$selection -gt 0) {
        $targetDelete = $wslList[[int]$selection - 1]
    } else {
        Write-Host "[!] Invalid selection." -ForegroundColor Red
        Start-Sleep -Seconds 2
        Invoke-UnregisterWSL
        return
    }
    
    Write-Host ""
    Write-Host "---------------------------------------------------" -ForegroundColor Yellow
    Write-Host "[WARNING] You selected: $targetDelete" -ForegroundColor Yellow
    Write-Host "This will permanently ERASE all data inside this instance." -ForegroundColor Yellow
    Write-Host "---------------------------------------------------" -ForegroundColor Yellow
    
    $confirm = Read-Host "Are you absolutely sure? (Y/N)"
    if ($confirm -ieq "Y") {
		Write-Host ""
		Write-Host "[+] Nuking $targetDelete..." -ForegroundColor Red
		wsl.exe --unregister "$targetDelete"
		Write-Host "[SUCCESS] Target destroyed." -ForegroundColor Green
    } else {
        Write-Host "[!] Deletion canceled." -ForegroundColor Yellow
    }
    Read-Host "Press Enter to continue..."
    Show-MainMenu
}

function Invoke-ImportWSL {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "             IMPORT NEW WSL FROM TARBALL            " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $wslName = Read-Host "1. Enter a unique name for this WSL instance"
    if ([string]::IsNullOrEmpty($wslName)) { Invoke-ImportWSL; return }
    $wslName = $wslName.Replace(" ", "-")
    
    Write-Host ""
    Write-Host "2. Where should the virtual hard disk be saved?"
    $defaultDir = "C:\WSL\$wslName"
    Write-Host "   [1] Default Location ($defaultDir)"
    Write-Host "   [2] Enter a custom path manually"
    
    # Automatically scan root of other drives for \WSL folder
    $locCount = 2
    $driveMappings = @{}
    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.IsReady -and (Test-Path "$(Join-Path $drive.Name "WSL")")) {
            if ($drive.Name -notlike "C:*") {
                $locCount++
                $scannedPath = Join-Path $drive.Name "WSL\$wslName"
                $driveMappings[$locCount] = $scannedPath
                Write-Host "   [$locCount] Use scanned path: $scannedPath"
            }
        }
    }
    Write-Host ""
    
    $locChoice = Read-Host "Select path option [1-$locCount]"
    if ($locChoice -eq "1") { 
        $targetDir = $defaultDir 
    }
    elseif ($locChoice -eq "2") {
        Write-Host ""
        $targetDir = Read-Host "Enter custom folder path (e.g., D:\WSL\BuildBox)"
    } else {
        $targetDir = $driveMappings[[int]$locChoice]
    }
    
    if ([string]::IsNullOrEmpty($targetDir)) {
        Write-Host "[!] Invalid location choice." -ForegroundColor Red
        Read-Host "Press Enter to try again..."
        Invoke-ImportWSL
        return
    }
    
    Write-Host ""
    Write-Host "3. Locating rootfs tarball files..." -ForegroundColor Cyan
    Write-Host "---------------------------------------------------"
    
    # Scan script directory and parent directory safely using object definitions
    $scriptDir = $PSScriptRoot
    $parentDir = Split-Path $scriptDir -Parent
    
    $tarFiles = @(Get-ChildItem -Path $scriptDir, $parentDir -Filter "*.tar.gz" -ErrorAction SilentlyContinue)
    
    if ($tarFiles.Count -eq 0) {
        Write-Host "[!] No .tar.gz files found automatically." -ForegroundColor Yellow
        $tarFile = Read-Host "Paste the full absolute path to your .tar.gz file"
    } else {
        $fCount = 1
        foreach ($file in $tarFiles) {
            if ($file.DirectoryName -eq $scriptDir) {
                Write-Host "  [$fCount] $($file.Name) *(in script folder)*"
            } else {
                Write-Host "  [$fCount] $($file.Name) *(in main \WSL folder)*"
            }
            $fCount++
        }
        Write-Host "  [$fCount] Enter/Paste a custom file path manually"
        Write-Host "---------------------------------------------------"
        Write-Host ""
        
        $fileChoice = Read-Host "Select a file number from the list above"
        if ($fileChoice -eq $fCount) {
            Write-Host ""
            $tarFile = Read-Host "Paste the full path to your .tar.gz file"
        } else {
            $tarFile = $tarFiles[[int]$fileChoice - 1].FullName
        }
    }
    
    if (-not (Test-Path $tarFile)) {
        Write-Host "[!] Tarball file path not found. Operation aborted." -ForegroundColor Red
        Read-Host "Press Enter to return to main menu..."
        Show-MainMenu
        return
    }
    
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "                CONFIRM INSTALLATION                " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "  Instance Name : $wslName"
    Write-Host "  Save Location : $targetDir"
    Write-Host "  Tarball File  : $tarFile"
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $confirm = Read-Host "Proceed with the import? (Y/N)"
    if ($confirm -ieq "Y") {
        if (-not (Test-Path $targetDir)) {
            Write-Host ""
            Write-Host "[+] Creating deployment directory..." -ForegroundColor Yellow
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        }
        Write-Host ""
        Write-Host "[+] Importing $wslName... This may take a few minutes." -ForegroundColor Green
        Write-Host ""
        
        wsl.exe --import $wslName $targetDir $tarFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "[SUCCESS] Import complete!" -ForegroundColor Green
            Write-Host "To boot into your environment, run: wsl -d $wslName" -ForegroundColor Green
        } else {
            Write-Host "[!] Something went wrong during the WSL execution setup." -ForegroundColor Red
        }
    } else {
        Write-Host "[!] Deployment canceled by user." -ForegroundColor Yellow
    }
    
    Read-Host "Press Enter to return to main menu..."
    Show-MainMenu
}

# Kick off the menu loop immediately on startup
Show-MainMenu