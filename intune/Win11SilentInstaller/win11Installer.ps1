# Define installer directory and path
$InstallerFolder = "C:\Win11Upgrade"
$InstallerPath = Join-Path $InstallerFolder "Windows11InstallationAssistant.exe"

# Create the folder if it doesn't exist
if (-not (Test-Path $InstallerFolder)) {
    New-Item -Path $InstallerFolder -ItemType Directory -Force | Out-Null
}

# Always delete any existing installer
if (Test-Path $InstallerPath) {
    Remove-Item $InstallerPath -Force
}

# Download the latest Windows 11 Installation Assistant
Write-Host "Downloading fresh copy of Windows 11 Installation Assistant..."
Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=2171764' -OutFile $InstallerPath

# Get the Windows version
$WinVer = (Get-CimInstance -ClassName Win32_OperatingSystem).Version

# Check if the version contains "26100"
if ($WinVer -like "*26100*") {
    Write-Host "Windows version contains 26100."
    New-Item -ItemType File -Path "$InstallerFolder\deviceCurrentlyWindows11.txt" -Force | Out-Null

} else {
    Write-Host "Windows version does not contain 26100."
    #New-ItemProperty -Path "HKEY_LOCAL_MACHINE\SYSTEM\Setup\MoSetup" -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -PropertyType DWord -Value 1 -Force | Out-Null
    #New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\PCHC" -Name "UpgradeEligibility" -PropertyType DWord -Value 1 -Force | Out-Null
    Start-Process -FilePath $InstallerPath -ArgumentList "/quietinstall", "/skipeula", "/auto upgrade", "/NoRestartUI", "/copylogs c:\" -Wait
}

exit 0
