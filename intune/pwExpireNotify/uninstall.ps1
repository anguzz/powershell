

#Requires -RunAsAdministrator

#--------------------------------------------------------------------------
# Initialization & Configuration
#--------------------------------------------------------------------------

$destinationPath = "C:\pwExpireNotifyClient" # app install directory
$logFilePath = "C:\pwExpireNotifyClientLogs" #  log location (or choose C:\Windows\Temp or similar)
$logFile = Join-Path $logFilePath "uninstall_pwExpireNotifyClient_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$moduleBasePath = Join-Path $env:ProgramFiles "WindowsPowerShell\Modules" 

# --- Component Names ---
$taskName = "CheckUserPasswordPolicy"
$clientSecretEnvVarName = "Intune_Desktop_Notifications_Secret" # Ensure this matches the install script


$modulesToRemove = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Users"
)


if (-not (Test-Path $logFilePath)) {
    try {
        New-Item -Path $logFilePath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "Failed to create log directory '$logFilePath'. Logging will be unavailable. Error: $($_.Exception.Message)"

    }
}


function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    if (Test-Path $logFilePath) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "$timestamp - $Message"
        try {
            Add-Content -Path $logFile -Value $logEntry -ErrorAction Stop
        } catch {
            Write-Warning "Failed to write to log file '$logFile'. Error: $($_.Exception.Message)"
        }
    } else {
         Write-Warning "Log directory '$logFilePath' unavailable. Message not logged: $Message"
    }
}

Write-Log "======== Uninstall Script Execution Start ========"
Write-Log "Target application path: $destinationPath"
Write-Log "System module path: $moduleBasePath"
Write-Log "Log file: $logFile"

#--------------------------------------------------------------------------
# Unregister Scheduled Task
#--------------------------------------------------------------------------
Write-Log "Attempting to unregister scheduled task '$taskName'..."
try {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Log "Scheduled task '$taskName' unregistered successfully."
    } else {
        Write-Log "Scheduled task '$taskName' does not exist or could not be found. Skipping."
    }
} catch {
    $errorMessage = "Error occurred while trying to unregister scheduled task '$taskName'. Error: $($_.Exception.Message)"
    Write-Log $errorMessage
    Write-Warning $errorMessage 
}

#--------------------------------------------------------------------------
# Remove Application Directory
#--------------------------------------------------------------------------
Write-Log "Attempting to remove application directory '$destinationPath'..."
if (Test-Path $destinationPath) {
    try {
        Remove-Item -Path $destinationPath -Recurse -Force -ErrorAction Stop
        Write-Log "Successfully removed directory '$destinationPath'."
    } catch {
        $errorMessage = "Failed to remove directory '$destinationPath'. Error: $($_.Exception.Message)"
        Write-Log $errorMessage
        Write-Warning $errorMessage # Log as warning, maybe partially uninstalled
    }
} else {
    Write-Log "Application directory '$destinationPath' does not exist. Skipping."
}

#--------------------------------------------------------------------------
# Remove Environment Variable
#--------------------------------------------------------------------------
Write-Log "Attempting to remove environment variable '$clientSecretEnvVarName'..."
try {
    $existingVar = [Environment]::GetEnvironmentVariable($clientSecretEnvVarName, [EnvironmentVariableTarget]::Machine)
    if ($existingVar -ne $null) {
        [Environment]::SetEnvironmentVariable($clientSecretEnvVarName, $null, [EnvironmentVariableTarget]::Machine)
        Write-Log "Environment variable '$clientSecretEnvVarName' removed successfully."
    } else {
         Write-Log "Environment variable '$clientSecretEnvVarName' does not exist. Skipping."
    }
} catch {
    $errorMessage = "Failed to remove environment variable '$clientSecretEnvVarName'. Error: $($_.Exception.Message)"
    Write-Log $errorMessage
    Write-Warning $errorMessage # Log as warning
}

#--------------------------------------------------------------------------
# Remove Copied Modules
#--------------------------------------------------------------------------
Write-Log "Attempting to remove specific module folders from '$moduleBasePath'..."

foreach ($moduleName in $modulesToRemove) {
    $moduleFullPath = Join-Path $moduleBasePath $moduleName
    Write-Log "Checking for module folder '$moduleFullPath'..."

    if (Test-Path $moduleFullPath) {
        Write-Log "Attempting to remove '$moduleFullPath'..."
        try {
            Remove-Item -Path $moduleFullPath -Recurse -Force -ErrorAction Stop
            Write-Log "Successfully removed module folder '$moduleFullPath'."
        } catch {
            $errorMessage = "Failed to remove module folder '$moduleFullPath'. Error: $($_.Exception.Message)"
            Write-Log $errorMessage
            Write-Warning $errorMessage 
        }
    } else {
        Write-Log "Module folder '$moduleFullPath' does not exist. Skipping."
    }
}

Write-Log "======== Uninstall Script Execution End ========"
exit 0 