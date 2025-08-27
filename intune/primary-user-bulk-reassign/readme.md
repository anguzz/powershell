# Intune Device Primary User Reassignment

## Overview
This PowerShell script reassigns an Intune device's "primary user" from a staging or old account (e.g., `user@email.com`) to the most recent interactive user, across all devices currently tied to that account.

For example, if multiple devices are tied to my account `anguzz@email.com`, their primary user would be re-assigned to the last logged-on user who is **not** that staging account. This is useful for shared devices, as well as scenarios where you have a staging Autopilot v2 DEM account for bulk enrollments.

It uses the following endpoint:  
`https://graph.microsoft.com/beta/deviceManagement/managedDevices/{deviceID}/?$select=usersLoggedOn`

### Example Graph Response
```json
{
  "@odata.context": "https://graph.microsoft.com/beta/$metadata#deviceManagement/managedDevices(usersLoggedOn)/$entity",
  "usersLoggedOn": [
    {
      "userId": "123456789-xxxx-xxxx-xxxx-xxxxxxxxxxxx", // anguzz account
      "lastLogOnDateTime": "2025-07-24T20:56:00.0121036Z"
    },
    {
      "userId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", // user A (to be re-assigned)
      "lastLogOnDateTime": "2025-08-24T20:56:00.0121036Z"
    }
  ]
}
```

## workflow
- Connects to Microsoft Graph with Intune + Directory scopes.  
- Finds all devices where `Primary User == reassignedUPN `.  
- Queries the `usersLoggedOn` (beta) property to identify the last logged-on user.  
- Validates the user and ensures they are not the DEM/staging account.  
- Removes old linked users and assigns the correct user as **Primary User**.  
- Supports `-WhatIf` to preview changes.  
- Outputs results to a CSV report and transcript log.

## requirements
- PowerShell 5.1+ or 7.x  
- Modules:
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.DeviceManagement`
- Permissions:
  - `DeviceManagementManagedDevices.ReadWrite.All`
  - `Directory.Read.All`
- Intune RBAC: **Change Primary User** role

## usage
```powershell
# Default (reassign from DEM to last logged-on user)
.\reassign.ps1 -StagingUserUpn "user@email.com"

# Preview actions without making changes
.\reassign.ps1 -StagingUserUpn "user@email.com" -WhatIf
