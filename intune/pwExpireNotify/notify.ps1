# Start-Sleep -Seconds 120 #to allow device to connect to network properly, etc

Connect-MgGraph -Scopes "User.Read.All"

$accessToken = ""#add your applications access token here
Connect-MgGraph -AccessToken ($accessToken |ConvertTo-SecureString -AsPlainText -Force) 


$currentUser = $env:USERNAME
$PasswordPolicyInterval = 90
$userPrincipalName = "$currentUser@fbmsales.com"

$wshell = New-Object -ComObject Wscript.Shell 

Write-Output "`n`n================================================================================================`n`n"
Write-Output "User Principal Name: $userPrincipalName"

$UserDetails = Get-MgUser -Filter "UserPrincipalName eq '$userPrincipalName'" -Property "DisplayName,LastPasswordChangeDateTime" | Select-Object DisplayName, LastPasswordChangeDateTime

if ($null -ne $UserDetails.LastPasswordChangeDateTime) {
    $lastChangeDate = [datetime]$UserDetails.LastPasswordChangeDateTime
    $daysSinceLastChange = (Get-Date) - $lastChangeDate
    $daysRemaining = $PasswordPolicyInterval - $daysSinceLastChange.Days
    Write-Output "Days remaining: $daysRemaining"

    if ($daysRemaining -le 0) {
        Write-Output "The password has expired or today is the expiration day."
        $wshell.Popup("Your password has expired or today is the expiration day. `n`n`You can update your password from any browser at https://myaccount.microsoft.com ",0,"Done",0x0)        

    } elseif ($daysRemaining -le 10) {
        Write-Output "The password will expire in $daysRemaining days. Consider changing it soon."
        $wshell.Popup("Your password will expire in $daysRemaining days. `n`n`You can update your password from any browser at https://myaccount.microsoft.com ",0,"Done",0x0)        
    } else {
        Write-Output "Password is within policy limits. ($daysRemaining days left until expiration)"
        $wshell.Popup( "TEST - Password is within policy limits. ($daysRemaining days left until expiration)",0,"Done",0x0)        

    }
} else {
    Write-Output "No Last Password Change Date available or user details missing."
}
Write-Output "`n`n================================================================================================`n`n"

Disconnect-MgGraph