# DNS Cache Flush with Logging
# Author: Angel Santoyo
# Purpose: Log DNS cache before and after flushing, to verify old GP portal entries cleared.

# Create log directory if missing
$logPath = "C:\logs\DnsCacheFlush\"
if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Path $logPath -Force | Out-Null }

$beforeLog = Join-Path $logPath "DnsCacheBeforeFlush.txt"
$afterLog  = Join-Path $logPath "DnsCacheAfterFlush.txt"

Write-Output "Starting DNS cache flush at $(Get-Date)..."

# Capture DNS cache before flush
try {
    $beforeFlush = Get-DnsClientCache
    $beforeFlush | Out-File -FilePath $beforeLog -Force
    Write-Output "Logged DNS cache before flush to $beforeLog"
} catch {
    Write-Warning "Failed to capture DNS cache before flush: $_"
}

# Flush DNS cache (system-level)
try {
    ipconfig /flushdns | Out-Null
    Write-Output "DNS cache successfully flushed."
} catch {
    Write-Warning "Failed to flush DNS cache: $_"
}

# Capture DNS cache after flush
try {
    Start-Sleep -Seconds 2
    $afterFlush = Get-DnsClientCache
    $afterFlush | Out-File -FilePath $afterLog -Force
    Write-Output "Logged DNS cache after flush to $afterLog"
} catch {
    Write-Warning "Failed to capture DNS cache after flush: $_"
}

Write-Output "DNS flush operation completed at $(Get-Date)."
exit 0
