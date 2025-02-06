# Adds a user as a local admin on a machine over the network via PowerShell Remoting and lists the local administrators, 
# similar to using computer managment but uses WS-Man instead of RPC/DCOM 


$computerName = Read-Host "Please enter the computer name"

Write-Progress -Activity "Checking network connection" -Status "Pinging $computerName"
if (-not (Test-Connection -ComputerName $computerName -Count 1 -Quiet)) {
    Write-Output "The computer '$computerName' is offline."
    exit
}

$credentials = Get-Credential


Write-Progress -Activity "Connecting to $computerName" -Status "Establishing remote session"
try {
    $session = New-PSSession -ComputerName $computerName -Credential $credentials
} catch {
    Write-Output "Failed to establish a remote session to '$computerName': $_"
    exit
}


if (-not $session) {
    Write-Output "No session could be created, exiting."
    exit
}


$userSamAccountName = Read-Host "Enter samAccountName of the user to add as a local admin"


Write-Progress -Activity "Modifying Administrators group" -Status "Adding $userSamAccountName to Administrators"
try {
    Invoke-Command -Session $session -ScriptBlock {
        Param($userSamAccountName)
        Add-LocalGroupMember -Group "Administrators" -Member $userSamAccountName
    } -ArgumentList $userSamAccountName
    Write-Output "User '$userSamAccountName' added to the local Administrators group on '$computerName'."
} catch {
    Write-Output "Failed to add user '$userSamAccountName' to the local Administrators group: $_"
}

# this prints all the local admins on the device after 
try {
    $adminGroup = Invoke-Command -Session $session -ScriptBlock { Get-LocalGroupMember -Group "Administrators" }
    Write-Output "Current members of the local Administrators group on '$computerName':"
    foreach ($member in $adminGroup) {
        Write-Output "`t$member.Name"
    }
} catch {
    Write-Output "Failed to retrieve members of the local Administrators group: $_"
}


Remove-PSSession -Session $session
Write-Output "Remote session closed."
