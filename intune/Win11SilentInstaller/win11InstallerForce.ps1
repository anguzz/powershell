# Define installer directory and path
$InstallerFolder = "C:\Win11Upgrade"
$InstallerPath = Join-Path $InstallerFolder "Windows11InstallationAssistant.exe"

# Create the folder if it doesn't exist
if (-not (Test-Path $InstallerFolder)) {
    New-Item -Path $InstallerFolder -ItemType Directory -Force | Out-Null
}

# Delete any existing installer
if (Test-Path $InstallerPath) {
    Remove-Item $InstallerPath -Force
}

# Download latest Windows 11 Installation Assistant
Write-Host "Downloading Windows 11 Installation Assistant..."
Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2171764' -OutFile $InstallerPath

$WinVer = (Get-CimInstance -ClassName Win32_OperatingSystem).Version


if ($WinVer -like "*26100*" -or $WinVer -match "^10\.0\.(2[2-9]\d{3})") {
    Write-Host "Windows version is Windows 11 ($WinVer)."
    New-Item -ItemType File -Path "$InstallerFolder\deviceCurrentlyWindows11.txt" -Force | Out-Null
    exit 0
}


$MoSetupKey = "HKLM:\SYSTEM\Setup\MoSetup"
if (-not (Test-Path $MoSetupKey)) {
    New-Item -Path $MoSetupKey -Force | Out-Null
}
New-ItemProperty -Path $MoSetupKey -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -PropertyType DWord -Value 1 -Force | Out-Null

# PCHC key
$PCHCKey = "HKLM:\SOFTWARE\Microsoft\PCHC"
if (-not (Test-Path $PCHCKey)) {
    New-Item -Path $PCHCKey -Force | Out-Null
}
New-ItemProperty -Path $PCHCKey -Name "UpgradeEligibility" -PropertyType DWord -Value 1 -Force | Out-Null

# Get logged-on user SID
$loggedOnUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName
if ($loggedOnUser) {
    try {
        $sid = (New-Object System.Security.Principal.NTAccount($loggedOnUser)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        $userRegPath = "Registry::HKEY_USERS\$sid\SOFTWARE\Microsoft\PCHC"
        if (-not (Test-Path $userRegPath)) {
            New-Item -Path $userRegPath -Force | Out-Null
        }
        New-ItemProperty -Path $userRegPath -Name "UpgradeEligibility" -PropertyType DWord -Value 1 -Force | Out-Null
        Write-Host "Successfully set HKCU UpgradeEligibility for user: $loggedOnUser"
    } catch {
        Write-Warning "Failed to write UpgradeEligibility to HKCU for $loggedOnUser. Error: $($_.Exception.Message)"
    }
} else {
    Write-Warning "No logged-on user detected. Skipping HKCU registry edit."
}

# Start upgrade
Start-Process -FilePath $InstallerPath -ArgumentList "/quietinstall", "/skipeula", "/auto upgrade", "/NoRestartUI", "/copylogs c:\" -Wait

exit 0
