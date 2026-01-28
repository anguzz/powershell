<#
.SYNOPSIS
  Reassigns Intune device "primary user" from old user to the most recent usersLoggedOn user.

.DESCRIPTION
  - Finds managed devices where userPrincipalName == reassignedUPN.
  - For each device, reads usersLoggedOn (beta), picks the most recent.
  - Uses beta relationship: DELETE non-target links, then POST target via users/$ref.
  - Outputs a CSV report and console summary.

.REQUIREMENTS
  - Modules: Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement
  - Intune RBAC allowing "Change primary user"
  - Scopes: DeviceManagementManagedDevices.ReadWrite.All, Directory.Read.All

.NOTES
  Use at your own risk; test in a pilot first.
#>

param(
  [string]$reassignedUPN = "username@email.com", # upn of the user to reassign from/staging user
  [switch]$WhatIf,
  [int]$MaxRetries = 3,
  [int]$DefaultRetrySeconds = 5
)

# ----------------- Config / Setup -----------------
$ErrorActionPreference = 'Stop'
$ts  = (Get-Date).ToString("yyyyMMdd-HHmmss")
$OutDir = Join-Path $PSScriptRoot "reassign-report"
New-Item -Path $OutDir -ItemType Directory -Force | Out-Null
$ReportPath = Join-Path $OutDir "SetPrimaryUserReport-$ts.csv"
$LogPath    = Join-Path $OutDir "SetPrimaryUser-$ts.log"

Start-Transcript -Path $LogPath -Append | Out-Null

# Ensure Graph modules are available
$requiredModules = @('Microsoft.Graph.Authentication','Microsoft.Graph.DeviceManagement')
foreach ($m in $requiredModules) {
  if (-not (Get-Module -ListAvailable -Name $m)) {
    Write-Host "Installing required module: $m ..."
    Install-Module $m -Scope CurrentUser -Force -AllowClobber
  }
  Import-Module $m -ErrorAction Stop
}

# ----------------- Connect to Graph -----------------
Write-Host "Connecting to Microsoft Graph..."
Connect-MgGraph -Scopes @(
  'DeviceManagementManagedDevices.ReadWrite.All',
  'Directory.Read.All'
)
$profile = Get-MgContext
Write-Host "Connected as $($profile.Account) on $($profile.TenantId)."

# ----------------- Helpers -----------------

# 429-aware wrapper
function Invoke-GraphWithRetry {
  param(
    [Parameter(Mandatory=$true)][ValidateSet('GET','POST','DELETE','PATCH','PUT')]
    [string]$Method,
    [Parameter(Mandatory=$true)][string]$Uri,
    [Parameter()][hashtable]$Headers,
    [Parameter()][object]$Body,
    [Parameter()][string]$ContentType = 'application/json',
    [int]$MaxRetries = 3,
    [int]$DefaultRetrySeconds = 5
  )
  $attempt = 0
  do {
    try {
      $params = @{ Method = $Method; Uri = $Uri }
      if ($Headers)     { $params.Headers     = $Headers }
      if ($PSBoundParameters.ContainsKey('Body')) { $params.Body = $Body }
      if ($ContentType) { $params.ContentType = $ContentType }
      return Invoke-MgGraphRequest @params
    }
    catch {
      $attempt++
      $resp = $_.Exception.Response
      $status = $resp.StatusCode.value__
      $retryAfter = $resp.Headers['Retry-After']
      if ($status -eq 429 -and $attempt -lt $MaxRetries) {
        $wait = [int]($retryAfter | Select-Object -First 1); if (-not $wait) { $wait = $DefaultRetrySeconds }
        Write-Warning "429 received. Waiting $wait sec (attempt $attempt/$MaxRetries) for $Uri"
        Start-Sleep -Seconds $wait
      } else { throw }
    }
  } while ($attempt -lt $MaxRetries)
}

# Cache user lookups (id -> object)
$script:UserCache = @{}

function Get-UserById {
  param([Parameter(Mandatory=$true)][string]$UserId)
  if ($UserCache.ContainsKey($UserId)) { return $UserCache[$UserId] }
  $uri = "https://graph.microsoft.com/v1.0/users/$UserId`?`$select=id,userPrincipalName,displayName,accountEnabled"
  $u = Invoke-GraphWithRetry -Method GET -Uri $uri -MaxRetries $MaxRetries -DefaultRetrySeconds $DefaultRetrySeconds
  $UserCache[$UserId] = $u
  return $u
}

function Get-StagedDevices {
  param([Parameter(Mandatory=$true)][string]$reassignedUPN)
  Write-Host "Searching for devices assigned to '$reassignedUPN'..."
  try {
    $devices = Get-MgDeviceManagementManagedDevice -Filter "userPrincipalName eq '$reassignedUPN'" -All
    Write-Host "Found $($devices.Count) devices."
    return $devices
  }
  catch {
    Write-Error "Failed to get devices. Error: $($_.Exception.Message)"
    return @()
  }
}

function Get-MostRecentUsersLoggedOnId {
  param([Parameter(Mandatory=$true)][string]$DeviceId)
  $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DeviceId`?`$select=usersLoggedOn"
  $resp = Invoke-GraphWithRetry -Method GET -Uri $uri -MaxRetries $MaxRetries -DefaultRetrySeconds $DefaultRetrySeconds
  if (-not $resp.usersLoggedOn) { return $null }
  $last = $resp.usersLoggedOn | Sort-Object -Property lastLogOnDateTime -Descending | Select-Object -First 1
  return $last.userId
}

# ----- beta helpers for device-user relationship -----

function Get-DeviceLinkedUsersBeta {
  param([Parameter(Mandatory=$true)][string]$DeviceId)
  $resp = Invoke-GraphWithRetry -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DeviceId/users" -MaxRetries $MaxRetries -DefaultRetrySeconds $DefaultRetrySeconds
  if ($null -eq $resp) { return @() }
  if ($resp.PSObject.Properties.Name -contains 'value') { return @($resp.value) }
  return @($resp)
}

function Ensure-PrimaryUserBeta {
  param(
    [Parameter(Mandatory=$true)][string]$DeviceId,
    [Parameter(Mandatory=$true)][string]$TargetUserId,
    [switch]$WhatIf
  )

  # Current links (beta)
  $current = Get-DeviceLinkedUsersBeta -DeviceId $DeviceId
  $currIds = @($current | ForEach-Object { $_.id })

  # Already correct
  if ($currIds.Count -eq 1 -and $currIds[0] -eq $TargetUserId) { return "NoChange" }

  # Prune non-targets
  foreach ($id in $currIds) {
    if ($id -ne $TargetUserId) {
      $delUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DeviceId/users/$id/`$ref"
      if ($WhatIf) {
        Write-Host "  [WHATIF] Would DELETE $delUri" -ForegroundColor Yellow
      } else {
        Invoke-GraphWithRetry -Method DELETE -Uri $delUri -MaxRetries $MaxRetries -DefaultRetrySeconds $DefaultRetrySeconds | Out-Null
      }
    }
  }

  # Ensure target link exists
  if ($currIds -notcontains $TargetUserId) {
    $addUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DeviceId/users/`$ref"
    $body   = @{ '@odata.id' = "https://graph.microsoft.com/beta/users/$TargetUserId" } | ConvertTo-Json
    if ($WhatIf) {
      Write-Host "  [WHATIF] Would POST $addUri -> $($body)" -ForegroundColor Yellow
    } else {
      Invoke-GraphWithRetry -Method POST -Uri $addUri -Body $body -ContentType 'application/json' -MaxRetries $MaxRetries -DefaultRetrySeconds $DefaultRetrySeconds | Out-Null
    }
    if ($currIds.Count -gt 0) {
      return "Replaced"
    } else {
      return "Added"
    }
  }

  return "Pruned"
}

# ----------------- Main -----------------
$devices = Get-StagedDevices -reassignedUPN $reassignedUPN
if (-not $devices -or $devices.Count -eq 0) {
  Write-Host "No devices found for staging user '$reassignedUPN'. Exiting."
  Stop-Transcript | Out-Null
  return
}

Write-Host "`n--- Devices to be processed ---"
$devices | Format-Table DeviceName, EnrolledByUserPrincipalName, Id
Write-Host "--------------------------------`n"

$report = New-Object System.Collections.Generic.List[object]
$idx = 0
$total = $devices.Count

foreach ($device in $devices) {
  $idx++
  $devId = $device.Id
  $devName = $device.DeviceName

  Write-Progress -Activity "Reassigning primary users" -Status "$devName ($idx of $total)" -PercentComplete (($idx/$total)*100)
  Write-Host "Processing device '$devName' (ID: $devId)..."

  $row = [PSCustomObject]@{
    Timestamp              = (Get-Date)
    DeviceName             = $devName
    DeviceId               = $devId
    reassignedUPN         = $reassignedUPN
    LastLoggedOnUserId     = $null
    LastLoggedOnUserUpn    = $null
    LastLoggedOnDisplay    = $null
    Action                 = $null
    Result                 = "FAILED"
    Error                  = $null
  }

  try {
    $newUserId = Get-MostRecentUsersLoggedOnId -DeviceId $devId
    if (-not $newUserId) {
      Write-Warning "  [SKIPPED] No usersLoggedOn found; cannot reassign."
      $row.Action = "Skipped (no usersLoggedOn)"
      $row.Result = "SKIPPED"
      $report.Add($row)
      continue
    }

    $row.LastLoggedOnUserId = $newUserId

    # Resolve to UPN for better logging
    try {
      $u = Get-UserById -UserId $newUserId
      $row.LastLoggedOnUserUpn = $u.userPrincipalName
      $row.LastLoggedOnDisplay = $u.displayName
      Write-Host "  Found last logged-on user: $($u.displayName) <$($u.userPrincipalName)>"
    }
    catch {
      Write-Warning "  Could not resolve user $newUserId to UPN; proceeding."
    }

    # Optional: Skip  self-assignments
    if ($row.LastLoggedOnUserUpn -match $reassignedUPN) {
      Write-Host "  [SKIP] Last logged-on user is self; not changing." -ForegroundColor Yellow
      $row.Action = "Skipped self-assignment"
      $row.Result = "SKIPPED"
      $report.Add($row)
      continue
    }

    # Ensure primary user via beta
    $action = Ensure-PrimaryUserBeta -DeviceId $devId -TargetUserId $newUserId -WhatIf:$WhatIf
    if ($action -eq "NoChange") {
      Write-Host "  [OK] Already set to target user." -ForegroundColor Green
    } else {
      Write-Host "  [SUCCESS] $action." -ForegroundColor Green
    }
    $row.Action = $action
    if ($WhatIf) {
      $row.Result = "WHATIF"
    } else {
      $row.Result = "SUCCESS"
    }

    # Read-back (beta) for visibility when not WhatIf
    if (-not $WhatIf) {
      $after = Get-DeviceLinkedUsersBeta -DeviceId $devId
      $afterUpns = ($after | ForEach-Object { $_.userPrincipalName }) -join ','
      if ($afterUpns) { Write-Host "  Now linked to: $afterUpns" }
    }
  }
  catch {
    $msg = $_.Exception.Message
    Write-Warning "  [FAILED] $msg"
    $row.Error = $msg
  }

  $report.Add($row)
}

# ----------------- Output -----------------
$report | Sort-Object Timestamp |
  Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8

Write-Host "`nDone. Report written to:"
Write-Host "  $ReportPath"
Write-Host "Transcript:"
Write-Host "  $LogPath"

Stop-Transcript | Out-Null
