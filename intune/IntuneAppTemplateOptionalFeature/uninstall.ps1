
$OptionalFeatureName = "YOUR_FEATURE_NAME_HERE" # Example: "NetFx3"

if ($OptionalFeatureName -eq "YOUR_FEATURE_NAME_HERE" -or -eq $null -or $OptionalFeatureName.Trim() -eq "") {
    Write-Error "Error: OptionalFeatureName is not configured. Please edit the script and set the variable."
    exit 1
}

Write-Host "Starting uninstallation process for Windows Optional Feature: '$($OptionalFeatureName)'..."

try {
    Write-Host "Checking status of Windows Optional Feature: '$($OptionalFeatureName)'..."
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $OptionalFeatureName -ErrorAction SilentlyContinue

    if ($null -ne $feature -and $feature.State -eq 'Enabled') {
        Write-Host "Feature '$($OptionalFeatureName)' is enabled. Attempting to disable..."
        Disable-WindowsOptionalFeature -Online -FeatureName $OptionalFeatureName -NoRestart -ErrorAction Stop
        Write-Host "Successfully initiated disabling of feature '$($OptionalFeatureName)'. A restart is often required for complete removal."
    } elseif ($null -ne $feature -and $feature.State -eq 'Disabled') {
        Write-Host "Feature '$($OptionalFeatureName)' is already disabled."
    } else {
        Write-Host "Feature '$($OptionalFeatureName)' not found or its state could not be determined. This might be normal if it was never installed or already removed."
    }
}
catch {
    Write-Error "Error disabling feature '$($OptionalFeatureName)': $($_.Exception.Message)"
    exit 1
}

Write-Host "Windows Optional Feature '$($OptionalFeatureName)' uninstallation process completed."
exit 0
