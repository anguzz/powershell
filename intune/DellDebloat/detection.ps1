
$DellAppNamesForAppxCheck = @(
    "DellInc.PartnerPromo",
    "DellInc.DellOptimizer",
    "DellInc.DellCommandUpdate",
    "DellInc.DellPowerManager",
    "DellInc.DellDigitalDelivery",
    "DellInc.DellSupportAssistforPCs"
)

$DellRegistryPatterns = @(
    "*Dell*Optimizer*", # Catches "Dell Optimizer", "Dell Optimizer Service", "Dell Optimizer Core"
   "*Dell*Power*Manager*", # Catches "Dell Power Manager", "Dell Power Manager Service"
    "*Dell*SupportAssist*", # Catches "Dell SupportAssist", "Dell SupportAssist OS Recovery", "Dell SupportAssist Remediation", "SupportAssist Recovery Assistant", "Dell SupportAssist OS Recovery Plugin for Dell Update", "Dell SupportAssistAgent", "Dell Update - SupportAssist Update Plugin"
    "*Dell*Command*Update*", # Catches "Dell Command | Update", "Dell Command | Update for Windows Universal", "Dell Command | Update for Windows 10"
    "*Dell*Digital*Delivery*", # Catches "Dell Digital Delivery Service", "Dell Digital Delivery"
    "*Dell*Peripheral*Manager*", # Catches "Dell Peripheral Manager"
    "*Dell*Core*Services*", # Catches "Dell Core Services"
    "*Dell*Pair*", # Catches "Dell Pair"
    "*Dell*Display*Manager*" # Catches "Dell Display Manager 2.0", "2.1", "2.2" etc.
)

$SpecificUninstallerPaths = @(
  "C:\Program Files\Dell\Dell Peripheral Manager\Uninstall.exe",
    "C:\Program Files\Dell\Dell Pair\Uninstall.exe"
)

$dellAppFound = $false
$foundAppName = "" 

# Check 1: Appx Packages (Installed and Provisioned)
Write-Output "Checking for Appx packages..."
foreach ($appName in $DellAppNamesForAppxCheck) {
    try {
        # Check installed for any user
        if (Get-AppxPackage -Name $appName -AllUsers -ErrorAction SilentlyContinue) {
            $dellAppFound = $true
            $foundAppName = $appName + " (Appx)"
            Write-Output "Found Appx package: $foundAppName"
            break # Exit loop early
        }
        # Check provisioned
        if (Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $appName } -ErrorAction SilentlyContinue) {
            $dellAppFound = $true
            $foundAppName = $appName + " (Provisioned Appx)"
            Write-Output "Found Provisioned Appx package: $foundAppName"
            break # Exit loop early
        }
    } catch {
        Write-Output "Error checking Appx package '$appName': $($_.Exception.Message)"
    }
}

# checks: Registry Uninstall Keys (Win32 Apps) - Only if no Appx found yet
if (-not $dellAppFound) {
    Write-Output "Checking registry for Win32 applications..."
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($pattern in $DellRegistryPatterns) {
        try {
            $foundEntry = Get-ItemProperty -Path $uninstallPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pattern -and $_.PSChildName -ne $null }
            if ($null -ne $foundEntry) {
                $dellAppFound = $true
                # Select the first DisplayName if multiple matches found for the pattern
                $foundAppName = ($foundEntry | Select-Object -First 1).DisplayName + " (Registry Pattern: $pattern)"
                Write-Output "Found Win32 application: $foundAppName"
                break # Exit loop early
            }
        } catch {
            Write-Output "Error checking registry pattern '$pattern': $($_.Exception.Message)"
        }
    }
}

if (-not $dellAppFound) {
    Write-Output "Checking for specific uninstaller files..."
    foreach ($path in $SpecificUninstallerPaths) {
        if (Test-Path -Path $path -PathType Leaf -ErrorAction SilentlyContinue) {
            $dellAppFound = $true
            $foundAppName = $path + " (File Exists)"
            Write-Output "Found specific uninstaller file: $foundAppName"
            break # Exit loop early
        }
    }
}

if ($dellAppFound) {
    Write-Output "Detection FAILED: Targeted Dell application '$foundAppName' still exists."
    # No output to STDOUT
    exit 1
} else {
    Write-Output "Detection SUCCEEDED: No targeted Dell applications found."
    # Output detection string to STDOUT
    Write-Output "Dell Bloatware Removed"
    exit 0
}
