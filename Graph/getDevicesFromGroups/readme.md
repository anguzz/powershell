
# Managed Devices Report Generator
This PowerShell script connects to Microsoft Graph API to fetch and report on managed devices associated with the members of a specified Azure Active Directory (AD) group.


# Overview
- Fetch Group Members: Retrieves the members of the specified Azure AD group and their basic details like User Principal Name (UPN) and ID.
- Loops through the members and retrieves each ones managed device
- Output: Outputs a report on all devices
- Use case: Good to check if users in a group have multiple managed devices, and audit user groups devices
- Automation: Works well with power automate for an automated report sent to necessary teams

# Usage
- Add the Group object ID found in entra at `$groupId` to target the group you want


# `getDevicesUserGroupsV2.ps1`
- Will send an extra request against a `device.id` at https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id) to get more information that is only returned at this endpoint. The user endpoint `https://graph.microsoft.com/v1.0/users/$userId/managedDevices` "will return null for certain device properties even if queried, so for the meantime I added this to call the deviceManagment endpoint. 

# `getDevicesDeviceGroup.ps1`
-Grabs devices from a device group. First queries a group for `https://graph.microsoft.com/v1.0/groups/$groupId/members`?`$select=id` and grabs the group member objects id. Using this object ID we query `https://graph.microsoft.com/v1.0/devices/$deviceID` 

This endpoint does not get information based on the managed device ID, which gets information directly from intune but rather gives us information from entra. 

In my use case I only care about the OS version and tracking that, which this allows you to do for devices based on that group. 




