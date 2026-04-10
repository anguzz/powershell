# Get  device specs if it's online and on network, based on device name

$computerName = Read-Host "Please enter the computer name"

# ping first
if (-not (Test-Connection -ComputerName $computerName -Count 1 -Quiet)) {
    Write-Output "The computer '$computerName' is offline."
    exit
}

$credentials = Get-Credential

$cimSession = New-CimSession -ComputerName $computerName -Credential $credentials

# get system info
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $cimSession
$cpuInfo = Get-CimInstance -ClassName Win32_Processor -CimSession $cimSession
$ramInfo = Get-CimInstance -ClassName Win32_PhysicalMemory -CimSession $cimSession
$diskInfo = Get-CimInstance -ClassName Win32_DiskDrive -CimSession $cimSession
$logicalDisks = Get-CimInstance -ClassName Win32_LogicalDisk -CimSession $cimSession -Filter "DriveType = 3"
$videoInfo = Get-CimInstance -ClassName Win32_VideoController -CimSession $cimSession
$networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -CimSession $cimSession -Filter "IPEnabled = True"
$motherboard = Get-CimInstance -ClassName Win32_BaseBoard -CimSession $cimSession
$bios = Get-CimInstance -ClassName Win32_BIOS -CimSession $cimSession
$updates = Get-CimInstance -ClassName Win32_QuickFixEngineering -CimSession $cimSession
$battery = Get-CimInstance -ClassName Win32_Battery -CimSession $cimSession


Write-Output "Operating System Info: $($osInfo.Caption), Version: $($osInfo.Version)"
Write-Output "CPU Info: $($cpuInfo.Name), $($cpuInfo.Description)"
Write-Output "Total Visible Memory: $($osInfo.TotalVisibleMemorySize / 1MB) GB"
Write-Output "Disk Info:"
foreach ($disk in $diskInfo) {
    Write-Output "    Model: $($disk.Model), Size: $($disk.Size / 1GB) GB"
}

Write-Output "Logical Disk Details:"
foreach ($disk in $logicalDisks) {
    $freeSpaceGB = [math]::Round($disk.FreeSpace / 1GB, 2)
    $totalSpaceGB = [math]::Round($disk.Size / 1GB, 2)
    Write-Output "    Drive $($disk.DeviceID): Total Size: $totalSpaceGB GB, Free Space: $freeSpaceGB GB"
}

Write-Output "Graphics Card Info:"
foreach ($video in $videoInfo) {
    Write-Output "    Name: $($video.Name), Driver Version: $($video.DriverVersion), Status: $($video.Status)"
}

Write-Output "Network Adapter Info:"
foreach ($adapter in $networkAdapters) {
    Write-Output "    Description: $($adapter.Description), IP Address: $($adapter.IPAddress[0]), MAC Address: $($adapter.MACAddress)"
}

Write-Output "Motherboard Info: Manufacturer: $($motherboard.Manufacturer), Product: $($motherboard.Product), Serial Number: $($motherboard.SerialNumber)"
Write-Output "BIOS Info: Version: $($bios.SMBIOSBIOSVersion), Manufacturer: $($bios.Manufacturer), Release Date: $($bios.ReleaseDate | Out-String)"


Write-Output "Battery Status:"
foreach ($bat in $battery) {
    Write-Output "    Estimated Charge Remaining: $($bat.EstimatedChargeRemaining)%"
}

Write-Output "RAM Details:"
foreach ($ram in $ramInfo) {
    Write-Output "    $($ram.Manufacturer) $($ram.Capacity / 1GB) GB, Speed: $($ram.Speed) MHz"
}

Remove-CimSession -CimSession $cimSession
Write-Output "CIM session closed."
