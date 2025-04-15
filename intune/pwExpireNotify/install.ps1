



param (
    [string]$ClientSecret = "", # Intune App Registration Client Secret
    [string]$Base64AESKey = "" # Base64 Encoded AES Key for Secret Encryption
)

# --- Script Paths ---
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition -ErrorAction Stop
$destinationPath = "C:\pwExpireNotifyClient"
$logFile = Join-Path $destinationPath "installLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# --- Module Paths ---
$moduleSourcePath = Join-Path $scriptPath "modules" # Location of bundled modules relative to the script
$moduleDestinationPath = "C:\Program Files\WindowsPowerShell\Modules"


# --- Secret Configuration ---
$clientSecretName = "Intune_Desktop_Notifications_Secret" 

# --- Logging Setup ---
# Ensure destination directory exists for logging
if (-not (Test-Path $destinationPath)) {
    try {
        New-Item -Path $destinationPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Error "Failed to create destination directory '$destinationPath'. Error: $($_.Exception.Message)"
        exit 1 # Cannot continue without destination/log directory
    }
}

# logging function
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    try {
        Add-Content -Path $logFile -Value $logEntry -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write to log file '$logFile'. Error: $($_.Exception.Message)"
    }
}

Write-Log "======== Script Execution Start ========"
Write-Log "Script path: $scriptPath"
Write-Log "Destination path: $destinationPath"
Write-Log "Log file: $logFile"
Write-Log "Bundled module source: $moduleSourcePath"
Write-Log "Module destination: $moduleDestinationPath"

#--------------------------------------------------------------------------
# Environment Variable Setup (Encrypted Secret)
#--------------------------------------------------------------------------
Write-Log "Setting encrypted client secret environment variable..."
try {
    $aesKeyBytes = [Convert]::FromBase64String($Base64AESKey)
    $secureString = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $encryptedClientSecret = ConvertFrom-SecureString -SecureString $secureString -Key $aesKeyBytes

    [Environment]::SetEnvironmentVariable($clientSecretName, $encryptedClientSecret, [EnvironmentVariableTarget]::Machine)
    Write-Log "Successfully set machine environment variable '$clientSecretName'."
} catch {
    $errorMessage = "Failed to set environment variable '$clientSecretName'. Error: $($_.Exception.Message)"
    Write-Log $errorMessage
    Write-Error $errorMessage
    exit 1 # Critical failure
}

#--------------------------------------------------------------------------
# Deploy Bundled Modules
#--------------------------------------------------------------------------
Write-Log "Deploying bundled modules..."
if (-not (Test-Path $moduleSourcePath)) {
     $errorMessage = "Module source path '$moduleSourcePath' not found. Ensure modules are bundled correctly."
     Write-Log $errorMessage
     Write-Error $errorMessage
     exit 1 
}

try {
    if (-not (Test-Path $moduleDestinationPath)) {
        Write-Log "Module destination path '$moduleDestinationPath' does not exist, attempting to create."
        New-Item -Path $moduleDestinationPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    
    Write-Log "Copying modules from '$moduleSourcePath' to '$moduleDestinationPath'..."
    Copy-Item -Path $moduleSourcePath\* -Destination $moduleDestinationPath -Recurse -Force -ErrorAction Stop
    Write-Log "Successfully copied bundled modules."
} catch {
    $errorMessage = "Failed to copy bundled modules. Error: $($_.Exception.Message)"
    Write-Log $errorMessage
    Write-Error $errorMessage

}

#--------------------------------------------------------------------------
# deploy Application Files
#--------------------------------------------------------------------------
Write-Log "Deploying application files..."
$filesToCopy = @(
    @{ Source = "files\checkExpire.ps1"; Destination = "checkExpire.ps1" },
    @{ Source = "files\popup.ps1"; Destination = "popup.ps1" },
    @{ Source = "files\popup2.ps1"; Destination = "popup2.ps1" },
    @{ Source = "files\_Logo.png"; Destination = "_Logo.png" }
)

foreach ($file in $filesToCopy) {
    $sourceFilePath = Join-Path $scriptPath $file.Source
    $destinationFilePath = Join-Path $destinationPath $file.Destination
    Write-Log "Copying '$($file.Source)' to '$destinationFilePath'..."
    try {
        Copy-Item -Path $sourceFilePath -Destination $destinationFilePath -Force -ErrorAction Stop
        Write-Log "Successfully copied '$($file.Destination)'."
    } catch {
        $errorMessage = "Failed to copy file '$($file.Source)'. Error: $($_.Exception.Message)"
        Write-Log $errorMessage
        Write-Error $errorMessage
       
    }
}

#--------------------------------------------------------------------------
# scheduled Task Creation
#--------------------------------------------------------------------------
Write-Log "Configuring scheduled task 'CheckUserPasswordPolicy'..."

$taskName = "CheckUserPasswordPolicy"
$taskDescription = "Checks user password expiration status and provides notifications."
$checkScriptFile = Join-Path $destinationPath "checkExpire.ps1"

$taskAction = New-ScheduledTaskAction -Execute "conhost.exe" -Argument "--headless PowerShell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$checkScriptFile`"" -ErrorAction Stop

# Define triggers for logon and startup
$triggers = @(
    New-ScheduledTaskTrigger -AtLogOn -ErrorAction Stop

)

$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RunOnlyIfNetworkAvailable -StartWhenAvailable -DontStopOnIdleEnd


$taskPrincipal = $null
try {
    $explorerProcess = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" | Select-Object -First 1
    if ($explorerProcess) {
        $ownerInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwner
        if ($ownerInfo -and $ownerInfo.User) {
            $domain = "DOMAIN" # add your domain here
            $accountName = "$domain\$($ownerInfo.User)"
            Write-Log "Attempting to set task principal to '$accountName' based on explorer.exe owner."
            $taskPrincipal = New-ScheduledTaskPrincipal -UserId $accountName -LogonType Interactive -ErrorAction Stop
        } else {
             Write-Log "Could not determine owner from explorer.exe process."
        }
    } else {
        Write-Log "explorer.exe process not found. Cannot determine user for scheduled task principal automatically."
    }
} catch {
     Write-Log "Error detecting user principal: $($_.Exception.Message)"
}

if (-not $taskPrincipal) {
  
     $errorMessage = "Failed to determine user principal for the scheduled task. Cannot proceed."
     Write-Log $errorMessage
     Write-Error $errorMessage
     exit 1
    
}


if ($taskPrincipal) {
    Write-Log "Registering scheduled task '$taskName'..."
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue 

        Register-ScheduledTask -TaskName $taskName `
            -Description $taskDescription `
            -Principal $taskPrincipal `
            -Action $taskAction `
            -Trigger $triggers `
            -Settings $taskSettings `
            -Force `
            -ErrorAction Stop

        Write-Log "Scheduled task '$taskName' registered successfully."
    } catch {
        $errorMessage = "Failed to register scheduled task '$taskName'. Error: $($_.Exception.Message)"
        Write-Log $errorMessage
        Write-Error $errorMessage
       
    }
} else {
     Write-Log "Skipping scheduled task registration because user principal could not be set."
}

Write-Log "======== Script Execution End ========"
exit 0 