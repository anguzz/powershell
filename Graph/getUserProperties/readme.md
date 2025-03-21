

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
- Handles errors with a `try-catch` block.
- Exports collected data (emails and office locations) to an output CSV file (`Export-Csv`).

## Script 3: Multiple Users Information 
- Advanced Query Parameters: Constructs the API URL with multiple select properties using the `$select` query, which allows the script to fetch specific properties like `onPremisesDistinguishedName` 

- example string `$selectProperties = "mail,officeLocation,onPremisesDistinguishedName"` 

- Ensure the API URL and properly escapes special characters in PowerShell using ``$apiURL = "https://graph.microsoft.com/v1.0/users/$userEmail`?`$select=$selectProperties"`` to ensure successful queries specicially using backticks ` 

## Script 4: 
- Similar to script 3 but using a different property (UserID rather then email) to create an excel sheet 
- Exports User Details by User ID 
`https://graph.microsoft.com/v1.0/users/$userId?$select=userPrincipalName,officeLocation,onPremisesDistinguishedName`
- Input: UserIDs CSV
- Output: UserDetails CSV, including  userPrincipalName(email)  officeLocation,  onPremisesDistinguishedName

## Script 5:
- Stripped down version of script 4 to go from UserID to email and create an excel sheet 
- Input: UserIDs CSV
- Output: UserEmails CSV
