# PowerShell Script: Export Devices with Outdated App Versions

This PowerShell script is designed to connect to Microsoft Graph, retrieve a list of devices running specific applications with versions below a defined threshold, and export the data to a CSV file. It's particularly useful for administrators who need to ensure applications across devices are updated to a minimum required version.


## Overview 
- Connect to Microsoft Graph API: Authenticates and establishes a connection using provided scopes.

- Set Application and Version Filters: Configure the target application's display name and version threshold. Any application version below the specified threshold will be considered outdated.

- Fetch and Filter Applications: Retrieves application data from Microsoft Graph and filters out applications that meet the version criteria.

- Extract Devices with Outdated Versions: For each outdated application, fetch the associated devices and collate their details.

- Export to CSV: Outputs the data of devices with outdated application versions to a CSV file named `AppOutdatedDevices.csv`.

##  Usage
- Update the `$filter` variable with the target application's display name.
- Adjust `$versionThreshold` to set your required minimum app version.
- Run the script in a PowerShell environment with appropriate permissions