#microsoft script to dump enrollment info into csv file for upload to autopilot
Install-PackageProvider -Name NuGet -Confirm:$false -Force
 
Install-Script -Name Get-WindowsAutoPilotInfo -Confirm:$false -Force
 
Set-ExecutionPolicy Bypass -Scope Process
 
Get-WindowsAutoPilotInfo.ps1 -Output 'c:\hash.csv'
