$destinationPath = "C:\pwExNotify" 
$logFilePath = "C:\logs"
$logFile = Join-Path $logFilePath "uninstall_pw_notify_expire_Log.txt"
$client_secret_name="Intune_Desktop_Notifications"

# check for the log directory 
if (-Not (Test-Path -Path $logFilePath)) {
    New-Item -Path $logFilePath -ItemType Directory
    Add-Content -Path $logFile -Value "Log directory created at '$logFilePath'."
}

# check for the log file 
if (-Not (Test-Path -Path $logFile)) {
    New-Item -Path $logFile -ItemType File
    Add-Content -Path $logFile -Value "Log file created at '$logFile'."
}

# remove task
try {
    Unregister-ScheduledTask -TaskName "CheckUserPasswordPolicy" -Confirm:$false
    Add-Content -Path $logFile -Value "Scheduled task 'CheckUserPasswordPolicy' unregistered successfully."
} catch {
    Add-Content -Path $logFile -Value "Failed to unregister scheduled task: $_"
}

# delete installer directory
try {
    Remove-Item -Path $destinationPath -Recurse -Force
    Add-Content -Path $logFile -Value "Deleted folder '$destinationPath' and all contents."
} catch {
    Add-Content -Path $logFile -Value "Failed to delete folder: $_"
}

# remove the env variable  
try {
    [Environment]::SetEnvironmentVariable($client_secret_name, $null, [EnvironmentVariableTarget]::Machine)
    Add-Content -Path $logFile -Value "Environment variable '$client_secret_name' removed successfully."
} catch {
    Add-Content -Path $logFile -Value "Failed to remove environment variable: $_"
}

# removes graph module
<# 
$modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users")
foreach ($module in $modules) {
    try {
        Uninstall-Module -Name $module -AllVersions -Force
        Add-Content -Path $logFile -Value "Uninstalled $module module successfully."
    } catch {
        Add-Content -Path $logFile -Value "Failed to uninstall $module module: $_"
    }
}
#>
