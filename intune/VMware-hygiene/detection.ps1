
$AppNamePattern = "VMware Horizon Client"

$AppFound = $false
$ErrorLog = @() 


$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

Write-Verbose "Starting detection for pattern: '$AppNamePattern'"

foreach ($Path in $RegistryPaths) {
    $ParentPath = Split-Path $Path -Parent
    if (!(Test-Path $ParentPath)) {
        Write-Verbose "Registry path '$ParentPath' not found, skipping."
        continue
    }

    Write-Verbose "Checking path: $Path"
    try {
      
        $InstalledApps = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue | Where-Object {
            $_.PSObject.Properties['DisplayName'] -ne $null -and
            $_.DisplayName -like $AppNamePattern -and
            ($_.PSObject.Properties['SystemComponent'] -eq $null -or $_.SystemComponent -ne 1) 
        }

        if ($InstalledApps) {
            $MatchingApp = $InstalledApps | Select-Object -First 1 
            Write-Verbose "Found application: $($MatchingApp.DisplayName)"
            $AppFound = $true
            break 
        }
    } catch {
        $ErrorMessage = "Error accessing registry path '$Path'. Error: $($_.Exception.Message)"
        Write-Warning $ErrorMessage
        $ErrorLog += $ErrorMessage
    }
} 

if ($AppFound) {
    Write-Host "Detected '$AppNamePattern' installed."
    exit 0 
} else {
    Write-Verbose "'$AppNamePattern' not found."
    if ($ErrorLog.Count -gt 0) {
        Write-Verbose "Potential issues during detection:"
        $ErrorLog | ForEach-Object { Write-Verbose $_ }
    }
    exit 0
}