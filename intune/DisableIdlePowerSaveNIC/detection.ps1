$logPath = "C:\Logs\IdlePowerSavingLog.txt"

function Write-Log {
    param([string]$message)
    Add-Content -Path $logPath -Value "$(Get-Date -Format 'MM-dd-yyyy HH:mm:ss') - $message"
    Write-Output $message  
}

try {
    if (-not (Test-Path -Path (Split-Path -Path $logPath -Parent))) {
        New-Item -Path (Split-Path -Path $logPath -Parent) -ItemType Directory
    }

    $adapters = Get-NetAdapterAdvancedProperty -DisplayName 'Idle Power Saving' -ErrorAction SilentlyContinue | Where-Object {$_.RegistryValue -eq '1'}

    if ($adapters.Count -eq 0) {
        Write-Log 'No adapter(s) found with Idle Power Saving enabled'
        exit 0
    }
    else {
        Write-Log 'Adapter(s) found with Idle Power Saving enabled'
        foreach ($adapter in $adapters) {
            Write-Log "Idle Power Saving disabled on adapter: $($adapter.Name)"
        }
        exit 1
    }
} 
catch {
    Write-Log 'Error encountered while processing adapters. Please check permissions and adapter status.'
    exit 0
}
