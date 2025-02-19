# Overview
This collection of PowerShell scripts provides methods for adding devices to a Microsoft Entra group. The scripts progress from a simple addition of a single device based on a device ID(as a simple showcase of how to add a device), to adding devices using their display names as seen in Microsoft Entra or Intune. 

The final script in the series enables bulk addition of devices from a CSV file based on their display names. This scripts is useful for administrators who need to manage device group memberships efficiently without direct access to device IDs.

# use case
The use case for me was I was trying to figure out how to bulk add devices to a group without having their device IDs and add them based off display name. This security group then had an automation I set up via intune to push out a patching solution. 

# Noteable
It's important to note that your account should have the necessary permissions to connect to graph and read device object attributes for this to read, then add them to groups.
