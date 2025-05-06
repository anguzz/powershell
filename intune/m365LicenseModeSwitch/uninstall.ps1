$registryPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$regName = "SharedComputerLicensing"
$defaultValue = 1  # Microsoft default is enabled (shared licensing)

if (-Not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}

if (Get-ItemProperty -Path $registryPath -Name $regName -ErrorAction SilentlyContinue) {
    Set-ItemProperty -Path $registryPath -Name $regName -Value $defaultValue
    Write-Host "Reset SharedComputerLicensing to 1 (shared licensing default)."
} else {
    New-ItemProperty -Path $registryPath -Name $regName -Value $defaultValue -PropertyType DWORD -Force
    Write-Host "Created SharedComputerLicensing with default value 1 (shared licensing)."
}
