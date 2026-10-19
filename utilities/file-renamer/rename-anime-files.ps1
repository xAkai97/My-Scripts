param(
    [string]$RunMode = "DRY",
    [string]$DroppedPath = ""
)

# If it receives ANYTHING other than "LIVE", it safely defaults to a Dry Run
$WhatIf = ($RunMode -ne "LIVE")

# DRAG AND DROP ROUTING: Determine what files to process
if ($DroppedPath -ne "") {
    if (Test-Path -LiteralPath $DroppedPath -PathType Container) {
        # A folder was dropped: process everything inside it
        $files = Get-ChildItem -LiteralPath $DroppedPath -Recurse -File
    } elseif (Test-Path -LiteralPath $DroppedPath -PathType Leaf) {
        # A single file was dropped: process only that file
        $files = Get-Item -LiteralPath $DroppedPath
    } else {
        Write-Host "Error: Dropped path is invalid or cannot be read." -ForegroundColor Red
        exit
    }
} else {
    # Nothing was dropped: default to the folder where the script lives
    $files = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File
}

foreach ($file in $files) {
    # Skip the utility scripts
    if ($file.Name -match '^(rename-anime-files\.(ps1|bat))$') { continue }

    $name = $file.BaseName
    $ext = $file.Extension
    $newName = $name

    if ($newName -match 'S(?!00)(\d+)E0*(\d+)') {
        $seasonNum = [int]$Matches[1]
        $epNum = $Matches[2]
        $newName = [System.Text.RegularExpressions.Regex]::Replace($newName, 'S(?!00)\d+E0*\d+', "S$seasonNum - $epNum")
    }

	$unwantedTags = @('[Dual Audio]', '[Dual-Audio]', 'Dual Audio', 'Dual-Audio')
		foreach ($tag in $unwantedTags) {
			$safeTag = [System.Text.RegularExpressions.Regex]::Escape($tag)
			$newName = [System.Text.RegularExpressions.Regex]::Replace($newName, $safeTag, '', 'IgnoreCase')
		}

    $newName = [System.Text.RegularExpressions.Regex]::Replace($newName, '\s*\[[0-9A-Fa-f]{8}\](\s*\(\d+\))?', '')

    $encoder = $null
    
	# Adaptive Encoder Extraction: Start of filename
	if ($newName -match '^\[([^\]]+)\]\s*(.*)$') {
		$potentialEncoder = $Matches[1]
		if ($potentialEncoder -notmatch '^(1080p|720p|480p|2160p|BD|Blu-?Ray|WEB-?DL|WEB|x264|x265|HEVC|AV1|OPUS|FLAC|AAC|AC3|DTS)$') {
			$encoder = $potentialEncoder
			$newName = $Matches[2]
		}
	}

	# Adaptive Encoder Extraction: End of filename
	if ($newName -match '^(.*?)\s*-\s*([A-Za-z][A-Za-z0-9_-]*)$') {
		$potentialEncoder = $Matches[2]
		if ($potentialEncoder -notmatch '^(1080p|720p|480p|2160p|BD|WEB|x264|x265|HEVC|AV1|OPUS|FLAC|AAC|AC3|DTS)$') {
			if (-not $encoder) { $encoder = $potentialEncoder }
			$newName = $Matches[1]
		}
	}

	# Adaptive Encoder Extraction: Bracketed at end of filename
	if ($newName -match '^(.*?)\s*\[([^\]]+)\]$') {
		$potentialEncoder = $Matches[2]
		if ($potentialEncoder -notmatch '^(1080p|720p|480p|2160p|BD|WEB|x264|x265|HEVC|AV1|OPUS|FLAC|AAC|AC3|DTS)$') {
			if (-not $encoder) { $encoder = $potentialEncoder }
			$newName = $Matches[1]
		}
	}

	if ($newName -match '\.') {
		# Protect single-digit numbers separated by a dot (e.g., 7.1, 5.1) without relying on word boundaries
		$newName = [System.Text.RegularExpressions.Regex]::Replace($newName, '(?<!\d)(\d)\.(\d)(?!\d)', '$1_DOT_$2')
		
		# Replace all remaining dots with spaces
		$newName = $newName -replace '\.', ' '
		
		# Restore the protected dots
		$newName = $newName -replace '_DOT_', '.'
		
		# Ensure space between codec and channel (FLAC7.1 -> FLAC 7.1)
		# $newName = [System.Text.RegularExpressions.Regex]::Replace($newName, '(?i)(FLAC|AAC|AC3|DTS)(\d\.\d)', '$1 $2')

	}

	$newName = [System.Text.RegularExpressions.Regex]::Replace($newName, '\]\s*\[', ' ')
	$newName = [System.Text.RegularExpressions.Regex]::Replace($newName, '\s+', ' ').Trim()

	# Wrap standard scene release media tags in brackets (only if not already wrapped)
	if ($newName -notmatch '\(' -and $newName -notmatch '\[') {
		$newName = [System.Text.RegularExpressions.Regex]::Replace($newName, '(?i)\s+(1080p|720p|480p|2160p)\b(.*)', ' [$1$2]')
	}

	if ($encoder) {
		if (-not $newName.EndsWith("[$encoder]")) {
			$newName = $newName + "[" + $encoder + "]"
		}
	}

    $newName = $newName.Trim()

    # FAILSAFE 1: Prevent empty filenames
    if ([string]::IsNullOrWhiteSpace($newName)) {
        Write-Host "Error: Generated empty filename for $($file.Name). Skipping." -ForegroundColor Red
        continue
    }

    # FAILSAFE 2: Strip any illegal Windows characters
    $newName = $newName -replace '[\\/:*?"<>|]', ''
    
    $newFileName = "$newName$ext"

    # FAILSAFE 3: Prevent overwriting existing files
    $targetPath = Join-Path -Path $file.DirectoryName -ChildPath $newFileName
    if ($file.Name -ne $newFileName -and (Test-Path -LiteralPath $targetPath)) {
        Write-Host "Collision Detected: $newFileName already exists. Skipping $($file.Name)." -ForegroundColor Red
        continue
    }

    if ($file.Name -ne $newFileName) {
        Write-Host "OLD: $($file.Name)" -ForegroundColor Yellow
        Write-Host "NEW: $newFileName" -ForegroundColor Green
        Write-Host "-----------------------------------------------------------"
        
        if (-not $WhatIf) {
            Rename-Item -LiteralPath $file.FullName -NewName $newFileName
        }
    } else {
        Write-Host "Skipped (No changes needed): $($file.Name)" -ForegroundColor DarkGray
    }
}

if ($WhatIf) {
    Write-Host "`n[DRY RUN COMPLETE] No files were actually modified." -ForegroundColor Cyan
} else {
    Write-Host "`n[RENAMING COMPLETE] All changes applied successfully!" -ForegroundColor Green
}
