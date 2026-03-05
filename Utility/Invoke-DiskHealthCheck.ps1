<#
.SYNOPSIS
Endpoint Disk Health Check

.DESCRIPTION
Collects quick disk health information for troubleshooting crashes or storage issues.
Runs several checks and prints results clearly for action history or remote tools
like Tanium.

Checks:
• Physical disk health status
• Disk model and SMART status
• File system scan (non-disruptive)
• Storage controller timeout errors (Event ID 129)
• Disk retry errors (Event ID 153)
#>

Write-Output "========== Disk Health Check =========="
Write-Output "Time: $(Get-Date)"
Write-Output ""

# --------------------------------------------------
# 1. Physical Disk Health
# --------------------------------------------------
Write-Output "---- Physical Disk Status ----"
try {
    Get-PhysicalDisk | Select FriendlyName, MediaType, HealthStatus, OperationalStatus | Format-Table -AutoSize
}
catch {
    Write-Output "Get-PhysicalDisk not available on this system."
}
Write-Output ""

# --------------------------------------------------
# 2. Disk Model + SMART Status
# --------------------------------------------------
Write-Output "---- Disk Model / SMART Status ----"
try {
    Get-CimInstance Win32_DiskDrive | Select Model, SerialNumber, Status | Format-Table -AutoSize
}
catch {
    Write-Output "Unable to retrieve disk model information."
}
Write-Output ""

# --------------------------------------------------
# 3. File System Scan
# --------------------------------------------------
Write-Output "---- File System Check (chkdsk scan mode) ----"
try {
    cmd /c "chkdsk C: /scan"
}
catch {
    Write-Output "Unable to run chkdsk scan."
}
Write-Output ""

# --------------------------------------------------
# 4. Storage Timeout Events (Event ID 129)
# --------------------------------------------------
Write-Output "---- Storport Timeout Events (Event ID 129) ----"
try {
    $events129 = Get-WinEvent -FilterHashtable @{LogName="System"; ID=129} -MaxEvents 5 -ErrorAction SilentlyContinue
    if ($events129) {
        $events129 | Select TimeCreated, Message | Format-List
    }
    else {
        Write-Output "No recent Event ID 129 detected."
    }
}
catch {
    Write-Output "Unable to query Event ID 129."
}
Write-Output ""

# --------------------------------------------------
# 5. Disk Retry Events (Event ID 153)
# --------------------------------------------------
Write-Output "---- Disk Retry Events (Event ID 153) ----"
try {
    $events153 = Get-WinEvent -FilterHashtable @{LogName="System"; ID=153} -MaxEvents 5 -ErrorAction SilentlyContinue
    if ($events153) {
        $events153 | Select TimeCreated, Message | Format-List
    }
    else {
        Write-Output "No recent Event ID 153 detected."
    }
}
catch {
    Write-Output "Unable to query Event ID 153."
}

Write-Output ""
Write-Output "========== Disk Health Check Complete =========="