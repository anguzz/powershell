#  script to check updates, services, processes, and scheduled jobs on a remote machine via device name 

$computerName = Read-Host "Please enter the computer name"
$credentials = Get-Credential

$cimSession = New-CimSession -ComputerName $computerName -Credential $credentials

$updates = Get-CimInstance -ClassName Win32_QuickFixEngineering -CimSession $cimSession
Write-Output "Installed Updates:"
foreach ($update in $updates) {
    Write-Output "    Hotfix ID: $($update.HotFixID), Description: $($update.Description), Installed On: $($update.InstalledOn)"
}

$services = Get-CimInstance -ClassName Win32_Service -CimSession $cimSession
Write-Output "Services Info:"
foreach ($service in $services) {
    Write-Output "    Name: $($service.Name), Status: $($service.State), Start Mode: $($service.StartMode)"
}

$processes = Get-CimInstance -ClassName Win32_Process -CimSession $cimSession
Write-Output "Processes Info:"
foreach ($process in $processes) {
    Write-Output "    Process Name: $($process.Name), Process ID: $($process.ProcessId), Memory Usage: $($process.WorkingSetSize / 1MB) MB"
}

$jobs = Get-CimInstance -ClassName Win32_ScheduledJob -CimSession $cimSession
Write-Output "Scheduled Jobs Info:"
foreach ($job in $jobs) {
    Write-Output "    Job ID: $($job.JobId), Command: $($job.Command), Next Run Time: $($job.NextRun)"
}

Remove-CimSession -CimSession $cimSession
Write-Output "CIM session closed."
