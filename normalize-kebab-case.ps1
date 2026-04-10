Get-ChildItem -Recurse -File |
Rename-Item -NewName {
    $name = $_.BaseName
    $ext = $_.Extension

    # 1. Split camelCase / PascalCase
    $name = $name -replace '([a-z0-9])([A-Z])', '$1-$2'
    $name = $name -replace '([A-Z])([A-Z][a-z])', '$1-$2'

    # 2. Replace spaces, underscores, dots → dash
    $name = $name -replace '[\s_.]+', '-'

    # 3. Remove anything not alphanumeric or dash
    $name = $name -replace '[^a-zA-Z0-9-]', ''

    # 4. Lowercase
    $name = $name.ToLower()

    # 5. Remove duplicate dashes
    $name = $name -replace '-{2,}', '-'

    # 6. Trim leading/trailing dashes
    $name = $name.Trim('-')

    $temp = "_" + $name + $ext

    Write-Host "Temp: $($_.Name) -> $temp" -ForegroundColor Yellow
    $temp
} -PassThru |
Rename-Item -NewName {
    $final = $_.Name.Substring(1)
    Write-Host "Final: $($_.Name) -> $final" -ForegroundColor Cyan
    $final
}