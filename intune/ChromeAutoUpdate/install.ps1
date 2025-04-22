
$registryPath = "HKLM:\Software\Policies\Google\Update"

# Define the policy values
$updateCheckMinutes = 240  # 4 hours 
$updateDefaultPolicy = 1     # 1 = Always allow updates


Write-Host "Starting Chrome auto-update policy configuration..."

try {
    if (-not (Test-Path $registryPath)) {
        Write-Host "Registry path '$registryPath' does not exist. Creating..."
        New-Item -Path $registryPath -Force -ErrorAction Stop | Out-Null
        Write-Host "Successfully created registry path."
    } else {
        Write-Host "Registry path '$registryPath' already exists."
    }

    # sets the AutoUpdateCheckPeriodMinutes value
    Write-Host "Setting 'AutoUpdateCheckPeriodMinutes' to '$updateCheckMinutes'..."
    Set-ItemProperty -Path $registryPath -Name "AutoUpdateCheckPeriodMinutes" -Value $updateCheckMinutes -Type DWord -Force -ErrorAction Stop
    Write-Host "'AutoUpdateCheckPeriodMinutes' set successfully."

    # sets the UpdateDefault value
    Write-Host "Setting 'UpdateDefault' to '$updateDefaultPolicy'..."
    Set-ItemProperty -Path $registryPath -Name "UpdateDefault" -Value $updateDefaultPolicy -Type DWord -Force -ErrorAction Stop
    Write-Host "'UpdateDefault' set successfully."

    Write-Host "Chrome auto-update policy configuration completed successfully."
    Exit 0 

} catch {
    $errorMessage = "Error configuring Chrome update policies: $($_.Exception.Message)"
    Write-Error $errorMessage
    Exit 1 
}
