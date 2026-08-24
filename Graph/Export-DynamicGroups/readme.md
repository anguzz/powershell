# Export Microsoft Entra ID Dynamic Groups

## Overview

`Export-DynamicGroups.ps1` exports Microsoft Entra ID dynamic groups and their membership rules to a CSV file.

The CSV provides a centralized view of dynamic group configurations, making it easier to review, document, and audit membership logic without opening each group individually in the Microsoft Entra admin center.

## Features

- Retrieves all dynamic membership groups
- Includes each group's membership rule
- Includes the membership rule processing state
- Exports the results to CSV
- Creates an audit-friendly view for filtering and comparison
- Helps identify inconsistent, outdated, or overly broad rules


## Why This Script Is Needed

The Entra admin center export does not include dynamic membership rules. Its export is limited to fields such as:

- Name
- Object ID
- Group type
- Membership type
- Email
- Source
- Role assignment allowed
- Security enabled
- Teams enabled
- Expires at
- Created at
- Processing status
- Target writeback type
