



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
$clientSecretName = "Intune_Desktop_Notifications" 

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
# Scheduled Task Creation using XML
#--------------------------------------------------------------------------
Write-Log "Configuring scheduled task 'CheckUserPasswordPolicy' from XML..."

$taskName = "CheckUserPasswordPolicy"
$taskXmlTemplateFile = Join-Path $scriptPath "taskXML\CheckUserPasswordPolicy.xml"
$taskXmlDeployedFile = Join-Path $destinationPath "CheckUserPasswordPolicy_configured.xml"

if (-not (Test-Path $taskXmlTemplateFile)) {
    $msg = "FATAL: Missing task XML template at '$taskXmlTemplateFile'."
    Write-Log $msg; Write-Error $msg; exit 1
}

# Determine Principal User ID - Using Current User's SID for robustness
$principalUserId = ""
try {
    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principalUserId = $windowsIdentity.User.Value # This is the SID string
    if (-not $principalUserId) {
        throw "Retrieved SID is empty."
    }
    Write-Log "Successfully retrieved current user SID to use for task principal: $principalUserId"
} catch {
    Write-Log "WARNING: Failed to get current user SID: $($_.Exception.Message). Falling back to 'BUILTIN\Users'."
    Write-Log "The task might not run with the intended specific user privileges if 'BUILTIN\Users' is used."
    $principalUserId = "BUILTIN\Users" # Fallback - be aware of implications
}

Write-Log "Using Principal UserID for task XML: '$principalUserId'"

# Replace token and save XML
try {
    $xmlContent = Get-Content $taskXmlTemplateFile -Raw -ErrorAction Stop
    
    $placeholderRegex = '\{PRINCIPAL_USER_ID\}' 
    if ($xmlContent -match $placeholderRegex) {
        $xmlContent = $xmlContent -replace $placeholderRegex, [System.Security.SecurityElement]::Escape($principalUserId)
        Write-Log "Successfully replaced placeholder '$placeholderRegex' in XML content."
    } else {
        Write-Log "WARNING: Placeholder '$placeholderRegex' not found in XML template '$taskXmlTemplateFile'. The UserId might not be set as intended."
    }
    
    $xmlContent | Set-Content -Path $taskXmlDeployedFile -Encoding Unicode -Force -ErrorAction Stop
    Write-Log "Configured task XML saved to '$taskXmlDeployedFile'."
} catch {
    $msg = "FATAL: Failed to process task XML template. Error: $($_.Exception.Message)"
    Write-Log $msg; Write-Error $msg; exit 1
}

Write-Log "Unregistering existing task '$taskName' (if present)..."
schtasks.exe /Delete /TN $taskName /F 2>&1 | Out-Null 

Write-Log "Registering scheduled task '$taskName' from XML '$taskXmlDeployedFile'..."
$schtasksOutput = schtasks.exe /Create /XML $taskXmlDeployedFile /TN $taskName /F 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Log "Scheduled task '$taskName' created successfully."
} else {
    $msg = "FATAL: Failed to create task '$taskName' (Exit Code: $LASTEXITCODE)."
    Write-Log $msg
    Write-Log "Schtasks.exe output: $schtasksOutput"
    Write-Log "Content of deployed XML file '$taskXmlDeployedFile' that failed:"
    Write-Log (Get-Content $taskXmlDeployedFile -Raw)
    Write-Error $msg 
    exit 1
}

Write-Log "======== Script Execution End ========"
exit 0

