[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The old email domain, e.g., 'domain1.com'")]
    [string]$OldDomain = "domain1.com",

    [Parameter(Mandatory = $false, HelpMessage = "The new email domain, e.g., 'domain2.com'")]
    [string]$NewDomain = "domain2.com"
)


$logPath = "C:\Logs"
$logFile = Join-Path -Path $logPath -ChildPath "renameSignaturesDomain.log"

if (-not (Test-Path -Path $logPath -PathType Container)) {
    try {
        New-Item -Path $logPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Warning "Could not create log directory at '$logPath'. Log will not be created. Error: $_"
    }
}

try {
    Start-Transcript -Path $logFile -Append -Force
    
    Write-Host "Starting Outlook signature update process..."
    Write-Host "Old Domain: $OldDomain | New Domain: $NewDomain"

    $explorerProcess = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $explorerProcess) {
        Write-Host "No active user session found (explorer.exe is not running). Exiting."
        exit 0
    }
    $ownerInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwner -ErrorAction SilentlyContinue
    if (-not ($ownerInfo -and $ownerInfo.User)) {
        Write-Warning "Could not determine the owner of the explorer.exe process. Exiting."
        exit 0
    }
    $loggedOnUser = $ownerInfo.User
    $userProfilePath = "C:\Users\$loggedOnUser"
    Write-Host "Detected user profile: $userProfilePath"

    $signaturesPath = Join-Path -Path $userProfilePath -ChildPath "AppData\Roaming\Microsoft\Signatures"
    Write-Host "Target signature path: $signaturesPath"

    if (-not (Test-Path -Path $signaturesPath)) {
        Write-Warning "Signature folder not found at '$signaturesPath'. Nothing to do."
        exit 0
    }

    # --- RENAME FILES AND FOLDERS ---
    Write-Host "---"
    Write-Host "Phase 1: Renaming signature files and folders..."
    $oldFileNamePattern = "*@$OldDomain)*"
    $itemsToRename = Get-ChildItem -Path $signaturesPath | Where-Object { $_.Name -like $oldFileNamePattern }

    if ($null -eq $itemsToRename) {
        Write-Host "No signature files or folders found with the old domain '$OldDomain'."
    } else {
        Write-Host "Found $($itemsToRename.Count) items to rename."
        foreach ($item in ($itemsToRename | Sort-Object { $_.Name.Length } -Descending)) {
            # -replace on the domain string itself for a clean swap
            $newFileName = $item.Name -replace [regex]::Escape($OldDomain), $NewDomain
            
            if ($PSCmdlet.ShouldProcess($item.FullName, "Rename to '$newFileName'")) {
                try {
                    Rename-Item -Path $item.FullName -NewName $newFileName -ErrorAction Stop
                    Write-Host "Renamed: '$($item.Name)' -> '$newFileName'"
                }
                catch {
                    Write-Error "Failed to rename '$($item.FullName)'. Error: $_"
                }
            }
        }
    }
    Write-Host "File renaming phase complete."

    # --- PHASE 2: UPDATE CONTENT INSIDE FILES ---
    Write-Host "---"
    Write-Host "Phase 2: Updating domain references inside signature files."

    $filesToUpdate = Get-ChildItem -Path $signaturesPath -Include "*.htm", "*.rtf", "*.txt" -Recurse -ErrorAction SilentlyContinue

    if ($null -eq $filesToUpdate) {
        Write-Host "No content files (.htm, .rtf, .txt) found to inspect."
    } else {
        #  base domain names (e.g., "domain" from "domain.com") to catch all path variations used by Outlook.
        $OldDomainBase = ($OldDomain -split '\.', 2)[0]
        $NewDomainBase = ($NewDomain -split '\.', 2)[0]

        foreach ($file in $filesToUpdate) {
            try {
                $content = Get-Content -Path $file.FullName -Raw
                
                # Check if either the full domain OR the base domain is present before processing.
                if (($content -match [regex]::Escape($OldDomain)) -or ($content -match [regex]::Escape($OldDomainBase))) {
                    if ($PSCmdlet.ShouldProcess($file.FullName, "Replace all instances of '$OldDomain' and '$OldDomainBase'")) {
                        
                        # performs a case-insensitive replacement for both variants.
                        $updatedContent = $content -replace [regex]::Escape($OldDomain), $NewDomain
                        $updatedContent = $updatedContent -replace [regex]::Escape($OldDomainBase), $NewDomainBase
                        
                        Set-Content -Path $file.FullName -Value $updatedContent -Force
                        Write-Host "Updated content in: $($file.Name)"
                    }
                }
            } catch {
                Write-Warning "Failed to process file '$($file.FullName)'. Error: $_"
            }
        }
    }
    Write-Host "Internal content update finished."
    Write-Host "---"
    Write-Host "Outlook signature update process completed successfully."
}
catch {
    Write-Error "An unexpected error occurred during script execution: $_"
    exit 1
}
finally {
    Stop-Transcript
}