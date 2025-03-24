$taskName = "CheckUserPasswordPolicy"

try {
     Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    Write-Output "Scheduled task '$taskName' detected successfully."
    Exit 0  # Success code
} catch {
    if ($_.Exception -match "does not exist") {
        Write-Output "Scheduled task '$taskName' not found."
    } else {
        Write-Output "Error checking scheduled task: $($_.Exception.Message)"
    }
    Exit 1  # Error code
}
