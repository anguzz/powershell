Get-Service | Where-Object {
    $_.Name -match 'SupportAssist|Dell.*Assist'
} | Stop-Service -Force -ErrorAction SilentlyContinue


$SAVer = Get-ChildItem -Path HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall, HKLM:\\SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall | Get-ItemProperty | Where-Object {$_.DisplayName -match "SupportAssist"} | Select-Object -Property DisplayVersion, UninstallString, PSChildName
ForEach ($ver in $SAVer) {
    If ($ver.UninstallString) {
        $uninst = $ver.UninstallString ; cmd /c $uninst /quiet /norestart
    }
}

Remove-Item -Path "C:\ProgramData\Dell\SARemediation" -Recurse -Force -ErrorAction SilentlyContinue
