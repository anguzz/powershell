$hostName = Read-Host "Enter host name"

if (-not (Test-Connection -ComputerName $hostName -Count 1 -Quiet)) {
    Write-Output "The host '$hostName' is offline."
    exit
}

$credentials = Get-Credential
$cimSession = New-CimSession -ComputerName $hostName -Credential $credentials
$runningProcesses = Get-CimInstance -ClassName Win32_Process -CimSession $cimSession

Write-Output "List of all running processes on ${hostName}:"
foreach ($process in $runningProcesses) {
    Write-Output "$($process.ProcessId) - $($process.Name)"
}

Remove-CimSession -CimSession $cimSession

Write-Output "CIM session closed."
