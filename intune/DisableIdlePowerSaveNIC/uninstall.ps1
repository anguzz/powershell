$logPath = "C:\Logs\IdlePowerSavingLog.txt"

if (-not (Test-Path -Path (Split-Path -Path $logPath -Parent))) {
    New-Item -Path (Split-Path -Path $logPath -Parent) -ItemType Directory
}

function Write-Log {
    param([string]$message)
    Add-Content -Path $logPath -Value "$(Get-Date -Format 'MM-dd-yyyy HH:mm:ss') - $message"
    Write-Output $message 
}

$adapters = Get-NetAdapterAdvancedProperty -DisplayName 'Idle Power Saving' | Where-Object {$_.RegistryValue -eq '0'}
foreach ($adapter in $adapters) {
    Write-Log "Found adapter with Idle Power Saving disabled: $($adapter.Name)"
    Set-NetAdapterAdvancedProperty -InterfaceDescription $adapter.InterfaceDescription -DisplayName 'Idle Power Saving' -RegistryValue '1'
    Write-Log "Enabled Idle Power Saving on adapter: $($adapter.Name)"
}
