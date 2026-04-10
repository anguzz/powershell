Get-ChildItem -Recurse -File |
Rename-Item -NewName {
    $temp = $_.Name -replace "_", "-" 
    $temp = "_" + $temp
    Write-Host "Temp rename: $($_.Name) -> $temp" -ForegroundColor Yellow
    $temp
} -PassThru |
Rename-Item -NewName {
    $final = $_.Name.Substring(1)
    Write-Host "Final rename: $($_.Name) -> $final" -ForegroundColor Cyan
    $final
}