
$printerName = "Microsoft XPS Document Writer"

$featureNames = @(
    "Printing-XPSServices-Features",
    "Microsoft-XPS-Document-Writer-Package" # This might be the name on some systems
)

Write-Host "Starting uninstallation process for Microsoft XPS Document Writer..."

try {
    $printer = Get-Printer -Name $printerName -ErrorAction SilentlyContinue
    if ($null -ne $printer) {
        Write-Host "Printer '$($printerName)' found. Attempting to remove..."
        Remove-Printer -Name $printerName -ErrorAction Stop
        Write-Host "Successfully removed printer '$($printerName)'."
    } else {
        Write-Host "Printer '$($printerName)' not found. No action needed for printer removal."
    }
}
catch {
    Write-Host "Error removing printer '$($printerName)': $($_.Exception.Message)"
}

foreach ($featureName in $featureNames) {
    try {
        Write-Host "Checking status of Windows Optional Feature: '$($featureName)'..."
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction SilentlyContinue

        if ($null -ne $feature -and $feature.State -eq 'Enabled') {
            Write-Host "Feature '$($featureName)' is enabled. Attempting to disable..."
            Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -ErrorAction Stop
            Write-Host "Successfully initiated disabling of feature '$($featureName)'. A restart might be required for complete removal."
        } elseif ($null -ne $feature -and $feature.State -eq 'Disabled') {
            Write-Host "Feature '$($featureName)' is already disabled."
        } else {
            Write-Host "Feature '$($featureName)' not found or its state could not be determined."
        }
    }
    catch {
        Write-Host "Error disabling feature '$($featureName)': $($_.Exception.Message)"
    }
}

Write-Host "Microsoft XPS Document Writer uninstallation process completed."

exit 0 # Success