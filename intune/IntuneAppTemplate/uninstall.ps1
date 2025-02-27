# add app name here
$AppName = "app name"

# this searches for the uninstall string at these registry paths
$RegistryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

$Uninstalled = $false

foreach ($Path in $RegistryPaths) {
    $Apps = Get-ChildItem -Path $Path | ForEach-Object {
        $DisplayName = $_.GetValue("DisplayName")
        $UninstallString = $_.GetValue("UninstallString")

        if ($DisplayName -like "*$AppName*") {
            $Guid = $_.PSChildName
            if ($Guid -match "^{.*}$") {
                Write-Host "Uninstalling $DisplayName - $Guid"
                Start-Process "MsiExec.exe" -ArgumentList "/X$Guid /quiet /norestart" -NoNewWindow -Wait
                $Uninstalled = $true
            }
        }
    }
}

if ($Uninstalled) {
    Write-Host "Uninstallation completed successfully."
} else {
    Write-Host "Application '$AppName' not found."
}
