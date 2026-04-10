$registryPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"
$keyName = "SharedComputerLicensing"
$expectedValue = "0" 

if (Test-Path $registryPath) {
    try {
        $actualValue = (Get-ItemProperty -Path $registryPath -Name $keyName -ErrorAction Stop).$keyName
        if ($actualValue -eq $expectedValue) {
            Write-Host "SharedComputerLicensing is set to user licensing (`"$actualValue`")."
            exit 0  
        } else {
            Write-Host "SharedComputerLicensing is set to shared device licensing (`"$actualValue`")."
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
