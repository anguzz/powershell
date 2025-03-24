$AccessTokenName = "GRAPH_PW_EXPIRE_TOKEN"
$destinationPath = "" 
$logFilePath = "C:\logs"
$logFile = Join-Path $logFilePath "uninstall_pw_notify_expire_Log.txt"

# Ensure the log directory exists
if (-Not (Test-Path -Path $logFilePath)) {
    New-Item -Path $logFilePath -ItemType Directory
    Add-Content -Path $logFile -Value "Log directory created at '$logFilePath'."
}

# Ensure the log file exists
if (-Not (Test-Path -Path $logFile)) {
    New-Item -Path $logFile -ItemType File
    Add-Content -Path $logFile -Value "Log file created at '$logFile'."
}

# Removes the scheduled task
try {
    Unregister-ScheduledTask -TaskName "CheckUserPasswordPolicy" -Confirm:$false
    Add-Content -Path $logFile -Value "Scheduled task 'CheckUserPasswordPolicy' unregistered successfully."
} catch {
    Add-Content -Path $logFile -Value "Failed to unregister scheduled task: $_"
}

# Deletes the installation directory
try {
    Remove-Item -Path $destinationPath -Recurse -Force
    Add-Content -Path $logFile -Value "Deleted folder '$destinationPath' and all contents."
} catch {
    Add-Content -Path $logFile -Value "Failed to delete folder: $_"
}

# Removes the environment variable
try {
    [System.Environment]::SetEnvironmentVariable($AccessTokenName, $null, [System.EnvironmentVariableTarget]::Machine)
    Add-Content -Path $logFile -Value "Removed environment variable '$AccessTokenName'."
} catch {
    Add-Content -Path $logFile -Value "Failed to remove environment variable '$AccessTokenName': $_"
}


$modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users")
foreach ($module in $modules) {
    try {
        Uninstall-Module -Name $module -AllVersions -Force
        Add-Content -Path $logFile -Value "Uninstalled $module module successfully."
    } catch {
        Add-Content -Path $logFile -Value "Failed to uninstall $module module: $_"
    }
}


