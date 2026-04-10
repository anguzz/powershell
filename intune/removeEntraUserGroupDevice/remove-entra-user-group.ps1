

Install-PackageProvider -Name "NuGet" -Force
Install-Module -Name "Microsoft.Graph.Authentication" -Scope AllUsers -Force -AllowClobber 


#=========================== variables ===========================
$ErrorActionPreference = 'SilentlyContinue'
$UsersFolderPath = "C:\Users"

Write-Host "Connecting to Microsoft Graph...`n"
Write-Host "=============================================================`n"

$GroupId = "" 
$tenantID = ""
$clientID = ""
$clientSecret = ""

$secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($clientID, $secureSecret)

Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credential -ErrorAction SilentlyContinue

$secureSecret = ConvertTo-SecureString $clientSecret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($clientID, $secureSecret)

#=========================== connection ===========================

Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credential -Scope "DeviceManagementManagedDevices.Read.All" -ErrorAction SilentlyContinue

Write-Host "Connected.`n "
Write-Host "=============================================================`n"


$groupDisplayNameURL = "https://graph.microsoft.com/v1.0/groups/$GroupId`?`$select=displayName"
$groupDisplayResponse = Invoke-MgGraphRequest -Uri $groupDisplayNameURL -Method GET -OutputType PSObject
$groupDisplayName = $groupDisplayResponse.displayName

Write-Host "Fetching members for group - " $groupDisplayName

Write-Host "=============================================================`n"


$groupMembersUpn = @()
$groupMemberPrefixes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
try {
    $groupApiUrl = "https://graph.microsoft.com/v1.0/groups/$GroupId/members?`$select=userPrincipalName"
    $groupResponse = Invoke-MgGraphRequest -Method GET -Uri $groupApiUrl -ErrorAction Stop
    $groupMembersUpn = $groupResponse.value.userPrincipalName

    # Extract prefixes (username part) into a HashSet for quick checking
    $groupMembersUpn | ForEach-Object {
        if ($_ -like '*@*') {
            $prefix = ($_ -split '@')[0]
            if (-not [string]::IsNullOrWhiteSpace($prefix)) {
                $groupMemberPrefixes.Add($prefix) | Out-Null
            }
        }
    }
    Write-Host "Found $($groupMembersUpn.Count) members, $($groupMemberPrefixes.Count) valid prefixes."
} catch {
    Write-Warning "Error fetching group members for '$GroupId': $($_.Exception.Message)"
}


# 3. Fetch Current Device Hostname
$hostname = $env:COMPUTERNAME
Write-Host "Current Device hostname: $hostname`n"
Write-Host "=============================================================`n"

# 4. Find Device ID and Primary User
try {
    Write-Host "Finding device '$hostname' and its registered owner..."

   
    $deviceAndOwnerUrl = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$hostname'&`$expand=registeredOwners(`$select=userPrincipalName)"

    $response = Invoke-MgGraphRequest -Method GET -Uri $deviceAndOwnerUrl -ErrorAction Stop

    $deviceInfo = $response.value | Select-Object -First 1

    if ($deviceInfo) {
        $entraDeviceId = $deviceInfo.id
        Write-Host "Found Entra Device ID: $entraDeviceId"

  
        if ($null -ne $deviceInfo.registeredOwners -and $deviceInfo.registeredOwners.Count -gt 0) {
            $primaryUserUpn = $deviceInfo.registeredOwners[0].userPrincipalName
        }

        if ($primaryUserUpn) {
            Write-Host "Device registered owner UserPrincipalName: $primaryUserUpn"
        } else {
            Write-Host "Device found, but no registered owner listed."
        }
    } else {
        Write-Warning "Device '$hostname' not found in Entra ID."
    }
} catch {
    Write-Warning "Error finding device or owner: $($_.Exception.Message)"
}

Write-Host "=============================================================`n"




# 5. check Local Profiles and Delete (if not primary user)
Write-Host "Checking profiles in $UsersFolderPath..."
Write-Host "-------------------------------------------------------------`n"

Get-ChildItem -Path $UsersFolderPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $profileName = $_.Name
    $profilePath = $_.FullName

    # Check if this folder name matches a prefix from the target group
    if ($groupMemberPrefixes.Contains($profileName)) {

        # Find the full UPN for this prefix from our list
        $matchingUpn = $groupMembersUpn | Where-Object { ($_ -split '@')[0] -eq $profileName } | Select-Object -First 1

        if (-not $matchingUpn) {
            # should not happen if prefix was found, but check anyway
            Write-Warning "Could not map folder '$profileName' back to a full UPN."
            Write-Host "-------------------------------------------------------------`n"
            continue
        }

        # Check against primary user
        if ($primaryUserUpn -ne $null -and $matchingUpn -eq $primaryUserUpn) {
            Write-Host "[SKIP] Profile '$profileName' belongs to primary user ($matchingUpn)." -ForegroundColor Cyan
            Write-Host "-------------------------------------------------------------`n"

        } else {
            # Target for deletion
            Write-Host "[TARGET] Profile '$profileName' (User: $matchingUpn) matches group and is not primary user.`n" -ForegroundColor Yellow

            if ($WhatIf) {
                 Write-Host " -> WHATIF: Would remove '$profilePath'`n" -ForegroundColor Magenta

            } else {
                Write-Host " -> Removing '$profilePath'...`n" -ForegroundColor Red
                try {
                    Remove-Item -Path $profilePath -Recurse -Force -ErrorAction Stop
                    Write-Host " -> Removed '$profilePath' successfully." -ForegroundColor Green
                } catch {
                    Write-Warning " -> FAILED to remove '$profilePath': $($_.Exception.Message)"
                }
            }
        }
    }
   
}
Write-Host "=============================================================`n"
Write-Host "Script finished."
exit 0
Write-Host "=============================================================`n"
