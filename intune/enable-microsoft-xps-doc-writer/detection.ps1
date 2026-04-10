#  detect if Microsoft XPS Document Writer is installed.
# for use as an Intune detection rule.

$featureNames = @(
    "Printing-XPSServices-Features", # Common feature name
    "XPS.Viewer~~~~0.0.1.0" # for the viewer, the user asked for the writer.

)

#  check: Windows Optional Feature
$featureInstalled = $false
$targetFeatureName1 = "Printing-XPSServices-Features" #   most likely one for the service/driver
$targetFeatureName2 = "Microsoft-XPS-Document-Writer" #  how it's listed in "Turn Windows features on or off"

try {
    $feature1 = Get-WindowsOptionalFeature -Online -FeatureName $targetFeatureName1 -ErrorAction SilentlyContinue
    if ($null -ne $feature1 -and $feature1.State -eq [Microsoft.Dism.Commands.FeatureState]::Enabled) {
        $featureInstalled = $true
    }

    if (-not $featureInstalled) {
 
    }

}
catch {
    $featureInstalled = $false
}

$printerInstalled = $false
$printerName = "Microsoft XPS Document Writer"
try {
    $printer = Get-Printer -Name $printerName -ErrorAction SilentlyContinue
    if ($null -ne $printer) {
        $printerInstalled = $true
    }
}
catch {
    $printerInstalled = $false
}




if ($featureInstalled -or $printerInstalled) {
    Write-Host "INSTALLED - Microsoft XPS Document Writer Found" # Standard output Intune looks for
    exit 0 # Success
} else {
    exit 1 # Failure
}