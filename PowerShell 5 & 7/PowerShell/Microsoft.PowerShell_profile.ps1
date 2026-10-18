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
        # Read lines, ignore empty lines and comment lines starting with #
        return Get-Content $Global:SearchPathsFile | Where-Object { 
            $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") 
        } | ForEach-Object { $_.Trim() }
    } else {
        # Auto-create the search paths file with instructions if it doesn't exist yet
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
    if ($IsMenuTrigger) {
        $SearchDirs = Get-VenvSearchPaths
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

    # 2) Explicit argument mode (Stays intact)
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

    # 3) Local fallback: .venv, venv, or any custom local venv (in cwd or project root)
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
        [string]$Path = ".venv",

        [Parameter(Mandatory = $false)]
        [Alias("h", "?")]
        [switch]$Help
    )

    # If user asks for help, show help
    if ($Help -or ($Path -ine "" -and ($Path -in @("-h", "--h", "-help", "--help", "help", "/?", "-?")))) {
        Show-VenvHelp
        return
    }

    # If user tries to pass any menu flag to mkvenv/make-venv, pass it to .venv instead
    if ($Path -ine "" -and ($Path -in @("-m", "-M", "-Menu", "-menu"))) {
        .venv -Menu
        return
    }

    Write-Host "Creating Python virtual environment at '$Path'..." -ForegroundColor Yellow
    python -m venv $Path
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Environment created successfully! Activating..." -ForegroundColor Green
        if ($Path -eq ".venv") {
            .venv
        } else {
            .venv $Path
        }
    } else {
        Write-Host "Error: Failed to create virtual environment." -ForegroundColor Red
    }
}

Set-Alias -Name mkvenv -Value New-Venv
Set-Alias -Name make-venv -Value New-Venv