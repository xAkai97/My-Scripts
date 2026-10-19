param(
    [string] $TargetFile
)

if (-not (Test-Path -LiteralPath $TargetFile)) {
    Write-Host "Error: File not found." -ForegroundColor Red
    exit
}

if ($TargetFile -match 'fix-fuse.*\.ps1$') {
    Write-Host "Cannot run the fix script on itself!" -ForegroundColor Yellow
    exit
}

$lines = Get-Content -LiteralPath $TargetFile

# Uses \x24 (hex for $) in single quotes so copy-paste can NEVER fuse variables
$pattern = '(?<!\x24\w+)([a-zA-Z0-9=\-\@\+\}\)])\x24(?=[\w\(\{])'
$replace = '$1 $$'

# Fix () or { fused directly to a $variable by splitting to a new indented line
$parenNewlinePattern = '\(\)\x24(?=[\w\(\{])'
$parenNewlineReplace = "()`r`n`t`$"

$braceNewlinePattern = '\{\x24(?=[\w\(\{])'
$braceNewlineReplace = "{`r`n`t`$"

$modified = $false
$newContent = @()

Write-Host "Scanning for fused characters and artifacts..." -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor DarkGray

for ($i = 0; $i -lt $lines.Count; $i++) {
    $original = $lines[$i]
    $current = $original

    # 1. Fix LaTeX pipe artifacts (\vert{} or \vert -> |)
    $current = [System.Text.RegularExpressions.Regex]::Replace($current, '\\vert(?:\{\})?', '|')

    # 2. Fix () or { fused directly to $variable
    $current = [System.Text.RegularExpressions.Regex]::Replace($current, $parenNewlinePattern, $parenNewlineReplace)
    $current = [System.Text.RegularExpressions.Regex]::Replace($current, $braceNewlinePattern, $braceNewlineReplace)

    # 3. Fix characters fused to $variable (skips '\tdevice$' safely)
    $current = [System.Text.RegularExpressions.Regex]::Replace($current, $pattern, $replace)

    # 4. Clean up any accidental double-dollar variables (e.g. $$loaded -> $loaded)
    $current = [System.Text.RegularExpressions.Regex]::Replace($current, '\x24\x24(?=[\w\(\{])', '$$')

    if ($current -cne $original) {
        Write-Host ("Line {0}:" -f ($i + 1)) -ForegroundColor Yellow
        Write-Host ("[-] {0}" -f $original) -ForegroundColor Red
        Write-Host ("[+] {0}" -f $current) -ForegroundColor Green
        Write-Host "--------------------------------" -ForegroundColor DarkGray
        $modified = $true
    }

    $newContent += $current
}

if ($modified) {
    Set-Content -LiteralPath $TargetFile -Value $newContent -Encoding utf8 -Force
    Write-Host "`nFixes applied and saved successfully to:" -ForegroundColor Green
    Write-Host $TargetFile -ForegroundColor White
} else {
    Write-Host "`nNo fused dollar signs or artifacts found! File is clean." -ForegroundColor Green
}

# 5. Built-in AST Syntax Verification
Write-Host "`nRunning AST Syntax Verification..." -ForegroundColor Cyan
$astTokens =$null
$astErrors =$null
$resolvedPath = (Resolve-Path -LiteralPath $TargetFile).Path

[void][System.Management.Automation.Language.Parser]::ParseFile($resolvedPath, [ref]$astTokens, [ref]$astErrors)

if ($astErrors.Count -eq 0) {
    Write-Host "[OK] AST Syntax Check Passed: 0 errors found." -ForegroundColor Green
} else {
    Write-Host ("[!] AST Syntax Check Failed: {0} error(s) detected:" -f $astErrors.Count) -ForegroundColor Red
    foreach ($err in $astErrors) {
        Write-Host ("  -> Line {0}, Col {1}: {2}" -f $err.Extent.StartLineNumber, $err.Extent.StartColumnNumber, $err.Message) -ForegroundColor Yellow
        Write-Host ("     Code: {0}" -f $err.Extent.Text) -ForegroundColor DarkGray
    }
}