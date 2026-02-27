# Bypassing 64-bit redirection for Tanium 32-bit agent
$bcdedit = if (Test-Path "$env:SystemRoot\Sysnative\bcdedit.exe") { "$env:SystemRoot\Sysnative\bcdedit.exe" } else { "bcdedit.exe" }

# Execute and capture
$bcd = & $bcdedit /enum 2>$null
if (-not $bcd) { Write-Host "Unknown|0|0|None"; exit }

# 1. Precise Loader Count
$loaderCount = ($bcd | Select-String "Windows Boot Loader").Count

# 2. Extract Timeout - cleaning any non-numeric characters
$timeoutLine = $bcd | Select-String "timeout"
$timeout = if ($timeoutLine -match "(\d+)") { $matches[1] } else { "0" }

# 3. Identify Duplicates (Targeting entries that are NOT the active OS)
$allLoaders = & $bcdedit /enum /v
$duplicateIDs = [regex]::Matches($allLoaders, "{[a-z0-9-]{36}}") | 
                ForEach-Object { $_.Value } | 
                Where-Object { $_ -ne "{current}" -and $_ -ne "{bootmgr}" -and $_ -match "^\{[a-f0-9]{8}-" } | 
                Select-Object -Unique

$idList = if ($duplicateIDs) { $duplicateIDs -join "," } else { "None" }

# 4. Final Status check
$status = if ($loaderCount -gt 1) { "Affected" } else { "Clean" }

# Output MUST match the column order: Status|LoaderCount|Timeout|DuplicateIDs
Write-Host "$status|$loaderCount|$timeout|$idList"