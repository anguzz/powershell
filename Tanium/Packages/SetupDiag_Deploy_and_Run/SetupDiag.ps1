$ErrorActionPreference = "Stop"

$destFolder   = "C:\SetupDiag"
$exePath      = "$destFolder\SetupDiag.exe"
$logPath      = "$destFolder\SetupDiagResults.log"
$installerUrl = "https://go.microsoft.com/fwlink/?linkid=870142"

try {
    # If exe already exists, do nothing
    if (Test-Path $exePath) {
        Write-Output "SetupDiag already exists. Skipping download and execution."
        exit 0
    }

    # Create folder if missing
    if (-not (Test-Path $destFolder)) {
        New-Item -Path $destFolder -ItemType Directory -Force | Out-Null
    }

    # Enforce TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Download SetupDiag
    Invoke-WebRequest -Uri $installerUrl -OutFile $exePath -UseBasicParsing

    # Execute SetupDiag
    Start-Process -FilePath $exePath `
        -ArgumentList "/Output:$logPath" `
        -Wait -NoNewWindow

    Write-Output "SetupDiag downloaded and executed successfully."
}
catch {
    Write-Error "Deployment failed: $_"
    exit 1
}