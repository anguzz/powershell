
$registryPath = "HKLM:\Software\Policies\Google\Update"

$valueName1 = "AutoUpdateCheckPeriodMinutes"
$valueName2 = "UpdateDefault"


Write-Host "Starting removal of specific Chrome auto-update policy registry values..."

try {
    if (Test-Path $registryPath) {
        Write-Host "Registry path '$registryPath' found."

        # attempts to remove the first value if it exists
        if (Get-ItemProperty -Path $registryPath -Name $valueName1 -ErrorAction SilentlyContinue) {
            Write-Host "Removing registry value '$valueName1'..."
            Remove-ItemProperty -Path $registryPath -Name $valueName1 -Force -ErrorAction Stop
            Write-Host "'$valueName1' removed successfully."
        } else {
            Write-Host "Registry value '$valueName1' not found. Skipping removal."
        }

        # attempts to remove the second value if it exists
        if (Get-ItemProperty -Path $registryPath -Name $valueName2 -ErrorAction SilentlyContinue) {
            Write-Host "Removing registry value '$valueName2'..."
            Remove-ItemProperty -Path $registryPath -Name $valueName2 -Force -ErrorAction Stop
            Write-Host "'$valueName2' removed successfully."
        } else {
            Write-Host "Registry value '$valueName2' not found. Skipping removal."
        }

        Write-Host "Chrome auto-update policy removal process completed for specified values."

    } else {
        Write-Host "Registry path '$registryPath' does not exist. No values to remove."
    }

    Exit 0 

} catch {
    $errorMessage = "Error removing Chrome update policy registry values: $($_.Exception.Message)"
    Write-Error $errorMessage
    Exit 1 
}
