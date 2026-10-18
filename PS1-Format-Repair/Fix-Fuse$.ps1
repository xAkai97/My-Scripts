param(
    [string]$TargetFile
)

if (-not (Test-Path -LiteralPath ($TargetFile))) {
    Write-Host "Error: File not found." -ForegroundColor Red;
    exit;
}

if (($TargetFile) -match "Fix-Fuse`$\.ps1$") {
    Write-Host "Cannot run the fix script on itself!" -ForegroundColor Yellow;
    exit;
}

# Read file line-by-line (Removed -Raw)
$lines = Get-Content -LiteralPath ($TargetFile);$d = [char]36;

# Adaptive regex pattern
$pattern = "(?<!\" + $d + "\w+)([a-zA-Z0-9=\-\@])\" + $d;
$replace = "`$1 " + $d + $d;

$modified = $false;
$newContent = @();

Write-Host "Scanning for fused characters..." -ForegroundColor Cyan;
Write-Host "--------------------------------" -ForegroundColor DarkGray;

for ($i = 0; $i -lt $lines.Count; $i++) {
    $original = $lines[$i];
    $current = $original;

    # Apply the adaptive space fix
    $current = [System.Text.RegularExpressions.Regex]::Replace($current, $pattern, $replace);

    # Apply the parenthesis newline fix
    $current = ($current).Replace("()$d", "()`r`n`t$d");

    # If the line was changed, print the before and after
    if ($current -cne $original) {
        Write-Host "Line $($i + 1):" -ForegroundColor Yellow;
        Write-Host "[-] $original" -ForegroundColor Red;
        Write-Host "[+] $current" -ForegroundColor Green;
        Write-Host "--------------------------------" -ForegroundColor DarkGray;
        $modified = $true;
    }
    
    $newContent += $current;
}

if ($modified) {
    # Save the updated lines back to the file
    Set-Content -LiteralPath ($TargetFile) -Value ($newContent) -Encoding utf8 -Force;
    Write-Host "`nFixes applied and saved successfully to:" -ForegroundColor Green;
    Write-Host ($TargetFile) -ForegroundColor White;
} else {
    Write-Host "`nNo fused dollar signs found! File is completely clean." -ForegroundColor Green;
}