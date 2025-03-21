$AccessTokenName = "GRAPH_PW_EXPIRE_TOKEN"
$destinationPath = "C:\Program Files (x86)\pwExpireNotifyClient"
$logFile = Join-Path $destinationPath "uninstallLog.txt"

# removes the scheduled task
try {
    Unregister-ScheduledTask -TaskName "CheckUserPasswordPolicy" -Confirm:$false
    Add-Content -Path $logFile -Value "Scheduled task 'CheckUserPasswordPolicy' unregistered successfully."
} catch {
    Add-Content -Path $logFile -Value "Failed to unregister scheduled task: $_"
}

# deletes the installation directory
try {
    Remove-Item -Path $destinationPath -Recurse -Force
    Add-Content -Path $logFile -Value "Deleted folder '$destinationPath' and all contents."
} catch {
    Add-Content -Path $logFile -Value "Failed to delete folder: $_"
}

# removes the environment variable
try {
    [System.Environment]::SetEnvironmentVariable($AccessTokenName, $null, [System.EnvironmentVariableTarget]::Machine)
    Add-Content -Path $logFile -Value "Removed environment variable '$AccessTokenName'."
} catch {
    Add-Content -Path $logFile -Value "Failed to remove environment variable '$AccessTokenName': $_"
}

# try to remove powershell modules for auth
$modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users")
foreach ($module in $modules) {
    try {
        Uninstall-Module -Name $module -AllVersions -Force
        Add-Content -Path $logFile -Value "Uninstalled $module module successfully."
    } catch {
        Add-Content -Path $logFile -Value "Failed to uninstall $module module: $_"
    }
}
