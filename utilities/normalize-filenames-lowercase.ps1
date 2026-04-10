# Source - https://stackoverflow.com/a/70571315
# Posted by Mahmoud Moawad
# Retrieved 2026-04-09, License - CC BY-SA 4.0

# modified by github.com/anguzz 4/9/26

# old commannd no visibility
# Get-ChildItem -r  | Rename-Item -NewName { $_.Name.ToLower().Insert(0,'_') } -PassThru |  Rename-Item -NewName { $_.Name.Substring(1) }


Get-ChildItem -Recurse -File |
Rename-Item -NewName {
    $new = $_.Name.ToLower().Insert(0,'_')
    Write-Host "Temp rename: $($_.Name) -> $new" -ForegroundColor Yellow
    $new
} -PassThru |
Rename-Item -NewName {
    $final = $_.Name.Substring(1)
    Write-Host "Final rename: $($_.Name) -> $final" -ForegroundColor Cyan
    $final
}