
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows Search"

if (-Not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}

try {
    Set-ItemProperty -Path $registryPath -Name "SetupCompletedSuccessfully" -Value 0 -Type DWord
    Write-Host "Registry value set. A rebuild of the Windows Search index will be triggered on the next system restart."
} catch {
    Write-Error "Failed to set the registry value. Error: $_"
    exit
}
