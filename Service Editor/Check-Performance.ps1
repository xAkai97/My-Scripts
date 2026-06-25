# Check-Performance.ps1
# Debug script to monitor resource usage of the ServiceEditor application.

$processName = "ServiceEditor"
$process = Get-Process -Name $processName -ErrorAction SilentlyContinue

if ($null -eq $process) {
    Write-Host "ServiceEditor process is not currently running." -ForegroundColor Yellow
    Write-Host "Please start ServiceEditor.exe first."
    exit
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Monitoring ServiceEditor Performance" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to exit monitoring.`n"

try {
    while ($true) {
        $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($null -eq $process) {
            Write-Host "ServiceEditor process terminated." -ForegroundColor Red
            break
        }
        
        # Calculate CPU usage
        $cpu = (Get-Counter "\Process($processName)\% Processor Time" -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
        if ($null -eq $cpu) { $cpu = 0 }
        # Scale CPU usage relative to number of logical processor cores
        $cpu = [Math]::Round($cpu / $env:NUMBER_OF_PROCESSORS, 2)
        
        $memWorkingSet = [Math]::Round($process.WorkingSet64 / 1MB, 2)
        $memPrivate = [Math]::Round($process.PrivateMemorySize64 / 1MB, 2)
        $threads = $process.Threads.Count
        $handles = $process.HandleCount

        Clear-Host
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host " Service Editor Performance Monitor (Active)" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "Process Name:   $($process.Name) (PID: $($process.Id))"
        Write-Host "Status:         Running" -ForegroundColor Green
        Write-Host "---------------------------------------------"
        Write-Host "CPU Usage:      $cpu % (Normalized over $env:NUMBER_OF_PROCESSORS Cores)" -ForegroundColor (if ($cpu -gt 5) {"Yellow"} else {"White"})
        Write-Host "Working Set:    $memWorkingSet MB (Physical RAM)" -ForegroundColor (if ($memWorkingSet -gt 150) {"Yellow"} else {"White"})
        Write-Host "Private Memory: $memPrivate MB (Committed Memory)"
        Write-Host "Active Threads: $threads" -ForegroundColor (if ($threads -gt 40) {"Yellow"} else {"White"})
        Write-Host "Handles Count:  $handles" -ForegroundColor (if ($handles -gt 1000) {"Yellow"} else {"White"})
        Write-Host "---------------------------------------------"
        Write-Host "Performance Recommendation:" -ForegroundColor Gray
        if ($cpu -gt 10) {
            Write-Host "[-] Warning: High CPU usage. Watchers might be polling instead of event-driven." -ForegroundColor Red
        } else {
            Write-Host "[+] CPU usage is low and healthy." -ForegroundColor Green
        }
        if ($memWorkingSet -gt 200) {
            Write-Host "[-] Warning: High RAM usage. Possible handle or object leak in WMI events." -ForegroundColor Red
        } else {
            Write-Host "[+] RAM footprint is low and optimal." -ForegroundColor Green
        }

        Start-Sleep -Seconds 1
    }
}
catch {
    Write-Host "`nMonitoring stopped." -ForegroundColor LightGray
}
