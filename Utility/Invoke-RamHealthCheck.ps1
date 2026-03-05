<#
.SYNOPSIS
  Get-RAMHealthReport.ps1
  Collects RAM health indicators and outputs results to stdout.
  Designed for non-interactive remote execution (e.g., Tanium).
#>

Write-Output "========== RAM HEALTH REPORT =========="
Write-Output "Hostname: $env:COMPUTERNAME"
Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# --------------------------------------------------
# Physical RAM inventory
# --------------------------------------------------
Write-Output "`n--- Physical Memory Modules ---"

try {
    $ram = Get-CimInstance Win32_PhysicalMemory

    foreach ($stick in $ram) {
        $capGB = [math]::Round($stick.Capacity / 1GB,2)

        Write-Output "Slot: $($stick.DeviceLocator)"
        Write-Output "  Manufacturer : $($stick.Manufacturer)"
        Write-Output "  Part Number  : $($stick.PartNumber.Trim())"
        Write-Output "  Serial       : $($stick.SerialNumber)"
        Write-Output "  Capacity GB  : $capGB"
        Write-Output "  Speed MHz    : $($stick.Speed)"
        Write-Output "  Configured   : $($stick.ConfiguredClockSpeed)"
        Write-Output ""
    }

    $total = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    Write-Output "Total RAM: $([math]::Round($total/1GB,2)) GB"

} catch {
    Write-Output "Failed to retrieve memory inventory: $_"
}

# --------------------------------------------------
# Current memory pressure
# --------------------------------------------------
Write-Output "`n--- Current Memory Status ---"

try {
    $os = Get-CimInstance Win32_OperatingSystem

    $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB,2)
    $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB,2)

    Write-Output "Total Visible RAM: $totalGB GB"
    Write-Output "Free RAM: $freeGB GB"
} catch {
    Write-Output "Failed to retrieve memory usage."
}

# --------------------------------------------------
# WHEA hardware error events
# --------------------------------------------------
Write-Output "`n--- Hardware Error Events (WHEA) ---"

try {
    $whea = Get-WinEvent -FilterHashtable @{
        LogName='System'
        ProviderName='Microsoft-Windows-WHEA-Logger'
        StartTime=(Get-Date).AddDays(-30)
    } -ErrorAction SilentlyContinue

    if ($whea) {
        Write-Output "WHEA events detected:"
        $whea |
            Select TimeCreated, Id, LevelDisplayName |
            Sort TimeCreated -Descending |
            Select -First 10 |
            Format-Table | Out-String | Write-Output
    } else {
        Write-Output "No WHEA hardware errors in last 30 days."
    }

} catch {
    Write-Output "Failed to check WHEA events."
}

# --------------------------------------------------
# Bugcheck events (memory related)
# --------------------------------------------------
Write-Output "`n--- Bugcheck Events (Event ID 1001) ---"

try {

    $bsod = Get-WinEvent -FilterHashtable @{
        LogName='System'
        Id=1001
        ProviderName='Microsoft-Windows-WER-SystemErrorReporting'
        StartTime=(Get-Date).AddDays(-30)
    } -ErrorAction SilentlyContinue

    if ($bsod) {

        $bsod |
            Select TimeCreated, Message |
            Sort TimeCreated -Descending |
            Select -First 5 |
            Format-List | Out-String | Write-Output

    } else {
        Write-Output "No BSOD events in last 30 days."
    }

} catch {
    Write-Output "Failed to retrieve bugcheck events."
}

# --------------------------------------------------
# Windows memory diagnostic results
# --------------------------------------------------
Write-Output "`n--- Windows Memory Diagnostic Results ---"

try {

    $memdiag = Get-WinEvent -FilterHashtable @{
        LogName='System'
        ProviderName='Microsoft-Windows-MemoryDiagnostics-Results'
    } -ErrorAction SilentlyContinue |
        Sort TimeCreated -Descending |
        Select -First 1

    if ($memdiag) {

        Write-Output "Last Memory Test:"
        Write-Output "Time: $($memdiag.TimeCreated)"
        Write-Output $memdiag.Message

    } else {

        Write-Output "No Windows Memory Diagnostic results found."

    }

} catch {
    Write-Output "Failed to retrieve memory diagnostic results."
}

# --------------------------------------------------
# Quick corruption indicators
# --------------------------------------------------
Write-Output "`n--- Quick Memory Corruption Indicators ---"

try {

    $memBugchecks = Get-WinEvent -FilterHashtable @{
        LogName='System'
        Id=1001
        StartTime=(Get-Date).AddDays(-30)
    } -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Message -match "0x0000001a|0x000000de|0x0000000a|MEMORY_MANAGEMENT|POOL_CORRUPTION"
    }

    if ($memBugchecks) {
        Write-Output "Memory-related bugchecks detected."
        Write-Output "Count: $($memBugchecks.Count)"
    }
    else {
        Write-Output "No common memory corruption bugchecks detected."
    }

} catch {
    Write-Output "Unable to evaluate corruption indicators."
}

Write-Output "`n========== END RAM HEALTH REPORT =========="