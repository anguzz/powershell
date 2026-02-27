# Invoke-BCD-Orphan-Cleanup.ps1
# Purpose: Backup BCD, suspend BitLocker for 1 reboot (if enabled), remove any BCD objects that reference $WINDOWS.~BT,
#          and ensure boot timeout is 0.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# 1. Detect Sysnative bcdedit (needed when running 32-bit PowerShell on 64-bit OS)
$bcdedit = if (Test-Path "$env:SystemRoot\Sysnative\bcdedit.exe") {
    "$env:SystemRoot\Sysnative\bcdedit.exe"
} else {
    "$env:SystemRoot\System32\bcdedit.exe"
}
Write-Output "--- Using bcdedit path: $bcdedit ---"

# 2. Suspend BitLocker (if active)
Write-Output "Checking BitLocker status..."
try {
    $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
    if ($bl -and $bl.ProtectionStatus -eq 'On') {
        Write-Output "BitLocker protection is ON. Suspending for 1 reboot..."
        Suspend-BitLocker -MountPoint "C:" -RebootCount 1 | Out-Null
    } else {
        Write-Output "BitLocker is not active or already suspended."
    }
} catch {
    Write-Output "Note: BitLocker check skipped or module not found."
}

# 3. Export BCD Backup
$backupPath = "C:\BCD_Backup_Final.bak"
Write-Output "Backing up BCD to $backupPath..."
& $bcdedit /export $backupPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Output "[ERROR] bcdedit /export failed. Exit code: $LASTEXITCODE"
}

# 4. Parse full BCD output once and delete any object that references $WINDOWS.~BT
Write-Output 'Scanning BCD identifiers for "$WINDOWS.~BT" references...'

# Get full output (verbose) and collapse into a single string for reliable parsing
$bcdRaw = & $bcdedit /enum all /v
$bcdText = $bcdRaw -join "`r`n"

# Split into objects at each "identifier" block
# This keeps each object's text together so we can detect $WINDOWS.~BT even if it's on "path" or "systemroot"
$blocks = [regex]::Split($bcdText, "(?m)^(?=identifier\s+)") | Where-Object { $_.Trim() }

$foundCount = 0
$deleteFailures = 0

foreach ($block in $blocks) {

    # Extract the identifier: could be {current}, {bootmgr}, or a GUID
    $idMatch = [regex]::Match($block, "(?mi)^\s*identifier\s+(\{[^\}]+\})\s*$")
    if (-not $idMatch.Success) { continue }

    $id = $idMatch.Groups[1].Value

    # Detect $WINDOWS.~BT within the block (case-insensitive)
    if ($block -match '(?i)\$WINDOWS\.~BT') {

        # Guardrails: never delete critical well-known identifiers
        if ($id -in @("{current}", "{default}", "{bootmgr}", "{fwbootmgr}", "{memdiag}", "{globalsettings}", "{bootloadersettings}", "{resumeloadersettings}", "{dbgsettings}", "{emssettings}", "{badmemory}", "{hypervisorsettings}")) {
            Write-Output "[SKIP] $id contains `$WINDOWS.~BT but is protected from deletion."
            continue
        }

        Write-Output "[MATCH] Found `$WINDOWS.~BT entry: $id"

        & $bcdedit /delete $id /f | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Output "[DELETE] Successfully deleted $id"
            $foundCount++
        } else {
            Write-Output "[ERROR] Failed to delete $id. Exit code: $LASTEXITCODE"
            $deleteFailures++
        }
    }
}

if ($foundCount -eq 0 -and $deleteFailures -eq 0) {
    Write-Output "No `$WINDOWS.~BT entries detected."
} else {
    Write-Output "Deleted `$WINDOWS.~BT entries: $foundCount. Failures: $deleteFailures"
}

# 5. Set timeout to 0 (Windows Boot Manager timeout)
Write-Output "Ensuring boot timeout is 0..."
& $bcdedit /timeout 0 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Output "[ERROR] Failed to set timeout. Exit code: $LASTEXITCODE"
} else {
    Write-Output "The operation completed successfully."
}

# 6. Final Verification
Write-Output "--- FINAL BCD CONFIGURATION ---"
& $bcdedit /enum all
Write-Output "--- SCRIPT COMPLETE ---"