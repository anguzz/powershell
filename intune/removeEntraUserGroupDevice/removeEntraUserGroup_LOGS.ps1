
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$Global:LogFile = "C:\ProfileCleanupLog_$Timestamp.log"

Function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG", "WHATIF")]
        [string]$Level = "INFO",

        [Parameter(Mandatory=$false)]
        [string]$LogFilePath = $Global:LogFile # Access global variable
    )

    $logTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$logTimestamp [$Level] $Message"

    try {
        $LogDir = Split-Path -Path $LogFilePath -Parent
        if (-not (Test-Path -Path $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        }
        Add-Content -Path $LogFilePath -Value $logEntry -ErrorAction Stop
    } catch {
        Write-Warning "!!! Failed to write to log file '$LogFilePath': $($_.Exception.Message)"
    }

    switch ($Level) {
        "INFO"   { Write-Host $logEntry }
        "WARN"   { Write-Warning $logEntry }
        "ERROR"  { Write-Error $logEntry -ErrorAction Continue } #  Continue so script doesn't halt here
        "DEBUG"  { Write-Host $logEntry -ForegroundColor Gray }
        "WHATIF" { Write-Host $logEntry -ForegroundColor Magenta }
        default  { Write-Host $logEntry }
    }
}

Write-Log -Message "Script execution started."

Write-Log -Message "Ensuring NuGet Package Provider is installed..."
try {
    Install-PackageProvider -Name "NuGet" -Force -ErrorAction Stop
    Write-Log -Message "NuGet provider OK."
} catch {
    Write-Log -Message "Error installing NuGet provider: $($_.Exception.Message)" -Level ERROR
    
}

Write-Log -Message "Ensuring Microsoft Graph Authentication module is installed..."
try {
    Install-Module -Name "Microsoft.Graph.Authentication" -Scope AllUsers -Force -AllowClobber -ErrorAction Stop
    Write-Log -Message "Microsoft.Graph.Authentication module OK."
} catch {
    Write-Log -Message "Error installing Microsoft.Graph.Authentication: $($_.Exception.Message)" -Level ERROR
    
}


$ErrorActionPreference = 'SilentlyContinue'
$UsersFolderPath = "C:\Users"
$GroupId = "" 
$tenantID = ""
$clientID = ""
$clientSecret = "" 

Write-Log -Message "Configuration:"
Write-Log -Message "  Users Folder Path: $UsersFolderPath"
Write-Log -Message "  Target Group ID: $GroupId"
Write-Log -Message "  Tenant ID: $tenantID"
Write-Log -Message "  Client ID: $clientID"


$WhatIf = $false 
if (-not $WhatIf) {
    Write-Log -Message "-WhatIf switch is NOT active. LIVE DELETION MODE." -Level WARN
} else {
    Write-Log -Message "-WhatIf switch IS active. No changes will be made." -Level INFO
}


Write-Log -Message "Preparing Graph credentials..."
try {
    $secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force -ErrorAction Stop
    $credential = New-Object System.Management.Automation.PSCredential ($clientID, $secureSecret) -ErrorAction Stop
    Write-Log -Message "Credentials created."
} catch {
    Write-Log -Message "Failed to create secure secret or credential object: $($_.Exception.Message)" -Level ERROR
    exit 1
}

Write-Log -Message "Connecting to Microsoft Graph using Application Context..."
Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credential -ErrorAction SilentlyContinue 

if (-not (Get-MgContext -ErrorAction SilentlyContinue)) {
    Write-Log -Message "Graph connection failed. Please check Tenant ID, Client ID, Secret, and App Permissions/Consent." -Level ERROR
    exit 1 
} else {
    $context = Get-MgContext
    Write-Log -Message "Graph connection successful. Tenant: $($context.TenantId), AppID: $($context.ClientId), AuthType: $($context.AuthType)"
}



$groupDisplayName = "Unknown"
try {
    Write-Log -Message "Fetching display name for group: $GroupId"
    $groupDisplayNameURL = "https://graph.microsoft.com/v1.0/groups/$GroupId`?`$select=displayName"
    $groupDisplayResponse = Invoke-MgGraphRequest -Uri $groupDisplayNameURL -Method GET -OutputType PSObject -ErrorAction Stop
    $groupDisplayName = $groupDisplayResponse.displayName
    Write-Log -Message "Target group display name: '$groupDisplayName'"
} catch {
    Write-Log -Message "Error fetching group display name for '$GroupId': $($_.Exception.Message)" -Level WARN
    
}

Write-Log -Message "Fetching members for group '$groupDisplayName' (ID: $GroupId)..."
$groupMembersUpn = @()
$groupMemberPrefixes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
try {
    $groupApiUrl = "https://graph.microsoft.com/v1.0/groups/$GroupId/members?`$select=userPrincipalName"
    $groupResponse = Invoke-MgGraphRequest -Method GET -Uri $groupApiUrl -ErrorAction Stop
    $groupMembersUpn = $groupResponse.value.userPrincipalName

    $groupMembersUpn | ForEach-Object {
        if ($_ -like '*@*') {
            $prefix = ($_ -split '@')[0]
            if (-not [string]::IsNullOrWhiteSpace($prefix)) {
                $groupMemberPrefixes.Add($prefix) | Out-Null
            }
        } else {
             Write-Log -Message "Group member '$_' does not look like a UPN, skipping prefix extraction." -Level WARN
        }
    }
    Write-Log -Message "Found $($groupMembersUpn.Count) members, $($groupMemberPrefixes.Count) valid prefixes extracted."
} catch {
    Write-Log -Message "Error fetching group members for '$GroupId': $($_.Exception.Message)" -Level ERROR
}



$hostname = $env:COMPUTERNAME
Write-Log -Message "Current Device hostname: $hostname"

$primaryUserUpn = $null
$entraDeviceId = $null

Write-Log -Message "Finding device '$hostname' and its registered owner via Graph API..."
try {
    $deviceAndOwnerUrl = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$hostname'&`$expand=registeredOwners(`$select=userPrincipalName)"
    Write-Log -Message "Device lookup URL: $deviceAndOwnerUrl" -Level DEBUG

    $response = Invoke-MgGraphRequest -Method GET -Uri $deviceAndOwnerUrl -ErrorAction Stop

    $deviceInfo = $response.value | Select-Object -First 1

    if ($deviceInfo) {
        $entraDeviceId = $deviceInfo.id
        Write-Log -Message "Found Entra Device ID: $entraDeviceId"

        if ($null -ne $deviceInfo.registeredOwners -and $deviceInfo.registeredOwners.Count -gt 0) {
            $primaryUserUpn = $deviceInfo.registeredOwners[0].userPrincipalName
            Write-Log -Message "Device registered owner UserPrincipalName: $primaryUserUpn"
        } else {
            Write-Log -Message "Device found, but no registered owner listed."
        }
    } else {
        Write-Log -Message "Device '$hostname' not found in Entra ID." -Level WARN
    }
} catch {
    Write-Log -Message "Error finding device '$hostname' or its owner: $($_.Exception.Message)" -Level ERROR
}


Write-Log -Message "Checking local profiles in '$UsersFolderPath'..."
$profilesProcessed = 0
$profilesTargeted = 0
$profilesSkipped = 0
$profilesRemoved = 0
$profilesFailed = 0

Get-ChildItem -Path $UsersFolderPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $profilesProcessed++
    $profileName = $_.Name
    $profilePath = $_.FullName
    Write-Log -Message "Checking profile folder: '$profileName' at '$profilePath'" -Level DEBUG

    if ($groupMemberPrefixes.Contains($profileName)) {
        Write-Log -Message "Profile folder '$profileName' matches a UPN prefix from group '$groupDisplayName'."

        $matchingUpn = $groupMembersUpn | Where-Object { ($_ -split '@')[0] -eq $profileName } | Select-Object -First 1

        if (-not $matchingUpn) {
            Write-Log -Message "Could not map folder '$profileName' back to a full UPN from group list." -Level WARN
            continue # Skip to next folder
        }

        # Check against primary user
        if ($primaryUserUpn -ne $null -and $matchingUpn -eq $primaryUserUpn) {
            $profilesSkipped++
            Write-Log -Message "[SKIP] Profile '$profileName' belongs to primary user ($matchingUpn)."
        } else {
            # Target for deletion
            $profilesTargeted++
            Write-Log -Message "[TARGET] Profile '$profileName' (User: $matchingUpn) matches group and is not primary user." -Level WARN 

            if ($WhatIf) {
                Write-Log -Message " -> WHATIF: Would remove '$profilePath'" -Level WHATIF
            } else {
                Write-Log -Message " -> Removing '$profilePath'..." -Level WARN 
                try {
                    Remove-Item -Path $profilePath -Recurse -Force -ErrorAction Stop
                    $profilesRemoved++
                    Write-Log -Message " -> Removed '$profilePath' successfully."
                } catch {
                    $profilesFailed++
                    Write-Log -Message " -> FAILED to remove '$profilePath': $($_.Exception.Message)" -Level ERROR
                }
            }
        }
    } else {
         Write-Log -Message "Profile folder '$profileName' does not match any UPN prefix from group '$groupDisplayName'." -Level DEBUG #
    }
     Write-Log -Message "---" -Level DEBUG 
}


Write-Log -Message "============================================================="
Write-Log -Message "Script finished."
Write-Log -Message "Summary:"
Write-Log -Message "  Profiles Checked: $profilesProcessed"
Write-Log -Message "  Profiles Matching Group: $profilesTargeted + $profilesSkipped"
Write-Log -Message "  Profiles Skipped (Primary User): $profilesSkipped"
Write-Log -Message "  Profiles Targeted for Deletion: $profilesTargeted"
if ($WhatIf) {
     Write-Log -Message "  Mode: WhatIf (No deletions performed)"
} else {
     Write-Log -Message "  Mode: Live"
     Write-Log -Message "  Profiles Actually Removed: $profilesRemoved"
     Write-Log -Message "  Profile Removals Failed: $profilesFailed"
}
Write-Log -Message "============================================================="


exit 0