# Intune Logged-On Devices Report for Group Members

## Description

This PowerShell script uses the Microsoft Graph API to identify Intune managed devices where members of a specified Microsoft Entra ID (Azure AD) group have logged on. 

It generates a CSV report containing details about each device found, the specific user from the group who logged onto it, and the timestamp of that user's last logon on that device according to Intune data.

This script is designed to be more efficient than querying devices per-user, especially for large groups or tenants, by fetching all devices once and processing the data locally.


## Required Microsoft Graph Permissions

When connecting using `Connect-MgGraph`, you need **at least** the following delegated permissions granted to your user or the application:

* `DeviceManagementManagedDevices.Read.All`: To read Intune device properties, including the `usersLoggedOn` list (uses `/beta` endpoint).
* `GroupMember.Read.All`: To read the members of the specified Entra ID group.
* `Group.Read.All`: To read the display name of the specified Entra ID group.
