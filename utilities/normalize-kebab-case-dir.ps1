<#
.SYNOPSIS
Normalizes directory (folder) names to kebab-case.

.DESCRIPTION
This script recursively processes all directories and:
- Converts names to lowercase
- Replaces spaces and underscores with dashes
- Splits camelCase / PascalCase into kebab-case
- Cleans duplicate or leading/trailing dashes

Folders are processed from deepest → top to avoid path conflicts.

.NOTES
- Only affects directories (not files)
- Safe to run after file normalization
- Uses temp rename to handle Windows case-insensitivity
#>

Get-ChildItem -Recurse -Directory |
Sort-Object FullName -Descending | ForEach-Object {

    $name = $_.Name

    $newName = [regex]::Replace($name, '(?<=[a-z0-9])(?=[A-Z])', '-')
    $newName = [regex]::Replace($newName, '(?<=[A-Z])(?=[A-Z][a-z])', '-')
    $newName = $newName -replace '[ _]+', '-'
    $newName = $newName.ToLower()
    $newName = $newName -replace '-{2,}', '-'
    $newName = $newName.Trim('-')

    if ($name -ne $newName) {
        $tempName = "__tmp__" + $name

        Write-Host "DIR: $name -> $newName" -ForegroundColor Yellow

        Rename-Item -LiteralPath $_.FullName -NewName $tempName
        Rename-Item -LiteralPath (Join-Path $_.Parent.FullName $tempName) -NewName $newName
    }
}