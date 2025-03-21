$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$destinationPath = "C:\pwExpireNotify"  #Point to a location users do not have permissions to access


$logFile = Join-Path $destinationPath "installLog.txt"
if (-not (Test-Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory
    Add-Content -Path $logFile -Value "Created destination directory."
}

$modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        try {
            Install-Module -Name $module -Force -Scope CurrentUser -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
            Add-Content -Path $logFile -Value "Installed $module module."
        } catch {
            Add-Content -Path $logFile -Value "Failed to install $module module: $_"
            exit
        }
    } else {
        Add-Content -Path $logFile -Value "$module module is already installed."
    }
}

$sourceFile = Join-Path $scriptPath "notify.ps1"
$destinationFile = Join-Path $destinationPath "callNotify.ps1"
Copy-Item -Path $sourceFile -Destination $destinationFile -Force
Add-Content -Path $logFile -Value "Copied notify.ps1 to callNotify.ps1."

$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-NoProfile -WindowStyle Hidden -File `"$destinationFile`""
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerBoot = New-ScheduledTaskTrigger -AtStartup

$triggers = @($triggerLogon, $triggerBoot)

try {
    Register-ScheduledTask -Action $action -Trigger $triggers -TaskName "CheckUserPasswordPolicy" -Description "Check password policy compliance on logon and system startup."
    Add-Content -Path $logFile -Value "Scheduled task registered successfully."
} catch {
    Add-Content -Path $logFile -Value "Failed to register scheduled task: $_"
}
