
$OptionalFeatureName = "YOUR_FEATURE_NAME_HERE" # Example: "NetFx3"

if ($OptionalFeatureName -eq "YOUR_FEATURE_NAME_HERE" -or -eq $null -or $OptionalFeatureName.Trim() -eq "") {
    Write-Host "Error: OptionalFeatureName is not configured in the detection script. Please edit the script and set the variable."
    exit 1
}

$exitCode = 1

Write-Host "Starting detection for Windows Optional Feature: '$($OptionalFeatureName)'..."

try {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $OptionalFeatureName -ErrorAction SilentlyContinue

    if ($null -ne $feature -and $feature.State -eq 'Enabled') {
        Write-Host "Detected: Feature '$($OptionalFeatureName)' is Enabled."
        $exitCode = 0 # success
    } elseif ($null -ne $feature -and $feature.State -eq 'Disabled') {
        Write-Host "Not Detected: Feature '$($OptionalFeatureName)' is Disabled."
    } else {
        Write-Host "Not Detected: Feature '$($OptionalFeatureName)' not found or state indeterminate."
    }
}
catch {
    Write-Error "Error during feature detection for '$($OptionalFeatureName)': $($_.Exception.Message)"
}

Write-Host "Detection script for '$($OptionalFeatureName)' finished with exit code: $exitCode"
exit $exitCode
