$ErrorActionPreference = "Stop"

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$app = Join-Path $scriptPath "package\Microsoft.HEVCVideoExtension_2.4.39.0_neutral_~_8wekyb3d8bbwe.appxbundle"

Write-Output "Provisioning AppxBundle for all users: $app"

if (-not (Test-Path $app)) {
    Write-Error "App bundle not found at path: $app"
    exit 1
}

Add-AppProvisionedPackage -Online -PackagePath $app -SkipLicense

Write-Output "Provisioned successfully."
exit 0
