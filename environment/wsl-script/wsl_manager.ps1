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
    Write-Host "  [4] User Settings (List, Add, Delete, Fix Perms)"
    Write-Host "  [5] Exit"
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $choice = Read-Host "Select an option [1-5]"
    switch ($choice) {
        "1" { Invoke-ListWSL }
        "2" { Invoke-ImportWSL }
        "3" { Invoke-UnregisterWSL }
        "4" { Show-UserMenu }
        "5" { Exit }
        Default { Show-MainMenu }
    }
}

function Show-UserMenu {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "               WSL USER MANAGEMENT                 " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "  [1] List users in a WSL instance"
    Write-Host "  [2] Set or create default user"
    Write-Host "  [3] Delete a user"
    Write-Host "  [4] Fix user permissions (Home dir & Sudo)"
    Write-Host "  [5] Return to Main Menu"
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $choice = Read-Host "Select an option [1-5]"
    switch ($choice) {
        "1" { Invoke-ListUsersWSL }
        "2" { Invoke-SetupUserWSL }
        "3" { Invoke-DeleteUserWSL }
        "4" { Invoke-FixPermissionsWSL }
        "5" { Show-MainMenu }
        Default { Show-UserMenu }
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

function Get-WslDistroList {
    $wslOutput = wsl.exe --list --quiet
    $wslList = @()
    foreach ($line in $wslOutput) {
        if ($line -match '\S') {
            $cleanName = $line.Replace("*", "").Replace("`0", "").Trim()
            if ($cleanName -and $cleanName -notlike "NAME" -and $cleanName -notlike "The WSL*") {
                $wslList += $cleanName
            }
        }
    }
    return ,$wslList
}

function Select-WslDistro {
    param([string]$ActionDescription)
    $wslList = Get-WslDistroList
    
    if ($wslList.Count -eq 0) {
        Write-Host "[!] No WSL instances found." -ForegroundColor Yellow
        return $null
    }
    
    Write-Host "Fetching installed environments..."
    Write-Host "---------------------------------------------------"
    $i = 1
    foreach ($distro in $wslList) {
        Write-Host "  [$i] $distro"
        $i++
    }
    $cancelIndex = $wslList.Count + 1
    Write-Host "  [$cancelIndex] Cancel and return"
    Write-Host "---------------------------------------------------"
    Write-Host ""
    
    $selection = Read-Host "Select instance number to $ActionDescription"
    if ([string]::IsNullOrEmpty($selection) -or $selection -eq $cancelIndex) { 
        return $null 
    }
    
    if ($selection -match '^\d+$' -and [int]$selection -le $wslList.Count -and [int]$selection -gt 0) {
        return $wslList[[int]$selection - 1]
    } else {
        Write-Host "[!] Invalid selection." -ForegroundColor Red
        Start-Sleep -Seconds 2
        return $null
    }
}

function Configure-WslUserInternal {
    param([string]$DistroName, [string]$UserName)
    
    Write-Host "[*] Configuring user '$UserName' on $DistroName..." -ForegroundColor Yellow

    $checkUserCmd = "id -u $UserName 2>/dev/null"
    wsl.exe -d $DistroName -u root bash -c $checkUserCmd
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[*] User '$UserName' does not exist. Creating user..." -ForegroundColor Cyan
        $createUserCmd = "useradd -m -s /bin/bash $UserName"
        wsl.exe -d $DistroName -u root bash -c $createUserCmd
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[!] Failed to create user. Ensure distribution supports standard useradd." -ForegroundColor Red
            return $false
        }
        
        Write-Host "[*] Setting password for $UserName..." -ForegroundColor Cyan
        wsl.exe -d $DistroName -u root passwd $UserName
    } else {
        Write-Host "[*] User '$UserName' already exists." -ForegroundColor Green
    }

    Write-Host "[*] Granting sudo privileges..." -ForegroundColor Cyan
    wsl.exe -d $DistroName -u root bash -c "usermod -aG sudo $UserName 2>/dev/null || usermod -aG wheel $UserName 2>/dev/null"

    Write-Host "[*] Updating WSL default user configuration..." -ForegroundColor Cyan
    $wslConfCmd = "printf '[user]\ndefault=$UserName\n' > /etc/wsl.conf"
    wsl.exe -d $DistroName -u root bash -c $wslConfCmd

    $uid = wsl.exe -d $DistroName -u root bash -c "id -u $UserName"
    if ($uid -match '^\d+$') {
        $distroGuidsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss"
        if (Test-Path $distroGuidsPath) {
            Get-ChildItem $distroGuidsPath | ForEach-Object {
                $distroNamePath = Join-Path $_.PSPath "DistributionName"
                if ((Test-Path $distroNamePath) -and ((Get-ItemProperty $_.PSPath).DistributionName -eq $DistroName)) {
                    Set-ItemProperty -Path $_.PSPath -Name "DefaultUid" -Value [int]$uid
                }
            }
        }
    }
    return $true
}

function Invoke-ListUsersWSL {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "             LIST USERS IN WSL INSTANCE            " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $targetDistro = Select-WslDistro "inspect users"
    if (-not $targetDistro) { Show-UserMenu; return }
    
    Write-Host ""
    Write-Host "---------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Users in $targetDistro (UID >= 1000):" -ForegroundColor Cyan
    Write-Host "---------------------------------------------------"
    
    $userQuery = "awk -F: '($3 >= 1000 || $1 == \"root\") {print \"User: \" $1 \" (UID: \" $3 \") - Shell: \" $7}' /etc/passwd"
    wsl.exe -d $targetDistro -u root bash -c $userQuery
    
    Write-Host "---------------------------------------------------"
    Read-Host "Press Enter to return to User Menu..."
    Show-UserMenu
}

function Invoke-SetupUserWSL {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "           SET / CREATE DEFAULT USER               " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $targetDistro = Select-WslDistro "configure default user"
    if (-not $targetDistro) { Show-UserMenu; return }

    Write-Host ""
    $newUserName = Read-Host "Enter the username to create or set as default"
    if ([string]::IsNullOrWhiteSpace($newUserName)) {
        Write-Host "[!] Username cannot be empty." -ForegroundColor Red
        Start-Sleep -Seconds 2
        Show-UserMenu
        return
    }
    
    $newUserName = $newUserName.Trim().ToLower()
    Write-Host ""

    if (Configure-WslUserInternal -DistroName $targetDistro -UserName $newUserName) {
        Write-Host ""
        Write-Host "[SUCCESS] Default user successfully set to '$newUserName' for $targetDistro!" -ForegroundColor Green
        Write-Host "Restart instance using: wsl.exe --terminate $targetDistro" -ForegroundColor Yellow
    }
    Write-Host ""
    Read-Host "Press Enter to return to User Menu..."
    Show-UserMenu
}

function Invoke-DeleteUserWSL {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "                 DELETE USER FROM WSL              " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $targetDistro = Select-WslDistro "delete user from"
    if (-not $targetDistro) { Show-UserMenu; return }

    Write-Host ""
    $targetUser = Read-Host "Enter exact username to delete"
    if ([string]::IsNullOrWhiteSpace($targetUser) -or $targetUser -eq "root") {
        Write-Host "[!] Invalid or protected username." -ForegroundColor Red
        Start-Sleep -Seconds 2
        Show-UserMenu
        return
    }

    Write-Host ""
    Write-Host "---------------------------------------------------" -ForegroundColor Yellow
    Write-Host "[WARNING] Deleting user '$targetUser' from $targetDistro" -ForegroundColor Yellow
    Write-Host "---------------------------------------------------" -ForegroundColor Yellow
    $delHome = Read-Host "Do you also want to purge their home directory? (Y/N)"
    
    $delCmd = if ($delHome -ieq "Y") { "userdel -r $targetUser" } else { "userdel $targetUser" }
    
    wsl.exe -d $targetDistro -u root bash -c $delCmd
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] User '$targetUser' successfully deleted." -ForegroundColor Green
    } else {
        Write-Host "[!] Failed to delete user (user may not exist or is currently logged in)." -ForegroundColor Red
    }
    
    Read-Host "Press Enter to return to User Menu..."
    Show-UserMenu
}

function Invoke-FixPermissionsWSL {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "           FIX USER PERMISSIONS & SUDO             " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $targetDistro = Select-WslDistro "fix permissions on"
    if (-not $targetDistro) { Show-UserMenu; return }

    Write-Host ""
    $targetUser = Read-Host "Enter the username whose permissions need repair"
    if ([string]::IsNullOrWhiteSpace($targetUser)) {
        Write-Host "[!] Username cannot be empty." -ForegroundColor Red
        Start-Sleep -Seconds 2
        Show-UserMenu
        return
    }

    Write-Host ""
    Write-Host "[+] Repairing permissions for '$targetUser' on $targetDistro..." -ForegroundColor Yellow

    $fixHomeCmd = "if [ -d /home/$targetUser ]; then chown -R $targetUser:$targetUser /home/$targetUser && chmod 755 /home/$targetUser; fi"
    wsl.exe -d $targetDistro -u root bash -c $fixHomeCmd

    $fixSudoCmd = "usermod -aG sudo $targetUser 2>/dev/null || usermod -aG wheel $targetUser 2>/dev/null"
    wsl.exe -d $targetDistro -u root bash -c $fixSudoCmd

    Write-Host "[SUCCESS] Home directory ownership and sudo privileges successfully repaired for '$targetUser'." -ForegroundColor Green
    Write-Host ""
    
    Read-Host "Press Enter to return to User Menu..."
    Show-UserMenu
}

function Invoke-UnregisterWSL {
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "            UNREGISTER / DELETE WSL INSTANCE        " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $targetDelete = Select-WslDistro "delete"
    if (-not $targetDelete) { Show-MainMenu; return }
    
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

    Write-Host ""
    Write-Host "4. Default User Configuration" -ForegroundColor Cyan
    Write-Host "---------------------------------------------------"
    $configureUser = Read-Host "Do you want to set up a default user during this import? (Y/N)"
    $importUser = ""
    if ($configureUser -ieq "Y") {
        $importUser = Read-Host "Enter username to create/set as default"
        $importUser = $importUser.Trim().ToLower()
    }
    
    Clear-Host
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "                CONFIRM INSTALLATION                " -ForegroundColor Cyan
    Write-Host "===================================================" -ForegroundColor Cyan
    Write-Host "  Instance Name : $wslName"
    Write-Host "  Save Location : $targetDir"
    Write-Host "  Tarball File  : $tarFile"
    if (-not [string]::IsNullOrEmpty($importUser)) {
        Write-Host "  Default User  : $importUser" -ForegroundColor Green
    } else {
        Write-Host "  Default User  : root (Standard Tarball Default)" -ForegroundColor Yellow
    }
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

            # If user opted to configure a user during import, run configuration logic automatically
            if (-not [string]::IsNullOrEmpty($importUser)) {
                Write-Host ""
                Write-Host "[+] Applying post-import user setup..." -ForegroundColor Cyan
                Configure-WslUserInternal -DistroName $wslName -UserName $importUser
                Write-Host "[SUCCESS] User configuration applied!" -ForegroundColor Green
            }

            Write-Host ""
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