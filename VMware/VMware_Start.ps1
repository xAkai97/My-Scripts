# Requires -RunAsAdministrator
#
# Shortcut Settings: Set Run As Administrator
# Target: %USERPROFILE%\AppData\Local\Microsoft\WindowsApps\Microsoft.PowerShell_8wekyb3d8bbwe\pwsh.exe -ExecutionPolicy Bypass -File "%USERPROFILE%\Documents\Scripts\VMware\VMware_Start.ps1"
# Start in: %USERPROFILE%\Documents\Scripts\VMware\

$services = @("VMAuthdService", "VMnetDHCP", "VMware NAT Service", "VMUSBArbService")

Write-Host "Starting VMware Services in parallel..." -ForegroundColor Cyan

# Run the parallel loop and capture any errors/failures into an array
$errors = $services | ForEach-Object -Parallel {
    try {
        Start-Service -Name $_ -ErrorAction Stop
        Write-Host "Successfully started: $_" -ForegroundColor Green
        return $false # No error for this service
    } catch {
        Write-Warning "Failed to start $_ : $_"
        return $true  # Had an error
    }
}

# Launch VMware Workstation immediately
Write-Host "Launching VMware Workstation..." -ForegroundColor Cyan
Start-Process "C:\Program Files\VMware\VMware Workstation\vmware.exe"

# Check if any of the parallel threads returned a $true (error)
if ($errors -contains $true) {
    Write-Host "`n[ERROR] One or more services failed to start." -ForegroundColor Red
    Read-Host "Press Enter to close this window"
}