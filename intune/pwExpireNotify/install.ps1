$AccessTokenName= "GRAPH_PW_EXPIRE_TOKEN"
$AccessTokenString= ""

[System.Environment]::SetEnvironmentVariable($AccessTokenName, $AccessTokenString, [System.EnvironmentVariableTarget]::Machine)


$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$destinationPath = ""  #set the desintation path here

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

# copy checkExpire 
$sourceFile = Join-Path $scriptPath "checkExpire.ps1"
$destinationFile = Join-Path $destinationPath "checkExpire.ps1"

Copy-Item -Path $sourceFile -Destination $destinationFile -Force
Add-Content -Path $logFile -Value "Copied checkExpire.ps1 "


# copy popup.ps1
$sourcePopupFile = Join-Path $scriptPath "popup.ps1"
$destinationPopupFile = Join-Path $destinationPath "popup.ps1"
Copy-Item -Path $sourcePopupFile -Destination $destinationPopupFile -Force
Add-Content -Path $logFile -Value "Copied popup.ps1 "

# task schedule checkExpire
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-NoProfile -WindowStyle Hidden -File `"$destinationFile`""
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerBoot = New-ScheduledTaskTrigger -AtStartup
$triggers = @($triggerLogon, $triggerBoot)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount

try {
    Register-ScheduledTask -Action $action -Principal $principal -Trigger $triggers -TaskName "CheckUserPasswordPolicy" -Description "Check password policy compliance on logon and system startup." -RunLevel Highest
    Add-Content -Path $logFile -Value "Scheduled task registered successfully with SYSTEM privileges."
} catch {
    Add-Content -Path $logFile -Value "Failed to register scheduled task with SYSTEM privileges: $_"
}

try {
    Register-ScheduledTask -Action $action -Trigger $triggers -TaskName "CheckUserPasswordPolicy" -Description "Check password policy compliance on logon and system startup."
    Add-Content -Path $logFile -Value "Scheduled task registered successfully."
} catch {
    Add-Content -Path $logFile -Value "Failed to register scheduled task: $_"
}
