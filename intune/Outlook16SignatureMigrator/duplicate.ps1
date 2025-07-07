[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The old email domain, e.g., 'domain1.com'")]
    [string]$OldDomain = "domain1.com",

    [Parameter(Mandatory = $false, HelpMessage = "The new email domain, e.g., 'domain2.com'")]
    [string]$NewDomain = "domain2.com"
)

$logPath = "C:\Logs"
$logFile = Join-Path -Path $logPath -ChildPath "duplicateSignatures.log"

if (-not (Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

try {
    Start-Transcript -Path $logFile -Append -Force

    $explorerProcess = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" | Select-Object -First 1
    if (-not $explorerProcess) { throw "Explorer process not found." }

    $ownerInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwner
    if (-not ($ownerInfo -and $ownerInfo.User)) { throw "Unable to determine logged-on user." }

    $loggedOnUser = $ownerInfo.User
    $userProfilePath = "C:\Users\$loggedOnUser"
    $signaturesPath = Join-Path -Path $userProfilePath -ChildPath "AppData\Roaming\Microsoft\Signatures"

    if (-not (Test-Path -Path $signaturesPath)) { throw "Signature path not found: $signaturesPath" }

    function Duplicate-Signatures {
        param (
            [string]$SourceDomain,
            [string]$TargetDomain
        )

        Write-Host "Duplicating signatures from $SourceDomain to $TargetDomain..."

        $itemsToDuplicate = Get-ChildItem -Path $signaturesPath | Where-Object { $_.Name -like "*@$SourceDomain)*" }

        foreach ($item in $itemsToDuplicate) {
            $newName = $item.Name -replace [regex]::Escape($SourceDomain), $TargetDomain
            $newPath = Join-Path -Path $signaturesPath -ChildPath $newName

            if (-not (Test-Path -Path $newPath)) {
                if ($item.PSIsContainer) {
                    Copy-Item -Path $item.FullName -Destination $newPath -Recurse -Force
                    Write-Host "Copied folder: $($item.Name) -> $newName"
                } else {
                    Copy-Item -Path $item.FullName -Destination $newPath -Force
                    Write-Host "Copied file: $($item.Name) -> $newName"
                }
            } else {
                Write-Host "Skipped (already exists): $newName"
            }
        }
    }

    # Perform bidirectional duplication
    Duplicate-Signatures -SourceDomain $OldDomain -TargetDomain $NewDomain
    Duplicate-Signatures -SourceDomain $NewDomain -TargetDomain $OldDomain

    # Unified content update
    Write-Host "Updating all signature contents to reference unified branding domain: $NewDomain"

    $brandingDomain = $NewDomain
    $brandingBase = ($NewDomain -split '\.', 2)[0]

    $allSignatureFiles = Get-ChildItem -Path $signaturesPath -Include "*.htm", "*.rtf", "*.txt" -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $allSignatureFiles) {
        try {
            $content = Get-Content -Path $file.FullName -Raw -Encoding Default

            # Preserve image paths in RTF files to avoid breaking links to _files folders
            if ($file.Extension -ne ".rtf") {
                $updatedContent = $content -replace [regex]::Escape($OldDomain), $brandingDomain
                $updatedContent = $updatedContent -replace [regex]::Escape($NewDomain), $brandingDomain
            } else {
                $updatedContent = $content
            }

            $updatedContent = $updatedContent -replace [regex]::Escape(($OldDomain -split '\.', 2)[0]), $brandingBase
            $updatedContent = $updatedContent -replace [regex]::Escape(($NewDomain -split '\.', 2)[0]), $brandingBase

            Set-Content -Path $file.FullName -Value $updatedContent -Force -Encoding Default
            Write-Host "Updated content in: $($file.Name)"
        } catch {
            Write-Warning "Failed to update content in: $($file.FullName). Error: $_"
        }
    }

    Write-Host "Signature duplication and content unification completed."
}
catch {
    Write-Error "An unexpected error occurred: $_"
    exit 1
}
finally {
    Stop-Transcript
}
