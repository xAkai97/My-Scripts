# Requires -RunAsAdministrator
# General service tool: reads services from services-config.json and sets enabled entries to the configured startup type.

param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "services-config.json")
)

# Verify the configuration file exists[cite: 2]
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found: $ConfigPath"[cite: 2]
    Read-Host "Press Enter to exit"
    exit
}

# Load and filter only the enabled services from the JSON file[cite: 2]
$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json[cite: 2]
$services = $config.services | Where-Object { $_.enabled -eq $true }[cite: 2]

if ($null -eq $services -or $services.Count -eq 0) {
    Write-Host "No enabled services found in the configuration." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}

function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "         SERVICE MANAGEMENT TOOL         " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "1. Set enabled services to Manual"
    Write-Host "2. Stop enabled services (if running)"
    Write-Host "3. Exit"
    Write-Host "=========================================" -ForegroundColor Cyan
}

do {
    Show-Menu
    $choice = Read-Host "Select an option [1-3]"

    switch ($choice) {
        "1" {
            Write-Host "`n[ Configuring Startup Type to Manual ]" -ForegroundColor Cyan
            foreach ($item in $services) {
                try {
                    # Verify service exists[cite: 2]
                    $svc = Get-Service -Name $item.name -ErrorAction Stop[cite: 2]
                    
                    # Set startup type to Manual
                    Set-Service -Name $item.name -StartupType "Manual" -ErrorAction Stop[cite: 1, 2]
                    Write-Host "Successfully set $($item.name) to Manual." -ForegroundColor Green
                }
                catch {
                    Write-Host "Error updating $($item.name): $($_.Exception.Message)" -ForegroundColor Red[cite: 2]
                }
            }
            Read-Host "`nPress Enter to return to the menu..."
        }

        "2" {
            Write-Host "`n[ Stopping Running Services ]" -ForegroundColor Cyan
            foreach ($item in $services) {
                try {
                    # Verify service exists[cite: 2]
                    $svc = Get-Service -Name $item.name -ErrorAction Stop[cite: 2]
                    
                    if ($svc.Status -eq 'Running') {[cite: 2]
                        Write-Host "Stopping $($item.name)..." -ForegroundColor Yellow
                        Stop-Service -Name $item.name -Force -ErrorAction Stop[cite: 2]
                        $svc.WaitForStatus('Stopped', '00:00:20')[cite: 2]
                        Write-Host "Successfully stopped $($item.name)." -ForegroundColor Green
                    } else {
                        Write-Host "$($item.name) is already stopped." -ForegroundColor DarkGray
                    }
                }
                catch {
                    Write-Host "Error stopping $($item.name): $($_.Exception.Message)" -ForegroundColor Red[cite: 2]
                }
            }
            Read-Host "`nPress Enter to return to the menu..."
        }

        "3" {
            Write-Host "`nExiting tool." -ForegroundColor Cyan
            break
        }

        default {
            Write-Host "`nInvalid choice. Please choose 1, 2, or 3." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
} while ($choice -ne "3")