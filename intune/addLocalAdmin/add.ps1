
$logPath = "C:\logs\AddLocalAdmin.log"
$ErrorActionPreference = 'Stop'

Start-Transcript -Path $logPath -Append -Force

try {
    # gets the upn of the user currently running the explorer.exe process
    $explorerProcess = Get-CimInstance -ClassName Win32_Process -Filter "Name='explorer.exe'"
    $ownerInfo = $explorerProcess | Invoke-CimMethod -MethodName GetOwner
    $upn = $ownerInfo.User

    if (-not $upn) {
        Write-Error "Could not determine the logged-in user's UPN. Explorer.exe process might not be running."
        exit 1
    }

    Write-Host "Identified logged-in user: $upn"

    # for Azure AD joined devices, the format is 'AzureAD\UserUPN'
    $member = "AzureAD\$upn"
    
    # calls the Add-LocalGroupMember cmdlet to add the user to the local Administrators group
    Write-Host "Adding '$member' to the local Administrators group..."
    Add-LocalGroupMember -Group "Administrators" -Member $member
    Write-Host "Successfully added user to the Administrators group."
    
    # success
    exit 0
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
finally {
    Stop-Transcript
}