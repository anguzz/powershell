
# Overview
- These scripts showcase how to create entra groups via graph api.

## Group Creation
- The json body to create a group a post request to https://graph.microsoft.com/v1.0/groups is attatched below

```json
$body = @{
    displayName = "Test entra group creation Graph API"
    description = "Example description for new group"
    mailEnabled = $false
    mailNickname = "TestEntraGroup" 
    securityEnabled = $true
}


```
### createGroups.ps1
- `Invoke-MgGraphRequest` to create a group, change the json body to your criteria
- Input: `groups.csv` with a column groupname full of the groups names you want created
- Output: `createdgroups.csv` created groups names, object ids.

### createGroupsCSV.ps1
- Handles the creation of multiple groups via a CSV file.
- Input: `groups.csv` with a column groupname full of the groups names you want created
- Output: `createdgroups.csv` created groups names, object ids.


### Additional Info
`mailnickname` cannot have `@ () \ [] " ; : <> , SPACE` as per `https://learn.microsoft.com/en-us/graph/api/group-post-groups?view=graph-rest-1.0&tabs=http#request-body` so if you pass in groupnames and want similarly named mailnicknames you have to handle those special characters with a sanitize function or ensure your group names are in a format thats mailnickname compatible. 

Currently since in my current usecase `$mailEnabled` is false I am not handling this logic.