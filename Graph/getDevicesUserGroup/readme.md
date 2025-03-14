
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
