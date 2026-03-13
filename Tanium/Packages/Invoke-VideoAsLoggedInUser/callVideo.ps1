# 1. Define paths
$DestinationDir = "C:\Temp\Tanium"
$FilePath = Join-Path $DestinationDir "rick.mp4"
$SourceFile = Join-Path $PSScriptRoot "rickRoll.mp4"

# 2. Ensure directory exists and copy the video
if (!(Test-Path $DestinationDir)) { 
    New-Item -Path $DestinationDir -ItemType Directory -Force 
}
Copy-Item -Path $SourceFile -Destination $FilePath -Force

# 3. Setup execution tools
$WMPPath = "C:\Program Files (x86)\Windows Media Player\wmplayer.exe"
$RunAsUser = "C:\Program Files (x86)\Tanium\Tanium Client\Tools\StdUtils\runasuser64.exe"

# 4. Global Suppression (HKLM) - Requires Admin/System
# These keys tell WMP that the EULA is accepted and it's not the first time running for anyone on the PC
$HKLM_PrefPath = "HKLM:\SOFTWARE\Microsoft\MediaPlayer\Preferences"
$HKLM_PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsMediaPlayer"

if (!(Test-Path $HKLM_PrefPath)) { New-Item -Path $HKLM_PrefPath -Force }
if (!(Test-Path $HKLM_PolicyPath)) { New-Item -Path $HKLM_PolicyPath -Force }

Set-ItemProperty -Path $HKLM_PrefPath -Name "AcceptedEULA" -Value 1 -Type DWord
Set-ItemProperty -Path $HKLM_PrefPath -Name "FirstTime" -Value 1 -Type DWord
Set-ItemProperty -Path $HKLM_PolicyPath -Name "GroupPrivacyAcceptance" -Value 1 -Type DWord

# 5. User-Specific Suppression (HKCU) - Just to be safe for the current session
& $RunAsUser /userenv /current /cmd "reg add 'HKCU\Software\Microsoft\MediaPlayer\Preferences' /v 'AcceptedPrivacyGreeting' /t REG_DWORD /d 1 /f"

# 6. Launch the video in Fullscreen
& $RunAsUser /userenv /current /cmd "`"$WMPPath`" `"$FilePath`" /play /fullscreen"



# 7. Wait before cleanup
Start-Sleep -Seconds 60

# 8. Cleanup staged video
if (Test-Path $FilePath) {
    Remove-Item $FilePath -Force -ErrorAction SilentlyContinue
}