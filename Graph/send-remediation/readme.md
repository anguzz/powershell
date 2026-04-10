# Overview
This PowerShell script automates the initiation of Proactive Remediations in Microsoft Intune on a list of devices provided in a CSV file.

# Steps

- Connects to Microsoft Graph API using the Microsoft.Graph module.

- Looks up devices by their Intune device name (managed device name).

- Triggers a specified Proactive Remediation Script by GUID using the following endpoint `https://graph.microsoft.com/beta/deviceManagement/managedDevices/$ManagedDeviceId/initiateOnDemandProactiveRemediation` 

- Provides summary of success, failure, and skipped devices.


# Usage
- Ensure you have the Microsoft.Graph PowerShell module installed
- Ensure a csv with `devices.csv` exists with a single column `DeviceName` of device host names
- Run the script in an elevated PowerShell session.
- Input the Proactive Remediation Script ID (GUID) when prompted to run on all devices in the csv file. 


# Output summary
- Number of successful remediation initiations

 - Number of devices not found

 - Number of errors