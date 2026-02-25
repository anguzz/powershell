param(
    [string]$destinationIP
)

# Decode UTF-8 encoded parameter (required in Tanium Cloud)
$destinationIP = [System.Uri]::UnescapeDataString($destinationIP)

if ([string]::IsNullOrWhiteSpace($destinationIP)) {
    Write-Output "ERROR: No destination IP provided."
    exit 1
}

Write-Output "=== Network Test Report ==="
Write-Output "Target: $destinationIP"
Write-Output "Timestamp: $(Get-Date)"
Write-Output ""

# 1. Basic ICMP Test
Write-Output "--- Test-Connection ---"
try {
    Test-Connection -ComputerName $destinationIP -Count 4 -ErrorAction Stop |
        Select-Object Address, ResponseTime |
        Format-Table -AutoSize
} catch {
    Write-Output "Test-Connection failed: $($_.Exception.Message)"
}

Write-Output ""

# 2. Legacy Ping
Write-Output "--- ping.exe ---"
try {
    ping $destinationIP -n 4
} catch {
    Write-Output "Ping failed."
}

Write-Output ""

# 3. Port Test (Common ports)
Write-Output "--- TCP Port Checks ---"
$ports = @(80, 443, 3389)

foreach ($port in $ports) {
    try {
        $result = Test-NetConnection -ComputerName $destinationIP -Port $port -WarningAction SilentlyContinue
        Write-Output "Port $port : $($result.TcpTestSucceeded)"
    } catch {
        Write-Output "Port $port : Test failed"
    }
}

Write-Output ""
Write-Output "=== End of Report ==="




