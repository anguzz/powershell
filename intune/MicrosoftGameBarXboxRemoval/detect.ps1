# detect.ps1

try {
    $packageName = "Microsoft.XboxGamingOverlay"
    $gameBarPackage = Get-AppxPackage -AllUsers -Name $packageName -ErrorAction SilentlyContinue

    if ($null -ne $gameBarPackage) {
        exit 1
    } else {
        Write-Host "Compliant: Microsoft.XboxGamingOverlay not found."
        exit 0
    }
}
catch {
    Write-Error "An error occurred during detection: $_"
    exit 1
}