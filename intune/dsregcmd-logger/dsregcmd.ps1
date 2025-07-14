$logDir = "C:\logs\dsregcmd"
if (!(Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "$logDir\dsregcmd_$timestamp.txt"

dsregcmd /status | Out-File -FilePath $logFile -Encoding UTF8

dsregcmd /refreshprt


exit 0