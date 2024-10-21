#   Set-ExecutionPolicy Unrestricted -Scope CurrentUser

Import-Module PowerShellGet

Install-Module -Name CredentialManager

Import-Module CredentialManager

$credential = Get-StoredCredential -Target 'ADUCAdminAccess'

if ($null -eq $credential) {
    $username = ''
    $securePassword = Read-Host "Enter Password for $username" -AsSecureString
    $credential = New-Object System.Management.Automation.PSCredential($username, $securePassword)
    
    New-StoredCredential -Target 'ADUCAdminAccess' -UserName $username -Password ($credential.GetNetworkCredential().Password) -Persist LocalMachine
} else {
    $securePassword = ConvertTo-SecureString $credential.Password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($credential.UserName, $securePassword)
}

Start-Process "mmc.exe" "dsa.msc" -Credential $credential
