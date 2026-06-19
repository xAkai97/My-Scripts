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
$Global:MappingsFile = Join-Path $Global:ProfileDir "venv-mappings.json"

# Shared helper for activation
function Activate-VenvPath {
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

# Dynamic Loader for manual mappings config
function Get-ProjectVenvMap {
    if (Test-Path $Global:MappingsFile) {
        try {
            $Json = Get-Content $Global:MappingsFile -Raw -ErrorAction SilentlyContinue
            if ($Json) {
                $Data = ConvertFrom-Json $Json
                $Map = @{}
                foreach ($Prop in $Data.PSObject.Properties) {
                    $Map[$Prop.Name] = $Prop.Value
                }
                return $Map
            }
        } catch {
            Write-Warning "Could not parse mapping file at $Global:MappingsFile"
        }
    }
    return @{}
}

# Helper command to quickly map a project folder to a venv (saves to mappings JSON)
function Register-ProjectVenv {
    param(
        [Parameter(Position = 0)]
        [string]$ProjectRoot = (Get-Location).Path,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$VenvPath
    )
    
    $ProjectRoot = (Resolve-Path $ProjectRoot).Path
    if (Test-Path $VenvPath) {
        $VenvPath = (Resolve-Path $VenvPath).Path
    } else {
        Write-Warning "Target path '$VenvPath' does not exist."
    }

    $Map = Get-ProjectVenvMap
    $Map[$ProjectRoot] = $VenvPath

    try {
        $Map | ConvertTo-Json | Out-File $Global:MappingsFile -Encoding utf8
        Write-Host "Successfully mapped '$ProjectRoot' to '$VenvPath' in $Global:MappingsFile" -ForegroundColor Green
    } catch {
        Write-Host "Error saving mappings: $_" -ForegroundColor Red
    }
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

    $Config = Get-VenvSearchPaths # Just returns paths array
    $SearchPathsList = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $Global:SearchPathsFile) {
        $SearchPathsList.AddRange((Get-Content $Global:SearchPathsFile))
    }
    
    if (-not $SearchPathsList.Contains($Path)) {
        $SearchPathsList.Add($Path)
        $SearchPathsList | Out-File $Global:SearchPathsFile -Encoding utf8
        Write-Host "Added '$Path' to central venv search paths." -ForegroundColor Green
    }
}

# =====================================================================
# 2. Main Functions (venv & .venv)
# =====================================================================

function venv {
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$EnvName
    )

    # If menu flags are passed to venv, forward them to .venv
    if ($EnvName -ine "" -and ($EnvName -eq "-m" -or $EnvName -eq "-M" -or $EnvName -eq "-Menu" -or $EnvName -eq "-menu")) {
        .venv -Menu
        return
    }

    Write-Host "Activating local venv..." -ForegroundColor Green
    if (Test-Path ".\venv\Scripts\Activate.ps1") {
        . .\venv\Scripts\Activate.ps1
    } else {
        Write-Host "Error: venv environment not found in current directory." -ForegroundColor Red
    }
}

function .venv {
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$EnvName,

        [Parameter(Mandatory = $false)]
        [switch]$Menu
    )
    
    # Check if the text argument matches any of the menu flags
    $IsMenuTrigger = $EnvName -ine "" -and ($EnvName -eq "-m" -or $EnvName -eq "-M" -or $EnvName -eq "-Menu" -or $EnvName -eq "-menu")

    # 1) Menu Selection Mode
    if ($Menu -or $IsMenuTrigger) {
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
        Write-Host " [$MenuIndex] Create brand new '.venv' in CURRENT folder" -ForegroundColor Yellow
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
                New-Venv -Path ".venv"
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
                $NewName = Read-Host "Enter a folder name for your new environment"
                if ([string]::IsNullOrWhiteSpace($NewName)) {
                    Write-Host "Invalid name. Cancelling." -ForegroundColor Red
                    return
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
            if (Activate-VenvPath -ActivateScript $DirectScript -DisplayName $EnvName) { return }
        }

        $RelativeScript = ".\$EnvName\Scripts\Activate.ps1"
        if (Activate-VenvPath -ActivateScript $RelativeScript -DisplayName $EnvName) { return }

        Write-Host "Error: Virtual environment '$EnvName' not found." -ForegroundColor Red
        return
    }

    # 3) Local fallback: .venv then venv directories
    foreach ($LocalName in @(".venv", "venv")) {
        $LocalScript = ".\$LocalName\Scripts\Activate.ps1"
        if (Test-Path $LocalScript) {
            Activate-VenvPath -ActivateScript $LocalScript -DisplayName $LocalName | Out-Null
            return
        }
    }

    $cwd = (Get-Location).Path

    # 4) Project-mapped external env fallback
    $ProjectVenvMap = Get-ProjectVenvMap
    foreach ($ProjectRoot in $ProjectVenvMap.Keys) {
        if ($cwd.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $EnvRoot = $ProjectVenvMap[$ProjectRoot]
            $MappedScript = Join-Path $EnvRoot "Scripts\Activate.ps1"
            if (Activate-VenvPath -ActivateScript $MappedScript -DisplayName $EnvRoot) { return }
        }
    }

    # 5) Dynamic central folder lookup
    $ProjectName = Split-Path $cwd -Leaf
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
                if (Activate-VenvPath -ActivateScript $MappedScript -DisplayName $Match.Name) { return }
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
        [string]$Path = ".venv"
    )

    # If user tries to pass any menu flag to mkvenv/make-venv, pass it to .venv instead
    if ($Path -ine "" -and ($Path -eq "-m" -or $Path -eq "-M" -or $Path -eq "-Menu" -or $Path -eq "-menu")) {
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