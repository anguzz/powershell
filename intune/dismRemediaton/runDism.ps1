#run dism and get generate logging C drive
$LogPath = "C:\Logging"
$LogFile = "DismLog.txt"
if (-Not (Test-Path -Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath
}

$Command = "dism /online /cleanup-image /restorehealth > $LogPath\$LogFile"
Invoke-Expression -Command $Command
Add-Content -Path "$LogPath\$LogFile" -Value "Executed on $(Get-Date)"
