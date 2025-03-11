#currently gets all intune windows devices and properties, puts in csv which allows for further filtering 
Import-Module Microsoft.Graph.Authentication

Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"

function Get-WindowsDevices {
    $devices = Get-MgDeviceManagementManagedDevice -All
    
    $windowsDevices = $devices | Where-Object {
        $_.OperatingSystem -eq "Windows"
    }
    
    return $windowsDevices
}

$nonWindows11Devices = Get-WindowsDevices
if ($nonWindows11Devices.Count -gt 0) {
    $nonWindows11Devices | Format-Table Id, DeviceName, OperatingSystem, OperatingSystemVersion | Out-String | Write-Host
    $nonWindows11Devices | Export-Csv -Path "Devices.csv" -NoTypeInformation
} else {
    Write-Host "Error"
}

Disconnect-MgGraph
