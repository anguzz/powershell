
$OptionalFeatureName = "YOUR_FEATURE_NAME_HERE" # Example: "NetFx3"

if ($OptionalFeatureName -eq "YOUR_FEATURE_NAME_HERE" -or -eq $null -or $OptionalFeatureName.Trim() -eq "") {
    Write-Error "Error: OptionalFeatureName is not configured. Please edit the script and set the variable."
    exit 1
}

Write-Host "Starting installation process for Windows Optional Feature: '$($OptionalFeatureName)'..."

try {
    Write-Host "Checking status of Windows Optional Feature: '$($OptionalFeatureName)'..."
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $OptionalFeatureName -ErrorAction SilentlyContinue

    if ($null -ne $feature -and $feature.State -eq 'Disabled') {
        Write-Host "Feature '$($OptionalFeatureName)' is disabled. Attempting to enable..."
        #  -All switch ensures any parent features are also enabled if necessary.
        Enable-WindowsOptionalFeature -Online -FeatureName $OptionalFeatureName -All -NoRestart -ErrorAction Stop
        Write-Host "Successfully initiated enabling of feature '$($OptionalFeatureName)'. A restart might be required, and source files might be downloaded from Windows Update."
    } elseif ($null -ne $feature -and $feature.State -eq 'Enabled') {
        Write-Host "Feature '$($OptionalFeatureName)' is already enabled."
    } else {
        Write-Host "Feature '$($OptionalFeatureName)' not found or its state could not be determined. Attempting to enable anyway..."
        Enable-WindowsOptionalFeature -Online -FeatureName $OptionalFeatureName -All -NoRestart -ErrorAction Stop
        Write-Host "Attempted to enable feature '$($OptionalFeatureName)'. Check logs for status. A restart might be required."
    }
}
catch {
    Write-Error "Error enabling feature '$($OptionalFeatureName)': $($_.Exception.Message)"
    exit 1
}

Write-Host "Windows Optional Feature '$($OptionalFeatureName)' installation process completed."
exit 0
