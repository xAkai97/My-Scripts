#Requires -RunAsAdministrator

$configPath = Join-Path $PSScriptRoot "vmware-services.json"

if (-not (Test-Path $configPath)) {
    Write-Error "Config file not found: $configPath"
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

$startedByScript = [System.Collections.Generic.List[string]]::new()

try {
    foreach ($service in $config.services) {

        $name = $service.name

        try {
            $svc = Get-Service -Name $name -ErrorAction Stop
        }
        catch {
            Write-Warning "Service '$name' not found."
            continue
        }

        # Ensure Manual startup type
        $cim = Get-CimInstance Win32_Service -Filter "Name='$name'"

        if ($cim.StartMode -ne 'Manual') {
            Write-Host "Setting $name startup type to Manual..."
            Set-Service -Name $name -StartupType Manual
        }

        # Start only if not already running
        if ($svc.Status -ne 'Running') {

            Write-Host "Starting $name..."

            Start-Service -Name $name -ErrorAction Stop

            $svc.WaitForStatus(
                [System.ServiceProcess.ServiceControllerStatus]::Running,
                [TimeSpan]::FromSeconds(20)
            )

            $startedByScript.Add($name)
        }
    }

    Write-Host "Launching VMware..."

    $proc = Start-Process `
        -FilePath $config.programPath `
        -PassThru

    $proc.WaitForExit()
}
finally {

    Write-Host "VMware closed."

    foreach ($name in $startedByScript) {

        try {

            $svc = Get-Service -Name $name -ErrorAction Stop

            if ($svc.Status -eq 'Running') {

                Write-Host "Stopping $name..."

                Stop-Service -Name $name -Force -ErrorAction Stop

                $svc.WaitForStatus(
                    [System.ServiceProcess.ServiceControllerStatus]::Stopped,
                    [TimeSpan]::FromSeconds(20)
                )
            }
        }
        catch {
            Write-Warning "Failed to stop $name : $_"
        }
    }

    Write-Host "Cleanup complete."
}