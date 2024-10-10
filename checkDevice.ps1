#get device specs if its online and on network based on devicename


$computerName = Read-Host "Please enter the computer name"

# test the device to check if it's online
if (-not (Test-Connection -ComputerName $computerName -Count 1 -Quiet)) {
    Write-Output "The computer '$computerName' is offline."
    exit
}

$credentials = Get-Credential

$cimSession = New-CimSession -ComputerName $computerName -Credential $credentials
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $cimSession
$cpuInfo = Get-CimInstance -ClassName Win32_Processor -CimSession $cimSession
$ramInfo = Get-CimInstance -ClassName Win32_PhysicalMemory -CimSession $cimSession
$diskInfo = Get-CimInstance -ClassName Win32_DiskDrive -CimSession $cimSession

#output
Write-Output "Operating System Info: $($osInfo.Caption), Version: $($osInfo.Version)"
Write-Output "CPU Info: $($cpuInfo.Name), $($cpuInfo.Description)"
Write-Output "Total Visible Memory: $($osInfo.TotalVisibleMemorySize / 1MB) GB"
Write-Output "Disk Info:"
foreach ($disk in $diskInfo) {
    Write-Output "    Model: $($disk.Model), Size: $($disk.Size / 1GB) GB"
}

# #output all ram sticks
Write-Output "RAM Details:"
foreach ($ram in $ramInfo) {
    Write-Output "    $($ram.Manufacturer) $($ram.Capacity / 1GB) GB, Speed: $($ram.Speed) MHz"
}


Remove-CimSession -CimSession $cimSession

Write-Output "CIM session closed."
