$registryPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$keyName = "SharedComputerLicensing"
$compliantValues = @("0", "1")  # 0 = user licensing, 1 = Microsoft default

if (Test-Path $registryPath) {
    try {
        $actualValue = (Get-ItemProperty -Path $registryPath -Name $keyName -ErrorAction Stop).$keyName
        if ($compliantValues -contains $actualValue) {
            Write-Host "SharedComputerLicensing is set to a user licensing value (`"$actualValue`")."
            exit 0  
        } else {
            Write-Host "SharedComputerLicensing is set to a device licensing value (`"$actualValue`")."
            exit 1  
        }
    } catch {
        Write-Host "SharedComputerLicensing value not found."
        exit 1  
    }
} else {
    Write-Host "Office ClickToRun registry path not found."
    exit 1  
}
