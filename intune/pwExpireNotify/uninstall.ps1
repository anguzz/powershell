$taskName = "CheckUserPasswordPolicy"
$destinationPath = "C:\pwExpireNotify"
$logFile = Join-Path $destinationPath "uninstallLog.txt"


try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Add-Content -Path $logFile -Value "Scheduled task '$taskName' unregistered successfully."
} catch {
    Add-Content -Path $logFile -Value "Failed to unregister scheduled task: $_"
}

try {
    Remove-Item -Path $destinationPath -Recurse -Force
    Add-Content -Path $logFile -Value "Deleted folder '$destinationPath' and all contents."
} catch {
    Add-Content -Path $logFile -Value "Failed to delete folder: $_"
}

$taskName = "CheckUserPasswordPolicy"
$destinationPath = "C:\pwExpireNotify"
$logFile = Join-Path $destinationPath "uninstallLog.txt"
$modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users")

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Add-Content -Path $logFile -Value "Scheduled task '$taskName' unregistered successfully."
} catch {
    Add-Content -Path $logFile -Value "Failed to unregister scheduled task: $_"
}

try {
    Remove-Item -Path $destinationPath -Recurse -Force
    Add-Content -Path $logFile -Value "Deleted folder '$destinationPath' and all contents."
} catch {
    Add-Content -Path $logFile -Value "Failed to delete folder: $_"
}

foreach ($module in $modules) {
    try {
        Uninstall-Module -Name $module -AllVersions -Force
        Add-Content -Path $logFile -Value "Uninstalled $module module successfully."
    } catch {
        Add-Content -Path $logFile -Value "Failed to uninstall $module module: $_"
    }
}

