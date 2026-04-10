<#
.SYNOPSIS
Normalizes filenames to kebab-case across a directory tree.

.DESCRIPTION
This script recursively processes all files in the current directory and:
- Converts filenames to lowercase
- Replaces spaces and underscores with dashes
- Splits camelCase / PascalCase into kebab-case
- Cleans up duplicate or leading/trailing dashes

It uses a safe two-step rename process to handle Windows case-insensitive behavior.

.HOW IT WORKS

1. Enumerates all files recursively using Get-ChildItem -Recurse -File

2. For each file:
   - Extracts the base filename and extension separately

3. Applies transformations to the base name:
   a. Inserts dashes between lowercase/number → uppercase transitions
      Example: getPrimaryUser → get-Primary-User

   b. Inserts dashes in acronym boundaries
      Example: SAMLSSOEntity → SAML-SSO-Entity

   c. Replaces spaces and underscores with dashes
      Example: my_file name → my-file-name

   d. Converts everything to lowercase
      Example: Get-User → get-user

   e. Collapses multiple dashes into one
      Example: my--file → my-file

   f. Trims leading/trailing dashes

4. Reconstructs the filename with the original extension

5. If the name changed:
   - Renames file to a temporary name (prefix "__tmp__")
     This forces Windows to recognize the rename
   - Renames again to the final kebab-case name

6. Outputs changes to console for visibility

.NOTES
- Designed to be safe for large directories
- Avoids over-splitting words (no character-by-character splitting)
- Works well for infrastructure, scripts, and documentation files
- Recommended to run in a Git repo for easy rollback

#>

Get-ChildItem -Recurse -File | ForEach-Object {
    $base = $_.BaseName
    $ext  = $_.Extension

    $newBase = [regex]::Replace($base, '(?<=[a-z0-9])(?=[A-Z])', '-')
    $newBase = [regex]::Replace($newBase, '(?<=[A-Z])(?=[A-Z][a-z])', '-')
    $newBase = $newBase -replace '[ _]+', '-'
    $newBase = $newBase.ToLower()
    $newBase = $newBase -replace '-{2,}', '-'
    $newBase = $newBase.Trim('-')

    $newName = "$newBase$ext"

    if ($_.Name -ne $newName) {
        $tempName = "__tmp__" + $_.Name
        Write-Host "$($_.Name) -> $newName" -ForegroundColor Cyan
        Rename-Item -LiteralPath $_.FullName -NewName $tempName
        Rename-Item -LiteralPath (Join-Path $_.DirectoryName $tempName) -NewName $newName
    }
}