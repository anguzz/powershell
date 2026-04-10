# fetch msi processes and close them through, intune compatible remediation
$installerProcesses = Get-Process msiexec -ErrorAction SilentlyContinue

if ($installerProcesses) {
    Write-Output "Active Windows Installer processes detected. Attempting to terminate."

    $recentEvents = Get-WinEvent -LogName Application -MaxEvents 20 | Where-Object {
        $_.ProviderName -eq "MsiInstaller"
    } | Select-Object TimeCreated, Id, LevelDisplayName, Message

    $recentEvents | Format-Table -AutoSize -Wrap

    try {
        $installerProcesses | Stop-Process -Force -ErrorAction Stop
        Write-Output "Successfully terminated active Windows Installer processes."
        exit 1  # msi was found initially but remediation successful
    }
    catch {
        Write-Output "Failed to terminate Windows Installer processes: $_"
        exit 2  # failed
    }
}
else {
    Write-Output "No active Windows Installer processes detected."
    exit 0  # compliant
}
