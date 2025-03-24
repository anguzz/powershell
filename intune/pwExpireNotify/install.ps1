$AccessTokenName= "GRAPH_PW_EXPIRE_TOKEN"
$AccessTokenString= ""

[System.Environment]::SetEnvironmentVariable($AccessTokenName, $AccessTokenString, [System.EnvironmentVariableTarget]::Machine)

$getToken = [System.Environment]::GetEnvironmentVariable($AccessTokenName, [System.EnvironmentVariableTarget]::Machine) 

if ($getToken -eq $AccessTokenString) {
    Write-Host "Success: Environment variable '$AccessTokenName' is set correctly."
} else {
    Write-Host "Error: Environment variable '$AccessTokenName' did not set correctly. Expected '$AccessTokenString' but got '$getToken'."
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$destinationPath = "C:\Program Files\pwExpireNotifyClient" 

$logFile = Join-Path $destinationPath "installLog.txt"
if (-not (Test-Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory
    Add-Content -Path $logFile -Value "Created destination directory."
}

$modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        try {
            Install-Module -Name $module -Force -Scope AllUsers -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
            Add-Content -Path $logFile -Value "Installed $module module."
        } catch {
            Add-Content -Path $logFile -Value "Failed to install $module module: $_"
            exit
        }
    } else {
        Add-Content -Path $logFile -Value "$module module is already installed."
    }
}


$sourceFile = Join-Path $scriptPath "files\checkExpire.ps1"
$destinationFile = Join-Path $destinationPath "checkExpire.ps1"


Copy-Item -Path $sourceFile -Destination $destinationFile -Force
Add-Content -Path $logFile -Value "Copied checkExpire.ps1 from files folder."


$sourcePopupFile = Join-Path $scriptPath "files\popup.ps1"
$destinationPopupFile = Join-Path $destinationPath "popup.ps1"
Copy-Item -Path $sourcePopupFile -Destination $destinationPopupFile -Force
Add-Content -Path $logFile -Value "Copied popup.ps1 from files folder."

$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$destinationFile`""

$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerBoot = New-ScheduledTaskTrigger -AtStartup

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

try {
    Unregister-ScheduledTask -TaskName "CheckUserPasswordPolicy" -Confirm:$false -ErrorAction SilentlyContinue

    # Register the new task
    Register-ScheduledTask -Action $action -Principal $principal -Trigger @($triggerLogon, $triggerBoot) -TaskName "CheckUserPasswordPolicy" -Description "Check password policy compliance on logon and system startup."
    Add-Content -Path $logFile -Value "Scheduled task registered successfully with SYSTEM privileges."
} catch {
    Add-Content -Path $logFile -Value "Failed to register scheduled task with SYSTEM privileges: $_"
    # Consider logging the exception details to better understand the error
    Write-Error $_
}
