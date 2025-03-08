

## Overview
This repository includes two PowerShell scripts that demonstrate how to interact with Microsoft Graph API to fetch user details and process them as specific PowerShell objects.

## Script 1: Single User Information
- Connects to Microsoft Graph (`Connect-MgGraph`) with the scope `User.Read.All`.
- Uses `Invoke-MgGraphRequest` to fetch details for a single user by email.
- Response Handling: Converts the API response to a PSObject, focusing on extracting and displaying the mail and officeLocation properties.


## Script 2: Multiple Users Information
- Enhances the first script to handle multiple users.
- Imports a list of user emails from a CSV file (`Import-Csv`).
- Loops through each user, fetching details with `Invoke-MgGraphRequest`.
- Converts responses into PowerShell custom objects (`PSObject`).
- Handles errors gracefully with a `try-catch` block.
- Exports collected data (emails and office locations) to an output CSV file (`Export-Csv`).

