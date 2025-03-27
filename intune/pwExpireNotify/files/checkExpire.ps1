


$tenantID = "" 
$clientID = "" 
$client_secret_name = "Intune_Desktop_Notifications"
$encrypted_client_secret = [Environment]::GetEnvironmentVariable($client_secret_name, [EnvironmentVariableTarget]::Machine)

$secureString = ConvertTo-SecureString $encrypted_client_secret
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
$decrypted_client_secret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
$secureClientSecret = ConvertTo-SecureString $decrypted_client_secret -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($clientID, $secureClientSecret)

Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credential 

$domainEmailExtension="@email.com"
$currentUser = $currentUser = (Get-WmiObject Win32_Process -Filter "Name = 'explorer.exe'").GetOwner().User
#same as doing this $env:USERNAME but since we are runnning via system on intune we will get system or null return hence call who is running explorer graphical process.
$PasswordPolicyInterval = 90

$userPrincipalName = "$currentUser$domainEmailExtension"

$scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition #this is to call the popup script 
$popupScriptPath = Join-Path -Path $scriptPath -ChildPath "popup.ps1" 
$lockedAccountPopUpScriptPath = Join-Path -Path $scriptPath -ChildPath "popup2.ps1" #for locked accounts


Write-Output "`n`n================================================================================================`n`n"
Write-Output "User Principal Name: $userPrincipalName"

Write-Host "Type of userPrincipalName: $($userPrincipalName.GetType().FullName)"

$UserDetails = Get-MgUser -Filter "UserPrincipalName eq '$userPrincipalName'" -Property "DisplayName,LastPasswordChangeDateTime","accountEnabled" | Select-Object DisplayName, LastPasswordChangeDateTime, accountEnabled

if ($null -ne $UserDetails.LastPasswordChangeDateTime) {
    $lastChangeDate = [datetime]$UserDetails.LastPasswordChangeDateTime
    $daysSinceLastChange = (Get-Date) - $lastChangeDate
    $daysRemaining = $PasswordPolicyInterval - $daysSinceLastChange.Days -1 
    $accountEnabled = $UserDetails.accountEnabled

    if (-not $accountEnabled) {
        Write-Output "The account is disabled."
         & $lockedAccountPopUpScriptPath -DaysRemaining $daysRemaining  
    } elseif ($daysRemaining -le 14) {
        Write-Output "The password will expire in $daysRemaining days. Consider changing it soon."
        & $popupScriptPath -DaysRemaining $daysRemaining
    } else {
        Write-Output "Password is within policy limits. ($daysRemaining days left until expiration)"
        #& $popupScriptPath -DaysRemaining $daysRemaining  #uncomment if you want to test
    }
} else {
    Write-Output "No Last Password Change Date available or user details missing."
}

Write-Output "`n`n================================================================================================`n`n"

$null = Disconnect-MgGraph 