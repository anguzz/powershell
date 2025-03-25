

$PW_Expire_key_name= "GRAPH_PW_EXPIRE_KEY"
$PW_Expire_key_string = "test_key"

[System.Environment]::SetEnvironmentVariable($PW_Expire_key_name, $PW_Expire_key_string, [System.EnvironmentVariableTarget]::Machine)

$checkToken = [System.Environment]::GetEnvironmentVariable($PW_Expire_key_name, [System.EnvironmentVariableTarget]::Machine) 

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$destinationPath = "" 
$logFile = Join-Path $destinationPath "installLog.txt"

if (-not (Test-Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory | Out-Null
    Add-Content -Path $logFile -Value "Created destination directory at $destinationPath."
}

if ($checkToken -eq $PW_Expire_key_string) {
    Write-Host "Success: Environment variable '$PW_Expire_key_name' is set correctly."
    Add-Content -Path $logFile -Value "Verified that environment variable is set correctly."
} else {
    Write-Host "Error: Environment variable '$PW_Expire_key_name' did not set correctly. Expected '$PW_Expire_key_string' but got '$checkToken'."
    Add-Content -Path $logFile -Value "Failed to verify environment variable: expected '$PW_Expire_key_string' but got '$checkToken'."
}


$modules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        try {
            Install-Module -Name $module -Force -Scope AllUsers -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
            Add-Content -Path $logFile -Value "Installed $module module."
        } catch {
            Add-Content -Path $logFile -Value "Failed to install $module module: $_"
            Write-Error $_
            exit
        }
    } else {
        Add-Content -Path $logFile -Value "$module module is already installed."
    }
}

$sourceFile = Join-Path $scriptPath "files\checkExpire.ps1"
$destinationFile = Join-Path $destinationPath "checkExpire.ps1"
Copy-Item -Path $sourceFile -Destination $destinationFile -Force
Add-Content -Path $logFile -Value "Copied checkExpire.ps1 from $sourceFile to $destinationFile."

$sourcePopupFile = Join-Path $scriptPath "files\popup.ps1"
$destinationPopupFile = Join-Path $destinationPath "popup.ps1"
Copy-Item -Path $sourcePopupFile -Destination $destinationPopupFile -Force
Add-Content -Path $logFile -Value "Copied popup.ps1 from $sourcePopupFile to $destinationPopupFile."

$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -File `"$destinationFile`""
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerBoot = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

try {
    Unregister-ScheduledTask -TaskName "CheckUserPasswordPolicy" -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -Action $action -Principal $principal -Trigger @($triggerLogon, $triggerBoot) -TaskName "CheckUserPasswordPolicy" -Description "Check password policy compliance on logon and system startup."
    Add-Content -Path $logFile -Value "Scheduled task 'CheckUserPasswordPolicy' registered successfully with SYSTEM privileges."
} catch {
    Add-Content -Path $logFile -Value "Failed to register scheduled task: $_"
    Write-Error $_
}