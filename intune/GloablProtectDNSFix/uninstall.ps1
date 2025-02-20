$registryPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Palo Alto Networks\GlobalProtect\Settings"
$valueName = "DNSBlockMethod"

try {
    if (Test-Path -Path "$registryPath\$valueName") {
        Remove-ItemProperty -Path $registryPath -Name $valueName -ErrorAction Stop
        Write-Host "Registry value '$valueName' removed successfully."
    } else {
        Write-Host "Registry value '$valueName' does not exist."
    }
}
catch {
    Write-Error "Failed to remove registry value: $_"
    exit 1
}
