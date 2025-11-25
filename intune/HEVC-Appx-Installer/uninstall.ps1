$ErrorActionPreference = "Stop"

$PackageName = "Microsoft.HEVCVideoExtension"

Write-Output "Starting uninstall for: $PackageName"

# 1. Remove provisioned package
$prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $PackageName }

if ($prov) {
    Write-Output "Removing provisioned package: $PackageName"
    Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName
} else {
    Write-Output "No provisioned package found."
}

# 2. Remove per-user installs
$allUsers = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $PackageName }

foreach ($pkg in $allUsers) {
    Write-Output "Removing per-user package: $($pkg.PackageFullName)"
    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers
}

Write-Output "Uninstall completed."
exit 0
