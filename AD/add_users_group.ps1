# this script specifically adds one group to a list of users using their samAccountname 
# for example asantoyo@email.com = asantoyo
# if you dont see the users added right away check what domain controller you ran this on with Get-ADDomainController
# in future might be better to make this run off UPN rather then SamAccountName

Import-Module ActiveDirectory
$adminCredentials = Get-Credential -Message "Enter admin credentials"
$groupName = "add_group_name_here"
$userList = @("user1","user2","user3","etc..")
# users just have to comma seperated and have "" around them
# can just parse and format in excel and paste into userlist (maybe later make this read a csv file)


function Test-GroupPermission {
    try {
        # try to get a list of group members (this will fail if the user doesn't have permission)
        Get-ADGroupMember -Identity $groupName -Credential $adminCredentials | Out-Null
        return $true
    } catch {
        Write-Warning "Error: You do not have permission to modify the group '$groupName'."
        return $false
    }
}

if (Test-GroupPermission) {
    foreach ($user in $userList) {
        try {
            # check each user exist
            $userObject = Get-ADUser -Identity $user -Credential $adminCredentials -ErrorAction Stop
            
            # check each user in group or not
            $groupMembers = Get-ADGroupMember -Identity $groupName -Credential $adminCredentials -ErrorAction Stop
            if ($groupMembers.SamAccountName -contains $userObject.SamAccountName) {
                Write-Warning "Warning: User '$user' is already a member of the group '$groupName'."
                continue
            }
            
            # add
            Add-ADGroupMember -Identity $groupName -Members $user -Credential $adminCredentials -ErrorAction Stop
            Write-Host "User '$user' added to the group '$groupName'."
        } catch { #exception err messages
            if ($_.Exception -match "Cannot find an object with identity:") {
                Write-Warning "Error: User '$user' does not exist in Active Directory."
            } elseif ($_.Exception -match "Cannot find an object with identity:") {
                Write-Warning "Error: Group '$groupName' does not exist in Active Directory."
            } else {
                Write-Warning "Error: Failed to add user '$user' to the group '$groupName'. Reason: $($_.Exception.Message)"
            }
        }
    }
} else {
    Write-Warning "Exiting script due to insufficient permissions."
}