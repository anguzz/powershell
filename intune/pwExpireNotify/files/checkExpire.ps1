# Start-Sleep -Seconds 120 #to allow device to connect to network properly, etc

$AccessTokenName= "GRAPH_PW_EXPIRE_TOKEN" #set in the install script
$AccessTokenString = [System.Environment]::GetEnvironmentVariable($AccessTokenName, [System.EnvironmentVariableTarget]::Machine)

Connect-MgGraph -AccessToken ($AccessTokenString |ConvertTo-SecureString -AsPlainText -Force) -NoWelcome -ErrorAction stop 


$domainEmailExtension="@email.com"
$currentUser = $currentUser = (Get-WmiObject Win32_Process -Filter "Name = 'explorer.exe'").GetOwner().User

#same as doing this $env:USERNAME but since we are runnning via system on intune we will get system or null return hence call who is running explorer graphical process.

$PasswordPolicyInterval = 90

$userPrincipalName = "$currentUser$domainEmailExtension"

$scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition #this is to call the popup script 
$popupScriptPath = Join-Path -Path $scriptPath -ChildPath "popup.ps1"



Write-Output "`n`n================================================================================================`n`n"
Write-Output "User Principal Name: $userPrincipalName"

$UserDetails = Get-MgUser -Filter "UserPrincipalName eq '$userPrincipalName'" -Property "DisplayName,LastPasswordChangeDateTime" | Select-Object DisplayName, LastPasswordChangeDateTime


if ($null -ne $UserDetails.LastPasswordChangeDateTime) {
    $lastChangeDate = [datetime]$UserDetails.LastPasswordChangeDateTime
    $daysSinceLastChange = (Get-Date) - $lastChangeDate
    $daysRemaining = $PasswordPolicyInterval - $daysSinceLastChange.Days
 


    if ($daysRemaining -le 0)  {
        Write-Output "The password has expired or today is the expiration day." #this condition will only occur day of, otherwise user is locked out. 
        & $popupScriptPath -DaysRemaining $daysRemaining #calls my popup script and passes in the days remaining from our api call

    } elseif ($daysRemaining -le 10) {
        Write-Output "The password will expire in $daysRemaining days. Consider changing it soon."
        & $popupScriptPath -DaysRemaining $daysRemaining #calls my popup script and passes in the days remaining from our api call
    } else {
        Write-Output "Password is within policy limits. ($daysRemaining days left until expiration)"
        & $popupScriptPath -DaysRemaining $daysRemaining  #remove after testing

    }
} else {
    Write-Output "No Last Password Change Date available or user details missing."
}
Write-Output "`n`n================================================================================================`n`n"

$null = Disconnect-MgGraph 