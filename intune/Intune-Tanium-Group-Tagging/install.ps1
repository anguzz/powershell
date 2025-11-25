$tagPath = "HKLM:\SOFTWARE\Tanium\Tanium Client\Sensor Data\Tags\" # this tag localtion is used on single endpoint view in the tanium console, it will appear in the UI under Tags section for the endpoint.
$tagName = "Tag-name-here" # add reg value for site here.


# Ensure the Tags key exists
if (-not (Test-Path $tagPath)) {
    New-Item -Path $tagPath -Force | Out-Null
}
# Create the tag
try {
    New-ItemProperty -Path $tagPath -Name $tagName -PropertyType String -Value "True" -Force | Out-Null
    Write-Output "Tag '$tagName' created successfully."
}
catch {
    Write-Output "Error creating tag '$tagName' : $_"
}   
Write-Output "Tanium tag script completed."
# End of script
exit 0
