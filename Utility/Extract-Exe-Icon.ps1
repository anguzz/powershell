Add-Type -AssemblyName System.Drawing

#  resolve relative to the script's own folder
$exePath  = Join-Path $PSScriptRoot "app_name.exe"
$outPath  = Join-Path $PSScriptRoot "PNG_name.png"

$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)

# save to PNG if found
if ($icon) {
    $icon.ToBitmap().Save($outPath)
    Write-Host "Icon exported successfully to $outPath"
} else {
    Write-Host "No icon found in $exePath"
}
