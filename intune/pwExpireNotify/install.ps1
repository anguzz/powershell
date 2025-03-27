

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$destinationPath = "C:\" 
$logFile = Join-Path $destinationPath "installLog.txt"


$client_secret_name="Intune_Desktop_Notifications"
$client_secret= ""

$secureString = ConvertTo-SecureString $client_secret -AsPlainText -Force
$encrypted_client_secret = ConvertFrom-SecureString $secureString

[Environment]::SetEnvironmentVariable($client_secret_name, $encrypted_client_secret, [EnvironmentVariableTarget]::Machine)


if (-not (Test-Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory | Out-Null
    Add-Content -Path $logFile -Value "Created destination directory at $destinationPath."
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

$sourcePopupFile2 = Join-Path $scriptPath "files\popup2.ps1"
$destinationPopupFile2 = Join-Path $destinationPath "popup2.ps1"
Copy-Item -Path $sourcePopupFile2 -Destination $destinationPopupFile2 -Force
Add-Content -Path $logFile -Value "Copied popup2.ps1 from $sourcePopupFile2 to $destinationPopupFile2."

$logoFile = Join-Path $scriptPath "files\Logo.png"
$destinationlogoFile = Join-Path $destinationPath "Logo.png"
Copy-Item -Path $logoFile -Destination $destinationPath -Force
Add-Content -Path $logFile -Value "Copied Logo.png from $sourcePopupFile2 to $destinationlogoFile."


$action = New-ScheduledTaskAction -Execute "conhost.exe" -Argument "--headless PowerShell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$destinationFile`""


$triggerLogon = New-ScheduledTaskTrigger -AtLogOn
$triggerBoot = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId (([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name) -LogonType Interactive -RunLevel Highest
$networkSettings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

try {
    Unregister-ScheduledTask -TaskName "CheckUserPasswordPolicy" -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -Action $action -Principal $principal -Trigger @($triggerLogon, $triggerBoot) -TaskName "CheckUserPasswordPolicy" -Description "Check password policy compliance on logon and system startup." -Settings $networkSettings  
    Add-Content -Path $logFile -Value "Scheduled task 'CheckUserPasswordPolicy' registered successfully with appropriate privileges and conditions."
} catch {
    Add-Content -Path $logFile -Value "Failed to register scheduled task: $_"
    Write-Error $_
}
