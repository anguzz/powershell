# uninstall.ps1

try {
    $ErrorActionPreference = 'Stop'
    $packagesRemoved = $false

    $packageNames = @(
        "Microsoft.XboxGamingOverlay*",
        "Microsoft.GameOverlay*",
        "Microsoft.XboxGameOverlay*",
        "Microsoft.XboxIdentityProvider*",
        "Microsoft.XboxSpeechToTextOverlay*",
        "Microsoft.Edge.GameAssist*",
        "Microsoft.Xbox.TCUI*",
        "Microsoft.XboxApp*",
        "Microsoft.GamingApp*"
    )

    foreach ($packageName in $packageNames) {
        $installedPackages = Get-AppxPackage -AllUsers -Name $packageName

        if ($installedPackages) {
            $installedPackages | Remove-AppxPackage -AllUsers
            Write-Output "Successfully found and removed package matching: $packageName"
            $packagesRemoved = $true
        } else {
            Write-Output "Package matching '$packageName' not found. Skipping."
        }
    }

    Write-Output "Script completed successfully."
    exit 0
}
catch {
    $errorMessage = "Failed to remove packages. Error: $_"
    Write-Error $errorMessage
    exit 1
}
