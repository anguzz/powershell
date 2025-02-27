$AppName = "app display name"
$AppVersion = "version wanted"

Write-Host "Custom script based detection : $AppName"

# Define the registry path for uninstall information
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
$regPath += "*"
$regPath64 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
$regPath64 += "*"

# Search both 32-bit and 64-bit registry paths for the application
$appRegKey = Get-ItemProperty -Path $regPath, $regPath64 -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq $AppName }

if ($appRegKey) {
    $installedVersion = $appRegKey.DisplayVersion
    Write-Host "Detected version: $installedVersion, Required version: $AppVersion"
    if ($installedVersion -eq $AppVersion) {
        Write-Host "Correct version of $AppName is installed."
        Exit 0
    } else {
        Write-Host "Version mismatch. Installed version: $installedVersion"
        Exit 1 # Indicates version mismatch
    }
} else {
    Write-Host "Application $AppName not found on the system."
    Exit 1
}
