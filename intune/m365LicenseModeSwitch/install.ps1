$registryPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$regName = "SharedComputerLicensing" # Microsoft default is enabled (shared licensing)

if (-Not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}

if (Get-ItemProperty -Path $registryPath -Name $regName -ErrorAction SilentlyContinue) {
    Set-ItemProperty -Path $registryPath -Name $regName -Value 0
    Write-Host "Updated existing SharedComputerLicensing value to 0 (user licensing)."
} else {
    New-ItemProperty -Path $registryPath -Name $regName -Value 0 -PropertyType String -Force
    Write-Host "Created SharedComputerLicensing value set to 0 (user licensing)."
}
