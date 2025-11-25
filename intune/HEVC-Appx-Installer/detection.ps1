$PackageName = "Microsoft.HEVCVideoExtension"

$prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $PackageName }
$pkg  = Get-AppxPackage -AllUsers | Where-Object { $_.Name -eq $PackageName }

if ($prov -or $pkg) {
    Write-Output "HEVC Video Extension is installed."
    exit 0
} else {
    Write-Output "HEVC Video Extension is NOT installed."
    exit 1
}
