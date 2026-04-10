# remove AppXApps(store apps) and provisioned packages via tanium 
# good for both current installs and provisioned packages


$AppID   = "<wingetAPPID>" # used for winget uninstall, e.g. 9NBLGGH42THS = "Microsoft.Microsoft3DViewer"
$StoreAppName = "<AppName>" # "Microsoft.Microsoft3DViewer" example

$LogFile = "C:\logging\RemoveStoreApp-$AppID.txt"
# Ensure logging directory exists
if (!(Test-Path (Split-Path $LogFile))) {
    New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "$timestamp - $Message"
    $line | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Output $line
}

Write-Log "---- Script started ----"

# Step 1: Try winget uninstall
Write-Log "Attempting winget uninstall..."
try {
    winget uninstall --id $AppID --silent --accept-source-agreements --accept-package-agreements | Out-Null
    Write-Log "winget uninstall command executed."
} catch {
    Write-Log "winget uninstall failed or APP ID not set: $($_.Exception.Message)"

}

# Step 2: Remove AppxPackage for all users
Write-Log "Checking for AppxPackage Microsoft.3DViewer..."
$packages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "$StoreAppName*" }

if ($packages) {
    foreach ($pkg in $packages) {
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            Write-Log "Removed AppxPackage: $($pkg.PackageFullName)"

        } catch {
            Write-Log "Failed to remove $($pkg.PackageFullName): $($_.Exception.Message)"
        }
    }
} else {
    Write-Log "No AppxPackage found."
}

# Step 3: Remove provisioned package (prevents it from returning for new users)
Write-Log "Checking provisioned package..."
$provPkg = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "$StoreAppName*" }
if ($provPkg) {
    foreach ($pkg in $provPkg) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
            Write-Log "Removed provisioned package: $($pkg.PackageName)"
        } catch {
            Write-Log "Failed to remove provisioned package $($pkg.PackageName): $($_.Exception.Message)"

        }
    }
} else {
    Write-Log "No provisioned package found."
}

Write-Log "---- Script finished ----`n"
exit 0