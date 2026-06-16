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
    Write-Host "Activating local venv..." -ForegroundColor Green
    if (Test-Path ".\venv\Scripts\Activate.ps1") {
        . .\venv\Scripts\Activate.ps1
    } else {
        Write-Host "Error: venv environment not found in current directory." -ForegroundColor Red
    }
}

function .venv {
    param(
        [string]$EnvName
    )
    
    # 1) Explicit argument mode
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

    # 2) Local fallback: .venv then venv directories
    foreach ($LocalName in @(".venv", "venv")) {
        $LocalScript = ".\$LocalName\Scripts\Activate.ps1"
        if (Test-Path $LocalScript) {
            Activate-VenvPath -ActivateScript $LocalScript -DisplayName $LocalName | Out-Null
            return
        }
    }

    $cwd = (Get-Location).Path

    # 3) Project-mapped external env fallback (loads from venv-mappings.json)
    $ProjectVenvMap = Get-ProjectVenvMap
    foreach ($ProjectRoot in $ProjectVenvMap.Keys) {
        if ($cwd.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $EnvRoot = $ProjectVenvMap[$ProjectRoot]
            $MappedScript = Join-Path $EnvRoot "Scripts\Activate.ps1"
            if (Activate-VenvPath -ActivateScript $MappedScript -DisplayName $EnvRoot) { return }
        }
    }

    # 4) Dynamic central folder lookup (Fuzzy matching on paths in venv-search-paths.txt)
    $ProjectName = Split-Path $cwd -Leaf
    $CleanProjectName = $ProjectName.Replace("-", "").Replace("_", "")
    $SearchPaths = Get-VenvSearchPaths
    
    foreach ($Dir in $SearchPaths) {
        if (Test-Path $Dir) {
            # Find first folder matching or containing the project directory name
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