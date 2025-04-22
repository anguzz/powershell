

$registryPath = "HKLM:\Software\Policies\Google\Update"

$expectedCheckMinutes = 240 #minutes (4 hours)
$expectedUpdatePolicy = 1

$valueName1 = "AutoUpdateCheckPeriodMinutes"
$valueName2 = "UpdateDefault"

$detectionStatus = $false 

try {
    if (Test-Path $registryPath) {
        $regKeyProperties = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue

        if ($null -ne $regKeyProperties) {
            $value1Correct = ($regKeyProperties.$valueName1 -ne $null) -and ($regKeyProperties.$valueName1 -eq $expectedCheckMinutes)
            $value2Correct = ($regKeyProperties.$valueName2 -ne $null) -and ($regKeyProperties.$valueName2 -eq $expectedUpdatePolicy)

            if ($value1Correct -and $value2Correct) {
                $detectionStatus = $true
            }
        }
    }

    # --- Output and Exit ---
    if ($detectionStatus) {
        Write-Output "Detected: Chrome update policies '$valueName1' and '$valueName2' are correctly configured."
        Exit 1
    } else {
         Write-Output "Not Detected: Chrome update policies not found or incorrectly configured."
        Exit 0 
    }

} catch {
     Write-Output "Error during detection script execution: $($_.Exception.Message)"
    Exit 0
}

