# =====================================================================
# 1. Shared Helpers & Configuration (Shared for PS 5 and PS 7)
# =====================================================================

$Global:ProfileDir = Join-Path $HOME "Documents\PowerShell"

# Create the shared folder if it doesn't exist yet
if (-not (Test-Path $Global:ProfileDir)) {
    New-Item -ItemType Directory -Path $Global:ProfileDir -Force | Out-Null
}

# Configuration file paths (placed in the same folder as your PowerShell Profile)
$Global:SearchPathsFile = Join-Path $Global:ProfileDir "venv-search-paths.txt"

# Shared helper for activation
function Invoke-VenvPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ActivateScript,
        [string]$DisplayName = "venv"
    )

    if (Test-Path $ActivateScript) {
        Write-Host "Activating virtual environment '$DisplayName'..." -ForegroundColor Green
        . $ActivateScript
        return $true
    }

    Write-Host "Error: Virtual environment not found at $ActivateScript" -ForegroundColor Red
    return $false
}

# Dynamic Loader for search paths
function Get-VenvSearchPaths {
    if (Test-Path $Global:SearchPathsFile) {
        return Get-Content $Global:SearchPathsFile | Where-Object { 
            $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") 
        } | ForEach-Object { $_.Trim() }
    } else {
        try {
            if (-not (Test-Path $Global:ProfileDir)) {
                New-Item -ItemType Directory -Path $Global:ProfileDir -Force | Out-Null
            }
            $Instructions = @(
                "# Enter directories to search for virtual environments, one per line.",
                "# Lines starting with '#' are ignored.",
                "# Examples:",
                "# D:\PythonEnvs",
                "# F:\PythonEnvs"
            )
            $Instructions | Out-File $Global:SearchPathsFile -Encoding utf8
            Write-Host "Created search paths config file at: $Global:SearchPathsFile" -ForegroundColor Yellow
        } catch {}
    }
    return @()
}

# Add a central virtual environment search folder to the config file
function Add-VenvSearchPath {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Path
    )
    
    if (Test-Path $Path) {
        $Path = (Resolve-Path $Path).Path
    } else {
        Write-Warning "Search directory '$Path' does not exist."
    }

    $SearchPathsList = @()
    if (Test-Path $Global:SearchPathsFile) {
        $SearchPathsList = @(Get-Content $Global:SearchPathsFile)
    }
    
    if ($Path -notin $SearchPathsList) {
        $SearchPathsList += $Path
        $SearchPathsList | Out-File $Global:SearchPathsFile -Encoding utf8
        Write-Host "Added '$Path' to central venv search paths." -ForegroundColor Green
    }
}

# =====================================================================
# 2. Main Functions (venv & .venv)
# =====================================================================

function Show-VenvHelp {
    Write-Host @"

Python Virtual Environment Manager (.venv / venv)
==================================================

Commands & Usage:
  venv, .venv                   Auto-detect and activate virtual environment.
                                Checks local (.venv, venv, custom), then central search paths.
  venv, .venv -m, -Menu         Open interactive CLI menu to create or select environments.
  venv, .venv <Name|Path>       Activate specific environment by name (central path) or path.
  venv, .venv -h, -Help, -?     Display this help reference.

Creation Commands:
  mkvenv, make-venv [Path]      Create a virtual environment (default: .venv) and activate it.
  mkvenv -v <Ver>               Target specific Python version (e.g. mkvenv -v 3.14).
  mkvenv -m                     Open interactive creation menu.

Central Search Paths:
  Add-VenvSearchPath <Path>     Add a central search directory (e.g. D:\PythonEnvs).
  Get-VenvSearchPaths           List configured search paths.

Configuration:
  Search Paths File: $Global:SearchPathsFile

"@ -ForegroundColor Cyan
}

Set-Alias -Name venv -Value .venv

function .venv {
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$EnvName,

        [Parameter(Mandatory = $false)]
        [switch]$Menu,

        [Parameter(Mandatory = $false)]
        [Alias("h", "?")]
        [switch]$Help
    )
    
    # Check if help is requested
    $IsHelpTrigger = $Help -or ($EnvName -ine "" -and ($EnvName -in @("-h", "--h", "-help", "--help", "help", "/?", "-?")))
    if ($IsHelpTrigger) {
        Show-VenvHelp
        return
    }

    # Check if the text argument matches any of the menu flags
    $IsMenuTrigger = $Menu -or ($EnvName -ine "" -and ($EnvName -in @("-m", "-M", "-Menu", "-menu")))

    # 1) Menu Selection Mode
    if ($IsMenuTrigger) { $SearchDirs = Get-VenvSearchPaths
		$AvailableEnvs = [System.Collections.Generic.List[PSCustomObject]]::new()
        
        # Scan for existing environments in central search paths
        foreach ($Dir in $SearchDirs) {
            if (Test-Path $Dir) {
                $SubDirs = Get-ChildItem -Path $Dir -Directory
                foreach ($Sub in $SubDirs) {
                    if (Test-Path (Join-Path $Sub.FullName "Scripts\Activate.ps1")) {
                        $AvailableEnvs.Add([PSCustomObject]@{
                            Name       = $Sub.Name
                            FullPath   = $Sub.FullName
                            ParentDir  = $Dir
                            Type       = "Existing"
                        })
                    }
                }
            }
        }

        # Build the Interactive Menu
        Write-Host "`n--- Virtual Environment Menu ---" -ForegroundColor Cyan
        $MenuIndex = 1

        # OPTION 1: Always Current Folder Creation
        Write-Host " [$MenuIndex] Create brand new venv in CURRENT folder" -ForegroundColor Yellow
        $MenuIndex++
        
        # List existing environments
        if ($AvailableEnvs.Count -gt 0) {
            Write-Host "`nExisting Environments:" -ForegroundColor Green
            foreach ($EnvItem in $AvailableEnvs) {
                Write-Host " [$MenuIndex] $($EnvItem.Name) ($($EnvItem.ParentDir))"
                $EnvItem | Add-Member -NotePropertyName "MenuID" -NotePropertyValue $MenuIndex 
				$MenuIndex++
            }
        }

        # List central paths for alternative remote creation
        Write-Host "`nCreate New Environment In Central Path:" -ForegroundColor Yellow
        $CreationPaths = @{}
        foreach ($Dir in $SearchDirs) {
            if (Test-Path $Dir) {
                Write-Host " [$MenuIndex] New venv in -> $Dir"
                $CreationPaths[$MenuIndex] = $Dir
                $MenuIndex++
            }
        }

        Write-Host " [q] Cancel / Exit" -ForegroundColor Red
        Write-Host ""

        $Selection = Read-Host "Select an option [1-$($MenuIndex - 1)]"
        
        if ($Selection -eq 'q' -or [string]::IsNullOrWhiteSpace($Selection)) {
            Write-Host "Operation cancelled." -ForegroundColor Gray
            return
        }

        if ($Selection -match '^\d+$') {
            $SelectedIndex = [int]$Selection
            
            # Choice 1: Current Folder Local Venv
            if ($SelectedIndex -eq 1) {
                $InputName = Read-Host "Set folder name for your local environment [1: .venv or Enter Custom Name]"
                if ($InputName -eq "q" -or $InputName -eq "quit" -or $InputName -eq "exit") {
                    Write-Host "Operation cancelled." -ForegroundColor Gray
                    return
                }
                if ([string]::IsNullOrWhiteSpace($InputName) -or $InputName -eq "1") {
                    $NewName = ".venv"
                } else {
                    $NewName = $InputName
                }
                New-Venv -Path $NewName
                return
            }

            # Choice: Existing environment activation
            $ChosenEnv = $AvailableEnvs | Where-Object { $_.MenuID -eq $SelectedIndex }
            if ($ChosenEnv) {
                .venv $ChosenEnv.FullPath
                return
            }

            # Choice: Create environment inside a central search path
            if ($CreationPaths.ContainsKey($SelectedIndex)) {
                $BasePath = $CreationPaths[$SelectedIndex]
                $CurrentFolder = Split-Path (Get-Location).Path -Leaf
                $InputName = Read-Host "Set folder name for your new environment [1: $CurrentFolder or Enter Custom Name]"
                if ($InputName -eq "q" -or $InputName -eq "quit" -or $InputName -eq "exit") {
                    Write-Host "Operation cancelled." -ForegroundColor Gray
                    return
                }
                if ([string]::IsNullOrWhiteSpace($InputName) -or $InputName -eq "1") {
                    $NewName = $CurrentFolder
                } else {
                    $NewName = $InputName
                }
                New-Venv -Path (Join-Path $BasePath $NewName)
                return
            }

            Write-Host "Invalid menu selection." -ForegroundColor Red
            return
        } else {
            Write-Host "Invalid input." -ForegroundColor Red
            return
        }
    }

    # 2) Explicit argument mode
    if ($EnvName -ne "") {
        if ([System.IO.Path]::IsPathRooted($EnvName)) {
            $DirectScript = if ($EnvName.EndsWith("Activate.ps1")) { $EnvName } else { Join-Path $EnvName "Scripts\Activate.ps1" }
            if (Invoke-VenvPath -ActivateScript $DirectScript -DisplayName $EnvName) { return }
        }

        $RelativeScript = ".\$EnvName\Scripts\Activate.ps1"
        if (Invoke-VenvPath -ActivateScript $RelativeScript -DisplayName $EnvName) { return }

        Write-Host "Error: Virtual environment '$EnvName' not found." -ForegroundColor Red
        return
    }

    $cwd = (Get-Location).Path

    # Resolve project root (checks parent directories for .git, pyproject.toml, or requirements.txt)
    $ProjectRoot = $cwd
    $CheckDir = $cwd
    while ($CheckDir) {
        if ((Test-Path (Join-Path $CheckDir ".git")) -or 
            (Test-Path (Join-Path $CheckDir "pyproject.toml")) -or 
            (Test-Path (Join-Path $CheckDir "requirements.txt"))) {
            $ProjectRoot = $CheckDir
            break
        }
        $Parent = Split-Path $CheckDir -Parent
        if ($Parent -eq $CheckDir -or [string]::IsNullOrWhiteSpace($Parent)) { break }
        $CheckDir = $Parent
    }

    # 3) Local fallback: .venv, venv, or any custom local venv
    $CandidateDirs = @($cwd)
    if ($ProjectRoot -ne $cwd) {
        $CandidateDirs += $ProjectRoot
    }

    foreach ($BaseDir in $CandidateDirs) {
        foreach ($LocalName in @(".venv", "venv")) {
            $LocalScript = Join-Path $BaseDir "$LocalName\Scripts\Activate.ps1"
            if (Test-Path $LocalScript) {
                Invoke-VenvPath -ActivateScript $LocalScript -DisplayName $LocalName | Out-Null
                return
            }
        }

        $LocalCustomVenv = Get-ChildItem -Path $BaseDir -Directory -ErrorAction SilentlyContinue | Where-Object {
            Test-Path (Join-Path $_.FullName "Scripts\Activate.ps1")
        } | Select-Object -First 1

        if ($LocalCustomVenv) {
            $LocalScript = Join-Path $LocalCustomVenv.FullName "Scripts\Activate.ps1"
            Invoke-VenvPath -ActivateScript $LocalScript -DisplayName $LocalCustomVenv.Name | Out-Null
            return
        }
    }

    # 4) Dynamic central folder lookup (matches project root name against search paths)
    $ProjectName = Split-Path $ProjectRoot -Leaf
    $CleanProjectName = $ProjectName.Replace("-", "").Replace("_", "")
    $SearchPaths = Get-VenvSearchPaths
    
    foreach ($Dir in $SearchPaths) {
        if (Test-Path $Dir) {
            $Match = Get-ChildItem -Path $Dir -Directory | Where-Object { 
                $CleanDirName = $_.Name.Replace("-", "").Replace("_", "")
                $_.Name -like "$ProjectName*" -or 
                $ProjectName -like "$($_.Name)*" -or
                $CleanDirName -like "*$CleanProjectName*"
            } | Select-Object -First 1

            if ($Match) {
                $MappedScript = Join-Path $Match.FullName "Scripts\Activate.ps1"
                if (Invoke-VenvPath -ActivateScript $MappedScript -DisplayName $Match.Name) { return }
            }
        }
    }

    Write-Host "Error: Virtual environment not found." -ForegroundColor Red
}

# =====================================================================
# 3. Environment Creation Methods
# =====================================================================

function New-Venv {
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [Alias("v")]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [Alias("h", "?")]
        [switch]$Help
    )

    # 1. Help & Menu Passthroughs
    if ($Help -or ($Path -ine "" -and ($Path -in @("-h", "--h", "-help", "--help", "help", "/?", "-?")))) {
        Show-VenvHelp
        return
    }

    if ($Path -ine "" -and ($Path -in @("-m", "-M", "-Menu", "-menu"))) {
        .venv -Menu
        return
    }

    $cwd = (Get-Location).Path
    $TargetDir = $Path

    # 2. Detect Installed Python Versions via the Windows Python Launcher (py -0)
    $PyLauncher = Get-Command -Name "py" -ErrorAction SilentlyContinue
    $PythonCmd = "python"
    $SelectedTag = ""

    if ($PyLauncher) {
        $RawLines = @(& py -0 2>$null | Where-Object { $_ -notmatch 'Active virtual environment' })
        $VersionEntries = @()

        for ($idx = 0; $idx -lt $RawLines.Count; $idx++) {
            $CurrentLine = $RawLines[$idx]
            if ($CurrentLine -match '-(?:V:)?(\d+\.\d+)') {
                $VersionEntries += [PSCustomObject]@{
                    Tag       = $Matches[1]
                    IsDefault = ($CurrentLine -match '\*')
                }
            }
        }

        # Explicit version parameter passed: make-venv -v 3.14
        if (-not [string]::IsNullOrWhiteSpace($Version)) {
            $TargetTag = $Version.TrimStart("-").Replace("V:", "")
            $PythonCmd = "py -$TargetTag"
            $SelectedTag = " (Python $TargetTag)"
        }
        # Multi-version interactive selection prompt
        elseif ($VersionEntries.Count -gt 1) {
            Write-Host "`nMultiple Python versions detected:" -ForegroundColor Cyan
            for ($k = 0; $k -lt $VersionEntries.Count; $k++) {
				$Entry = $VersionEntries[$k]
                $DefaultLabel = if ($Entry.IsDefault) { " (Default)" } else { "" }
                Write-Host " [$($k + 1)] Python $($Entry.Tag)$DefaultLabel"
            }
            Write-Host " [d] Use System Default"

            $PyChoice = Read-Host "`nSelect Python version [1-$($VersionEntries.Count)] or press Enter for default"
            if ($PyChoice -match '^\d+$' -and [int]$PyChoice -ge 1 -and [int]$PyChoice -le $VersionEntries.Count) {
                $ChosenVer = $VersionEntries[[int]$PyChoice - 1].Tag
                $PythonCmd = "py -$ChosenVer"
                $SelectedTag = " (Python $ChosenVer)"
            }
        }
    }

    # 3. Remote / Network Drive Detection
    $IsNetworkPath = $false
    if ($cwd.StartsWith("\\")) {
        $IsNetworkPath = $true
    } elseif ($cwd -match '^([A-Za-z]):') {
        $DriveLetter = $Matches[1]
        $DriveInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($DriveLetter):'" -ErrorAction SilentlyContinue
        if ($DriveInfo -and $DriveInfo.DriveType -eq 4) {
            $IsNetworkPath = $true
        }
    }

    # 4. Handle Remote Routing
    if ($IsNetworkPath -and ([string]::IsNullOrWhiteSpace($TargetDir) -or -not [System.IO.Path]::IsPathRooted($TargetDir))) {
        Write-Host "`n[!] Warning: You are working on a network drive ($cwd)." -ForegroundColor Yellow
        Write-Host "Creating Python virtual environments on remote/SMB drives causes file-lock and path issues." -ForegroundColor DarkYellow

		$AvailablePaths = @(Get-VenvSearchPaths | Where-Object { Test-Path -Path $_ })
        $ChosenBasePath = $null

        if ($AvailablePaths.Count -eq 1) { $Choice = Read-Host "`nUse configured central location '$($AvailablePaths[0])'? [Y/n/custom]"
            if ($Choice -match '^(c|custom)$') {
                $ChosenBasePath = Read-Host "Enter custom local directory"
            } elseif ($Choice -match '^(n|no)$') {
                $ChosenBasePath = $null
            } else {
                $ChosenBasePath = $AvailablePaths[0]
            }
        } elseif ($AvailablePaths.Count -gt 1) {
            Write-Host "`nConfigured Central Paths:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $AvailablePaths.Count; $i++) {
                Write-Host " [$($i + 1)] $($AvailablePaths[$i])"
            }
            Write-Host " [c] Enter a custom path"
            Write-Host " [r] Keep on remote drive anyway"
            Write-Host " [q] Cancel"

            $Selection = Read-Host "`nSelect an option [1-$($AvailablePaths.Count)]"
            if ($Selection -eq 'q') {
                Write-Host "Operation cancelled." -ForegroundColor Gray
                return
            } elseif ($Selection -eq 'c') {
                $ChosenBasePath = Read-Host "Enter custom directory"
            } elseif ($Selection -eq 'r') {
                $ChosenBasePath = $null
            } elseif ($Selection -match '^\d+$' -and [int]$Selection -ge 1 -and [int]$Selection -le $AvailablePaths.Count) {
                $ChosenBasePath = $AvailablePaths[[int]$Selection - 1]
            }
        } else {
            $PromptCustom = Read-Host "`nNo local search paths configured. Enter a local folder (e.g. D:\PythonEnvs) or press Enter to stay on remote"
            if (-not [string]::IsNullOrWhiteSpace($PromptCustom)) {
                $ChosenBasePath = $PromptCustom
            }
        }

        if ($ChosenBasePath) {
            if (-not (Test-Path $ChosenBasePath)) {
                New-Item -ItemType Directory -Path $ChosenBasePath -Force | Out-Null
            }
            $FolderLeaf = (Get-Item -LiteralPath $cwd).Name
            if ([string]::IsNullOrWhiteSpace($FolderLeaf)) {
                $FolderLeaf = Split-Path $cwd -Leaf
            }

            $EnvName = if (-not [string]::IsNullOrWhiteSpace($TargetDir)) { $TargetDir } else { $FolderLeaf }
			$TargetDir = Join-Path -Path $ChosenBasePath -ChildPath $EnvName
        }
    }

    if ([string]::IsNullOrWhiteSpace($TargetDir)) { $TargetDir = ".venv"
    }

    # 5. Overwrite Protection & Auto-Deactivation
    if ($env:VIRTUAL_ENV) {
        Write-Host "Deactivating current virtual environment ($env:VIRTUAL_ENV)..." -ForegroundColor Yellow
        deactivate
    }

    $ExtraArgs = @()
    if (Test-Path (Join-Path $TargetDir "Scripts\python.exe")) {
        $Recreate = Read-Host "Environment already exists at '$TargetDir'. Overwrite/Clear? [y/N]"
        if ($Recreate -notmatch '^(y|yes)$') {
            Write-Host "Re-creation cancelled. Activating existing environment..." -ForegroundColor Yellow
            .venv $TargetDir
            return
        }
        $ExtraArgs += "--clear"
    }

    # 6. Environment Execution
    Write-Host "Creating Python virtual environment$SelectedTag at '$TargetDir'..." -ForegroundColor Yellow
    
    if ($PythonCmd -like "py *") {
        $VersionFlag = $PythonCmd.Split(" ")[1]
        & py $VersionFlag -m venv "$TargetDir" @ExtraArgs
    } else {
        & python -m venv "$TargetDir" @ExtraArgs
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Environment created successfully! Activating..." -ForegroundColor Green
        
        .venv $TargetDir
    } else {
        Write-Host "Error: Failed to create virtual environment." -ForegroundColor Red
    }
}

Set-Alias -Name mkvenv -Value New-Venv
Set-Alias -Name make-venv -Value New-Venv