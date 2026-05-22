<#
.SYNOPSIS
    Single-file Microsoft Store AppX/MSIX downloader helper with WPF UI.

.DESCRIPTION
    - Search Microsoft Store apps through winget msstore source
    - Resolve ProductId and Store URL
    - Manual Store URL/ProductId fallback
    - Query rg-adguard for package links
    - Download valid .appx/.appxbundle/.msix/.msixbundle packages
    - Skip encrypted .eappx/.emsix packages by default
    - Show SHA256 and Authenticode signature status
    - Install downloaded packages for the current user with Add-AppxPackage

.NOTES
    This is a helper tool for lab/admin use when the Microsoft Store app is blocked or unavailable.
    It relies on winget for search resolution and rg-adguard for package link resolution.

    Current-user install uses Add-AppxPackage and normally does not require Administrator.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# -----------------------------
# Globals
# -----------------------------

$script:LogFile = Join-Path $PSScriptRoot ("StoreAppxDownloader_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
$script:CurrentApp = $null
$script:CurrentPackages = @()
$script:DownloadedFiles = @()
$script:LastDownloadPath = ""
$script:CancelRequested = $false

$script:PackageExtensions = @(".appx", ".appxbundle", ".msix", ".msixbundle")
$script:EncryptedExtensions = @(".eappx", ".eappxbundle", ".emsix", ".emsixbundle")

# -----------------------------
# Helper Functions
# -----------------------------

function Write-Log {
    param(
        [ValidateSet("Info", "Success", "Warning", "Error", "Progress")]
        [string]$Level,
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $line -Encoding UTF8

    if ($script:LogListBox) {
        $item = [pscustomobject]@{
            Time    = $timestamp
            Level   = $Level
            Message = $Message
        }
        [void]$script:LogListBox.Items.Add($item)
        try { $script:LogListBox.ScrollIntoView($item) } catch { }
    }

    if ($script:StatusTextBlock) {
        $script:StatusTextBlock.Text = $Message
    }
}

function Add-Log {
    param(
        [ValidateSet("Info", "Success", "Warning", "Error", "Progress")]
        [string]$Level,
        [string]$Message
    )

    Write-Log -Level $Level -Message $Message
}

function Show-StoreLiftMessage {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$Title,
        [System.Windows.MessageBoxButton]$Buttons = [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::None
    )

    try {
        return [System.Windows.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
    }
    catch {
        Write-Log -Level Error -Message $Message
        return $null
    }
}

function Set-UiBusy {
    param([bool]$Busy)

    $script:SearchButton.IsEnabled = -not $Busy
    $script:ResolveButton.IsEnabled = -not $Busy
    $script:DownloadButton.IsEnabled = -not $Busy
    if ($script:InstallButton) {
        $canInstall = (-not $Busy) -and (-not [string]::IsNullOrWhiteSpace($script:LastDownloadPath)) -and (Test-Path $script:LastDownloadPath)
        $script:InstallButton.IsEnabled = $canInstall
    }
    $script:OpenFolderButton.IsEnabled = -not $Busy
    $script:BrowseButton.IsEnabled = -not $Busy
    $script:StopButton.IsEnabled = $Busy
}

function Hide-InlineInstallButton {
    $script:DownloadedFiles = @()
    $script:LastDownloadPath = ""
    if ($script:InstallButton) {
        $script:InstallButton.Visibility = "Visible"
        $script:InstallButton.IsEnabled = $false
    }
}

function Show-InlineInstallButton {
    param([Parameter(Mandatory)][string]$Path)
    $script:LastDownloadPath = [string]$Path
    if ($script:InstallButton) {
        $script:InstallButton.Visibility = "Visible"
        $script:InstallButton.IsEnabled = $true
    }
}

function ConvertTo-StoreUrl {
    param([Parameter(Mandatory)][string]$ProductId)
    return "https://apps.microsoft.com/detail/$($ProductId.Trim().ToUpper())"
}

function Resolve-ManualStoreInput {
    param([Parameter(Mandatory)][string]$InputText)

    $value = $InputText.Trim()

    if ($value -match 'apps\.microsoft\.com/detail/(?<ProductId>[^/?#]+)') {
        $productId = $Matches.ProductId.Trim().ToUpper()
        return [pscustomobject]@{
            Name      = "Manual Store URL"
            ProductId = $productId
            Publisher = "Unknown"
            Version   = "Unknown"
            StoreUrl  = ConvertTo-StoreUrl -ProductId $productId
            Source    = "ManualUrl"
        }
    }

    if ($value -match '^(?<ProductId>[A-Z0-9]{10,}|XP[A-Z0-9]+)$') {
        $productId = $Matches.ProductId.Trim().ToUpper()
        return [pscustomobject]@{
            Name      = "Manual ProductId"
            ProductId = $productId
            Publisher = "Unknown"
            Version   = "Unknown"
            StoreUrl  = ConvertTo-StoreUrl -ProductId $productId
            Source    = "ManualProductId"
        }
    }

    throw "Manual input must be a Microsoft Store URL or ProductId."
}

function Search-MicrosoftStoreApp {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Query)

    if ([string]::IsNullOrWhiteSpace($Query)) {
        throw "Enter an app name to search."
    }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget.exe was not found. Install App Installer or use manual Store URL/ProductId input."
    }

    Write-Log -Level Info -Message "Searching Microsoft Store source for: $Query"

    $raw = & winget search --name $Query --source msstore --accept-source-agreements --disable-interactivity 2>&1
    $lines = @($raw | ForEach-Object {
        # Strip ANSI/control characters that can break parsing in Windows Terminal/PowerShell 7.
        ($_.ToString() -replace '\x1B\[[0-?]*[ -/]*[@-~]', '')
    })

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^Name\s+Id\s+Version') { continue }
        if ($trimmed -match '^-{2,}') { continue }
        if ($trimmed -match '^No package found') { continue }
        if ($trimmed -match '^The `msstore` source') { continue }
        if ($trimmed -match '^Found\s+') { continue }

        # Winget msstore rows are usually: Name<spaces>ProductId<spaces>Version
        # Names can contain spaces and hyphens, so capture the ProductId from near the end.
        if ($trimmed -notmatch '^(?<Name>.+?)\s{2,}(?<Id>(?:[A-Z0-9]{10,}|XP[A-Z0-9]+))\s+(?<Version>\S+)$') {
            continue
        }

        $name = $Matches.Name.Trim()
        $id = $Matches.Id.Trim().ToUpper()
        $version = $Matches.Version.Trim()

        [void]$results.Add([pscustomobject]@{
            Name      = $name
            ProductId = $id
            Publisher = "Unknown"
            Version   = $version
            StoreUrl  = ConvertTo-StoreUrl -ProductId $id
            Source    = "winget/msstore"
        })
    }

    if ($results.Count -eq 0) {
        Write-Log -Level Warning -Message "No parsable Store results found. Try a more specific search or paste a Store URL/ProductId."
    }
    else {
        Write-Log -Level Success -Message "Found $($results.Count) Store result(s). Select one and click Preview Packages."
    }

    return $results
}

function Get-TargetArchitecture {
    param([string]$Selection)

    if ($Selection -eq "Auto") {
        switch ($env:PROCESSOR_ARCHITECTURE) {
            "AMD64" { return "x64" }
            "IA64"  { return "x64" }
            "ARM64" { return "arm64" }
            "x86"   { return "x86" }
            default { return "x64" }
        }
    }

    return $Selection.ToLower()
}

function Test-ValidPackageLink {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$FileName,
        [bool]$IncludeEncrypted = $false
    )

    $nameToCheck = if (-not [string]::IsNullOrWhiteSpace($FileName)) {
        $FileName.ToLower()
    }
    else {
        ([System.Uri]::UnescapeDataString(([uri]$Url).AbsolutePath)).ToLower()
    }

    foreach ($ext in $script:EncryptedExtensions) {
        if ($nameToCheck.EndsWith($ext)) {
            return $IncludeEncrypted
        }
    }

    $isPackage = $false
    foreach ($ext in $script:PackageExtensions) {
        if ($nameToCheck.EndsWith($ext)) {
            $isPackage = $true
            break
        }
    }

    if (-not $isPackage) { return $false }

    # Microsoft CDN links from rg-adguard commonly use delivery.mp.microsoft.com.
    # Some URLs do not end in .appx/.msix, so validate extension from link text/file name instead.
    if ($Url -notmatch '^https?://.+delivery\.mp\.microsoft\.com/') {
        return $false
    }

    return $true
}

function Get-FileNameFromHeadResponse {
    param(
        [string]$Url,
        [Microsoft.PowerShell.Commands.WebResponseObject]$Response
    )

    $contentDisposition = $Response.Headers["Content-Disposition"]

    # RFC 5987 style: filename*=UTF-8''SomeFile.msixbundle
    # PowerShell single-quoted strings escape a single quote by doubling it, not with backslash.
    if ($contentDisposition -and $contentDisposition -match 'filename\*=UTF-8''''(?<Name>[^;]+)') {
        return [System.Uri]::UnescapeDataString($Matches.Name)
    }

    # Normal Content-Disposition style: filename="SomeFile.msixbundle"
    if ($contentDisposition -and $contentDisposition -match 'filename="?(?<Name>[^";]+)"?') {
        return $Matches.Name
    }

    return [System.IO.Path]::GetFileName(([uri]$Url).AbsolutePath)
}

function Get-PackageTypeFromName {
    param([string]$FileName)

    if ($FileName -match 'VCLibs|UI\.Xaml|NET\.Native|WindowsAppRuntime|Microsoft\.NET') {
        return "Dependency"
    }

    return "Main"
}

function Get-ArchitectureFromName {
    param([string]$FileName)

    if ($FileName -match '_x64_') { return "x64" }
    if ($FileName -match '_x86_') { return "x86" }
    if ($FileName -match '_arm64_') { return "arm64" }
    if ($FileName -match '_arm_') { return "arm" }
    if ($FileName -match '_neutral_') { return "neutral" }
    return "bundle/unknown"
}

function Test-PackageArchitectureMatch {
    param(
        [string]$FileName,
        [string]$Architecture
    )

    $name = $FileName.ToLower()

    if ($Architecture -eq "neutral") {
        return ($name -match '_neutral_')
    }

    # Always allow neutral dependencies and bundles that do not clearly expose arch in filename.
    if ($name -match '_neutral_') { return $true }
    if ($name -notmatch '_(x64|x86|arm64|arm)_') { return $true }

    return ($name -match "_$Architecture`_")
}

function ConvertTo-SafeInt64 {
    param([object]$Value)

    try {
        if ($null -eq $Value) { return [int64]0 }
        if ($Value -is [array]) {
            if ($Value.Count -eq 0) { return [int64]0 }
            $Value = $Value[0]
        }
        $text = ([string]$Value).Trim()
        if ([string]::IsNullOrWhiteSpace($text)) { return [int64]0 }
        return [int64]$text
    }
    catch {
        return [int64]0
    }
}

function Get-PackageVersionFromName {
    param([string]$FileName)

    if ($FileName -match '_(?<Version>\d+\.\d+(?:\.\d+){0,3})_') {
        return [string]$Matches.Version
    }

    return '0.0.0.0'
}

function Get-PackageVersionSortKey {
    param([string]$FileName)

    $versionText = Get-PackageVersionFromName -FileName $FileName
    $parts = @($versionText -split '\.')
    while ($parts.Count -lt 4) { $parts += '0' }

    $safeParts = foreach ($part in $parts[0..3]) {
        try { '{0:D10}' -f ([int64]$part) } catch { '0000000000' }
    }

    return ($safeParts -join '.')
}

function Get-PackageFamilyFromName {
    param([string]$FileName)

    $name = [System.IO.Path]::GetFileName($FileName)

    if ($name -match '^(?<Name>.+?)_(?<Version>\d+\.\d+(?:\.\d+){0,3})_.*__(?<Publisher>[^\.]+)\.') {
        return ("{0}__{1}" -f $Matches.Name, $Matches.Publisher).ToLower()
    }

    if ($name -match '^(?<Name>.+?)_(?<Version>\d+\.\d+(?:\.\d+){0,3})_') {
        return $Matches.Name.ToLower()
    }

    return ([System.IO.Path]::GetFileNameWithoutExtension($name)).ToLower()
}

function Select-NewestStorePackages {
    param([array]$Packages)

    $items = @($Packages | Where-Object { $null -ne $_ })
    if ($items.Count -le 1) { return $items }

    # Avoid Dictionary.ContainsKey()/generic collection behavior that can throw
    # "Argument types do not match" on some Windows PowerShell + WPF hosts.
    # Use Group-Object and string sort keys only.
    $selected = @()
    $groups = $items | Group-Object -Property PackageType, PackageFamily, Architecture

    foreach ($group in @($groups)) {
        $best = @($group.Group) |
            Sort-Object `
                @{ Expression = { Get-PackageVersionSortKey -FileName ([string]$_.FileName) }; Descending = $true }, `
                @{ Expression = { ConvertTo-SafeInt64 -Value $_.SizeBytes }; Descending = $true }, `
                @{ Expression = { [string]$_.FileName }; Descending = $false } |
            Select-Object -First 1

        if ($null -ne $best) {
            $selected += $best
        }
    }

    $ordered = @($selected) | Sort-Object PackageType, PackageFamily, Architecture, FileName
    $removed = @($items).Count - @($ordered).Count
    if ($removed -gt 0) {
        Write-Log -Level Info -Message "Filtered out $removed older duplicate package version(s)."
    }

    return @($ordered)
}

function Get-StorePackageLinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$StoreUrl,
        [string]$ProductId,
        [ValidateSet("Auto", "x64", "x86", "arm64", "arm", "neutral")]
        [string]$Architecture = "Auto",
        [ValidateSet("Retail", "RP", "WIS", "WIF")]
        [string]$Ring = "Retail",
        [bool]$IncludeEncrypted = $false
    )

    $targetArch = Get-TargetArchitecture -Selection $Architecture

    if (-not $ProductId -and $StoreUrl -match '/detail/(?<ProductId>[^/?#]+)') {
        $ProductId = $Matches.ProductId.Trim().ToUpper()
    }

    Write-Log -Level Info -Message "Resolving package links for ProductId=$ProductId Ring=$Ring Architecture=$targetArch"

    $headers = @{
        "User-Agent"      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
        "Accept"          = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        "Accept-Language" = "en-US,en;q=0.9"
        "Origin"          = "https://store.rg-adguard.net"
        "Referer"         = "https://store.rg-adguard.net/"
    }

    $response = $null
    $attemptErrors = New-Object System.Collections.Generic.List[string]

    $requestBodies = @()

    if ($ProductId) {
        # rg-adguard accepts ProductId directly. This is usually cleaner than generated Store URLs.
        $requestBodies += "type=ProductId&url=$ProductId&ring=$Ring&lang=en-US"
    }

    if ($StoreUrl) {
        # Keep URL fallback. Escape only for form body safety.
        $encodedStoreUrl = [uri]::EscapeDataString($StoreUrl)
        $requestBodies += "type=url&url=$encodedStoreUrl&ring=$Ring&lang=en-US"
    }

    foreach ($body in $requestBodies) {
        try {
            Write-Log -Level Info -Message "Trying rg-adguard resolver with body: $body"
            $response = Invoke-WebRequest -UseBasicParsing -Method POST -Uri "https://store.rg-adguard.net/api/GetFiles" -Body $body -ContentType "application/x-www-form-urlencoded" -Headers $headers
            if ($response -and $response.Content) { break }
        }
        catch {
            [void]$attemptErrors.Add($_.Exception.Message)
            Write-Log -Level Warning -Message "Resolver attempt failed: $($_.Exception.Message)"
            $response = $null
        }
    }

    if (-not $response -or -not $response.Content) {
        $details = ($attemptErrors -join " | ")
        throw "Could not resolve package links. rg-adguard returned an error or blocked the request. Details: $details"
    }

    # rg-adguard usually returns package URLs as anchor tags where the HREF is the CDN URL
    # and the visible anchor text is the real .appx/.msix file name. The CDN URL may not
    # end with .appx/.msix, so validate using the anchor text first.
    # Use an explicit Regex object and cast response content to string. This avoids the
    # Windows PowerShell/.NET overload issue that can throw: "Argument types do not match".
    $html = [string]$response.Content
    Write-Log -Level Info -Message "Resolver response received. HTML length: $($html.Length)"

    # Inline (?is) gives IgnoreCase + Singleline without passing a RegexOptions enum.
    # Use numbered capture groups instead of named groups. On some Windows PowerShell/.NET
    # combinations, $match.Groups["Name"] can throw: "Argument types do not match".
    $anchorPattern = '(?is)<a[^>]+href=["''](https?://[^"'']+)["''][^>]*>(.*?)</a>'
    $anchorMatches = [System.Text.RegularExpressions.Regex]::Matches([string]$html, [string]$anchorPattern)
    Write-Log -Level Info -Message "Regex parsed $($anchorMatches.Count) anchor candidate(s)."

    $linkObjects = @()
    $anchorIndex = 0
    $validIndex = 0

    foreach ($m in $anchorMatches) {
        $anchorIndex++
        try {
            $rawUrl = [string]$m.Groups[1].Value
            $rawText = [string]$m.Groups[2].Value

            if ([string]::IsNullOrWhiteSpace($rawUrl)) { continue }

            $url = [System.Net.WebUtility]::HtmlDecode($rawUrl)
            $cleanText = [string]($rawText -replace '<[^>]+>', '')
            $text = [System.Net.WebUtility]::HtmlDecode($cleanText)
            if ($null -eq $text) { $text = "" }
            $text = $text.Trim()

            $fileName = $text
            if ([string]::IsNullOrWhiteSpace($fileName) -or $fileName -notmatch '\.(appx|appxbundle|msix|msixbundle|eappx|eappxbundle|emsix|emsixbundle)$') {
                $fileName = [System.Uri]::UnescapeDataString([System.IO.Path]::GetFileName(([uri]$url).AbsolutePath))
            }

            if (Test-ValidPackageLink -Url ([string]$url) -FileName ([string]$fileName) -IncludeEncrypted ([bool]$IncludeEncrypted)) {
                $validIndex++
                $linkObjects += [pscustomobject]@{
                    Url      = [string]$url
                    FileName = [string]$fileName
                }
            }
        }
        catch {
            Write-Log -Level Warning -Message "Anchor parse skipped at index $anchorIndex`: $($_.Exception.Message)"
            continue
        }
    }
    Write-Log -Level Info -Message "Anchor filtering completed. Valid package links before de-dupe: $validIndex"

    # Keep this deliberately simple and avoid .NET collection Count/constructor overloads.
    $linkObjects = @($linkObjects)
    $linkCount = @($linkObjects).Length
    $anchorCount = @($anchorMatches).Count
    Write-Log -Level Info -Message "Resolver returned $anchorCount anchor(s); $linkCount valid package link(s) after filtering."

    if ($linkCount -eq 0) {
        throw "Resolver returned no valid AppX/MSIX links for ProductId=$ProductId. This usually means the parser found no package anchors, the selected Store result is not an AppX/MSIX app, or rg-adguard returned a blocked/empty response. Try another result or paste the exact apps.microsoft.com URL."
    }

    $packages = @()

    $packageLoopIndex = 0
    foreach ($link in $linkObjects) {
        $packageLoopIndex++
        $url = [string]$link.Url
        Write-Log -Level Info -Message "Processing package link $packageLoopIndex of $linkCount"
        if ($script:CancelRequested) {
            Write-Log -Level Warning -Message "Package resolution cancelled."
            break
        }

        try {
            # Do not require HEAD to succeed. Some Microsoft CDN links reject HEAD with 403 while GET still works.
            $fileName = [string]$link.FileName
            Write-Log -Level Info -Message "Package candidate: $fileName"
            if ([string]::IsNullOrWhiteSpace($fileName)) {
                $fileName = [System.Uri]::UnescapeDataString([System.IO.Path]::GetFileName(([uri]$url).AbsolutePath))
            }
            if ([string]::IsNullOrWhiteSpace($fileName)) {
                continue
            }

            if (-not (Test-PackageArchitectureMatch -FileName $fileName -Architecture $targetArch)) {
                Write-Log -Level Info -Message "Skipping architecture mismatch: $fileName"
                continue
            }

            # Keep Preview stable: do not issue HEAD requests here.
            # Some CDN responses expose Content-Length as provider-specific objects, which can trigger
            # "Argument types do not match" in older Windows PowerShell/WPF runs. The actual size is
            # filled in after download from the local file length.
            $sizeBytes = [int64]0

            $packageType = Get-PackageTypeFromName -FileName $fileName
            $packageGroup = if ($packageType -eq "Main") { "Main package" } else { "Dependencies" }

            $packages += [pscustomobject]@{
                Selected      = $true
                PackageGroup  = $packageGroup
                FileName      = $fileName
                PackageType   = $packageType
                PackageFamily = Get-PackageFamilyFromName -FileName $fileName
                Version       = Get-PackageVersionFromName -FileName $fileName
                Architecture  = Get-ArchitectureFromName -FileName $fileName
                SizeMB        = if ($sizeBytes -gt 0) { [math]::Round($sizeBytes / 1MB, 2) } else { 0 }
                SizeBytes     = $sizeBytes
                Url           = $url
                LocalPath     = ""
                SHA256        = ""
                Signature     = "NotDownloaded"
            }
        }
        catch {
            Write-Log -Level Warning -Message "Could not parse package link. Skipping. $($_.Exception.Message)"
        }
    }

    Write-Log -Level Info -Message "Built $(@($packages).Count) package candidate(s) before newest-version filtering."
    $ordered = Select-NewestStorePackages -Packages @($packages)

    Write-Log -Level Success -Message "Resolved $(@($ordered).Count) newest package file(s). Main package and dependencies are listed."
    return @($ordered)
}

function Get-SafeFolderName {
    param([string]$Name)

    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $safe = $Name
    foreach ($char in $invalid) {
        $safe = $safe.Replace($char, "_")
    }
    return $safe.Trim()
}


function Remove-StoreLiftBitsTempFiles {
    param([Parameter(Mandatory)][string]$FolderPath)

    try {
        Get-ChildItem -Path $FolderPath -File -Filter "BIT*.tmp" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt (Get-Date).AddMinutes(-5) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    catch { }
}

function Invoke-StoreLiftFileDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$FileName,
        [int]$NoProgressTimeoutSeconds = 75,
        [int]$MaxDownloadSeconds = 900
    )

    $downloadFolder = Split-Path -Parent $Destination
    Remove-StoreLiftBitsTempFiles -FolderPath $downloadFolder

    if (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue) {
        $bitsJob = $null
        try {
            Write-Log -Level Info -Message "Starting BITS download: $FileName"
            $bitsJob = Start-BitsTransfer -Source $Source -Destination $Destination -Description "StoreLift download: $FileName" -Asynchronous -ErrorAction Stop

            $startTime = Get-Date
            $lastProgressTime = Get-Date
            $lastLogTime = (Get-Date).AddSeconds(-10)
            $lastBytes = [int64]-1

            while ($true) {
                if ($script:CancelRequested) {
                    try { Remove-BitsTransfer -BitsJob $bitsJob -Confirm:$false -ErrorAction SilentlyContinue } catch { }
                    throw "Download cancelled: $FileName"
                }

                $bitsJob = Get-BitsTransfer -Id $bitsJob.Id -ErrorAction Stop

                $bytesTransferred = [int64]$bitsJob.BytesTransferred
                $bytesTotal = [int64]$bitsJob.BytesTotal

                if ($bytesTransferred -ne $lastBytes) {
                    $lastBytes = $bytesTransferred
                    $lastProgressTime = Get-Date
                }

                $now = Get-Date
                if (($now - $lastLogTime).TotalSeconds -ge 5) {
                    if ($bytesTotal -gt 0) {
                        $percent = [math]::Round(($bytesTransferred / $bytesTotal) * 100, 1)
                        $mbDone = [math]::Round($bytesTransferred / 1MB, 2)
                        $mbTotal = [math]::Round($bytesTotal / 1MB, 2)
                        Write-Log -Level Progress -Message "BITS progress for $FileName`: $percent% ($mbDone MB / $mbTotal MB)"
                    }
                    else {
                        $mbDone = [math]::Round($bytesTransferred / 1MB, 2)
                        Write-Log -Level Progress -Message "BITS progress for $FileName`: $mbDone MB downloaded"
                    }
                    $lastLogTime = $now
                    try { [System.Windows.Forms.Application]::DoEvents() } catch { }
                }

                if ($bitsJob.JobState -eq "Transferred") {
                    Complete-BitsTransfer -BitsJob $bitsJob -ErrorAction Stop
                    Write-Log -Level Success -Message "BITS completed: $FileName"
                    return
                }

                if ($bitsJob.JobState -eq "Error") {
                    $errorText = $bitsJob.ErrorDescription
                    try { Remove-BitsTransfer -BitsJob $bitsJob -Confirm:$false -ErrorAction SilentlyContinue } catch { }
                    throw "BITS failed for $FileName. $errorText"
                }

                if (($now - $lastProgressTime).TotalSeconds -ge $NoProgressTimeoutSeconds) {
                    try { Remove-BitsTransfer -BitsJob $bitsJob -Confirm:$false -ErrorAction SilentlyContinue } catch { }
                    throw "BITS stalled for $FileName with no progress for $NoProgressTimeoutSeconds seconds."
                }

                if (($now - $startTime).TotalSeconds -ge $MaxDownloadSeconds) {
                    try { Remove-BitsTransfer -BitsJob $bitsJob -Confirm:$false -ErrorAction SilentlyContinue } catch { }
                    throw "BITS timed out for $FileName after $MaxDownloadSeconds seconds."
                }

                Start-Sleep -Seconds 1
                try { [System.Windows.Forms.Application]::DoEvents() } catch { }
            }
        }
        catch {
            Write-Log -Level Warning -Message "$($_.Exception.Message) Falling back to Invoke-WebRequest."
            try {
                if ($bitsJob) {
                    Remove-BitsTransfer -BitsJob $bitsJob -Confirm:$false -ErrorAction SilentlyContinue
                }
            }
            catch { }
            Remove-StoreLiftBitsTempFiles -FolderPath $downloadFolder
        }
    }

    Write-Log -Level Info -Message "Starting web download fallback: $FileName"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $Source -OutFile $Destination -TimeoutSec $MaxDownloadSeconds -Headers @{ "User-Agent" = "Mozilla/5.0" } -ErrorAction Stop
        Write-Log -Level Success -Message "Web download completed: $FileName"
    }
    catch {
        if (Test-Path $Destination) {
            try { Remove-Item -Path $Destination -Force -ErrorAction SilentlyContinue } catch { }
        }
        throw "Fallback web download failed for $FileName`: $($_.Exception.Message)"
    }
}

function Download-StorePackages {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][array]$Packages,
        [Parameter(Mandatory)][string]$DestinationPath
    )

    if (-not (Test-Path $DestinationPath)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }

    $downloaded = @()
    $selectedPackages = @($Packages | Where-Object { $_.Selected -eq $true })

    if ($selectedPackages.Count -eq 0) {
        throw "No packages selected for download."
    }

    $total = $selectedPackages.Count
    $index = 0

    foreach ($pkg in $selectedPackages) {
        if ($script:CancelRequested) {
            Write-Log -Level Warning -Message "Download cancelled."
            break
        }

        $index++
        $fileName = [string]$pkg.FileName
        $url = [string]$pkg.Url

        if ([string]::IsNullOrWhiteSpace($fileName)) {
            Write-Log -Level Warning -Message "Skipping package with empty file name."
            continue
        }

        if ([string]::IsNullOrWhiteSpace($url)) {
            Write-Log -Level Warning -Message "Skipping $fileName because URL is empty."
            continue
        }

        $targetPath = Join-Path -Path $DestinationPath -ChildPath $fileName
        Write-Log -Level Progress -Message "Downloading $index of $total`: $fileName"

        try {
            if (-not (Test-Path $targetPath)) {
                # BITS can leave a BIT*.tmp file while it is actively downloading.
                # Use async BITS so StoreLift can detect a stalled transfer and fall back cleanly.
                Invoke-StoreLiftFileDownload -Source $url -Destination $targetPath -FileName $fileName
            }
            else {
                Write-Log -Level Info -Message "Already exists, verifying: $fileName"
            }

            $hash = Get-FileHash -Path $targetPath -Algorithm SHA256
            $sig = Get-AuthenticodeSignature -FilePath $targetPath
            $item = Get-Item $targetPath

            $pkg.LocalPath = [string]$targetPath
            $pkg.SHA256 = [string]$hash.Hash
            $pkg.Signature = [string]$sig.Status
            $pkg.SizeMB = [math]::Round($item.Length / 1MB, 2)

            $downloaded += $pkg
            Write-Log -Level Success -Message "Downloaded/verified: $fileName"
        }
        catch {
            Write-Log -Level Error -Message "Failed downloading $fileName`: $($_.Exception.Message)"
            throw
        }
    }

    Write-Log -Level Success -Message "Download step completed. Downloaded/verified $($downloaded.Count) file(s)."
    return @($downloaded)
}


function Get-NewestLocalPackageFiles {
    param([Parameter(Mandatory)][array]$Files)

    $items = foreach ($file in $Files) {
        [pscustomobject]@{
            File          = $file
            PackageType   = Get-PackageTypeFromName -FileName $file.Name
            PackageFamily = Get-PackageFamilyFromName -FileName $file.Name
            Architecture  = Get-ArchitectureFromName -FileName $file.Name
            VersionKey    = Get-PackageVersionSortKey -FileName $file.Name
            Length        = [int64]$file.Length
        }
    }

    return @(
        $items |
            Group-Object PackageType, PackageFamily, Architecture |
            ForEach-Object {
                $_.Group |
                    Sort-Object @{ Expression = { $_.VersionKey }; Descending = $true },
                                @{ Expression = { $_.Length }; Descending = $true } |
                    Select-Object -First 1
            } |
            ForEach-Object { $_.File }
    )
}

function Install-CurrentUserPackages {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Install path does not exist: $Path"
    }

    Write-Log -Level Info -Message "Installing for current user from folder: $Path"

    $files = Get-ChildItem -Path $Path -File -Recurse |
        Where-Object { $script:PackageExtensions -contains $_.Extension.ToLower() }

    if (-not $files) {
        throw "No AppX/MSIX packages found in: $Path"
    }

    $newestFiles = @(Get-NewestLocalPackageFiles -Files @($files))

    $dependencyNamePattern = 'VCLibs|UI\.Xaml|NET\.Native|WindowsAppRuntime|Microsoft\.NET'

    $dependencies = @($newestFiles | Where-Object {
        $_.Name -match $dependencyNamePattern
    })

    $mainPackages = @($newestFiles | Where-Object {
        $_.Name -notmatch $dependencyNamePattern
    })

    if ($mainPackages.Count -eq 0) {
        throw "No main AppX/MSIX package found in: $Path"
    }

    # Pick newest/largest main package only.
    # This avoids accidentally trying to install multiple candidate main packages.
    $mainPackage = $mainPackages |
        Sort-Object `
            @{ Expression = { Get-PackageVersionSortKey -FileName $_.Name }; Descending = $true },
            @{ Expression = { $_.Length }; Descending = $true } |
        Select-Object -First 1

    Write-Log -Level Info -Message "Main package: $($mainPackage.FullName)"
    Write-Log -Level Info -Message "Dependency count: $($dependencies.Count)"

    foreach ($dep in $dependencies) {
        Write-Log -Level Info -Message "Dependency: $($dep.Name)"
    }

    try {
        if ($dependencies.Count -gt 0) {
            Add-AppxPackage `
                -Path $mainPackage.FullName `
                -DependencyPath @($dependencies.FullName) `
                -ErrorAction Stop
        }
        else {
            Add-AppxPackage `
                -Path $mainPackage.FullName `
                -ErrorAction Stop
        }

        Write-Log -Level Success -Message "Installed successfully for current user: $($mainPackage.Name)"
        Write-Log -Level Success -Message "Install step completed."
    }
    catch {
        if ($_.Exception.Message -match '0x80073D06') {
            Write-Log -Level Info -Message "Same or higher version may already be installed for current user: $($mainPackage.Name)"
            return
        }

        Write-Log -Level Error -Message "Install failed: $($_.Exception.Message)"
        throw
    }
}

# -----------------------------
# WPF XAML
# -----------------------------

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="StoreLift" Height="840" Width="1180" MinHeight="720" MinWidth="1050" WindowStartupLocation="CenterScreen" ResizeMode="CanResize" Background="#0B1220" Foreground="#E5E7EB">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#1D4ED8"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="3"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#111827"/>
            <Setter Property="Foreground" Value="#F9FAFB"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="Padding" Value="5"/>
            <Setter Property="Margin" Value="3"/>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="#111827"/>
            <Setter Property="Foreground" Value="#E5E7EB"/>
            <Setter Property="RowBackground" Value="#111827"/>
            <Setter Property="AlternatingRowBackground" Value="#172033"/>
            <Setter Property="GridLinesVisibility" Value="Horizontal"/>
            <Setter Property="HorizontalGridLinesBrush" Value="#334155"/>
            <Setter Property="VerticalGridLinesBrush" Value="#334155"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
            <Setter Property="AutoGenerateColumns" Value="True"/>
            <Setter Property="CanUserAddRows" Value="False"/>
            <Setter Property="IsReadOnly" Value="False"/>
            <Setter Property="Margin" Value="3"/>
            <Setter Property="ColumnHeaderHeight" Value="24"/>
            <Setter Property="RowHeight" Value="22"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="#1E293B"/>
            <Setter Property="Foreground" Value="#BFDBFE"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="Padding" Value="6,4"/>
        </Style>
<Style TargetType="DataGridRow">
    <Setter Property="Background" Value="#111827"/>
    <Setter Property="Foreground" Value="#E5E7EB"/>
    <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
            <Setter Property="Background" Value="#1D4ED8"/>
            <Setter Property="Foreground" Value="White"/>
        </Trigger>
    </Style.Triggers>
</Style>
        <Style TargetType="DataGridCell">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#E5E7EB"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="Padding" Value="4,2"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#2563EB"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="GroupBox">
            <Setter Property="Foreground" Value="#93C5FD"/>
            <Setter Property="BorderBrush" Value="#1E3A8A"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Padding" Value="5"/>
        </Style>
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="#CBD5E1"/>
        </Style>
    </Window.Resources>

    <Grid Margin="8">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <!-- Fixed heights keep the grids visible even when the window is crowded. -->
            <RowDefinition Height="245"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="210"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#0F1B33" CornerRadius="8" Padding="8,6" Margin="0,0,0,3" Height="58">
            <StackPanel>
                <TextBlock Text="StoreLift" FontSize="20" FontWeight="Bold" Foreground="#BFDBFE"/>
                <TextBlock Text="Search, resolve, download, verify, and install AppX/MSIX packages locally." FontSize="10" Foreground="#94A3B8" Margin="0,0,0,0"/>
            </StackPanel>
        </Border>

        <GroupBox Grid.Row="1" Header="Search / Manual">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <TextBox x:Name="SearchTextBox" Grid.Row="0" Grid.Column="0" Height="28" Text="paint" ToolTip="Search app name using winget msstore source."/>
                <Button x:Name="SearchButton" Grid.Row="0" Grid.Column="1" Content="Search Store" Width="125" Height="28"/>
                <Button x:Name="StopButton" Grid.Row="0" Grid.Column="2" Content="Stop" Width="80" Height="28" IsEnabled="False" Background="#991B1B"/>

                <TextBox x:Name="ManualTextBox" Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="2" Height="28" Text="Optional manual Store URL or ProductId" Foreground="#94A3B8" ToolTip="Example: https://apps.microsoft.com/detail/9PCFS5B6T72H or 9PCFS5B6T72H"/>
                <Button x:Name="UseManualButton" Grid.Row="1" Grid.Column="2" Content="Use Manual" Width="105" Height="28"/>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="2" Header="Search Results" MinHeight="235">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <DataGrid x:Name="ResultsGrid" Grid.Row="0" SelectionMode="Single" SelectionUnit="FullRow" AutoGenerateColumns="False" MinHeight="185" VerticalAlignment="Stretch" ScrollViewer.VerticalScrollBarVisibility="Auto">
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="2*"/>
                        <DataGridTextColumn Header="ProductId" Binding="{Binding ProductId}" Width="130"/>
                        <DataGridTextColumn Header="Version" Binding="{Binding Version}" Width="90"/>
                        <DataGridTextColumn Header="Source" Binding="{Binding Source}" Width="120"/>
                        <DataGridTextColumn Header="StoreUrl" Binding="{Binding StoreUrl}" Width="3*"/>
                    </DataGrid.Columns>
                </DataGrid>
                <Button x:Name="ResolveButton" Grid.Row="1" Content="Preview Packages" Width="160" Height="30" HorizontalAlignment="Right" Margin="3,2,3,0"/>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="3" Header="Preview Options">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Label Grid.Column="0" Content="Architecture:" VerticalAlignment="Center"/>
                <ComboBox x:Name="ArchComboBox" Grid.Column="1" Width="100" SelectedIndex="0">
                    <ComboBoxItem Content="Auto"/>
                    <ComboBoxItem Content="x64"/>
                    <ComboBoxItem Content="x86"/>
                    <ComboBoxItem Content="arm64"/>
                    <ComboBoxItem Content="arm"/>
                    <ComboBoxItem Content="neutral"/>
                </ComboBox>

                <Label Grid.Column="2" Content="Ring:" VerticalAlignment="Center"/>
                <ComboBox x:Name="RingComboBox" Grid.Column="3" Width="105" HorizontalAlignment="Left" SelectedIndex="0">
                    <ComboBoxItem Content="Retail"/>
                    <ComboBoxItem Content="RP"/>
                    <ComboBoxItem Content="WIS"/>
                    <ComboBoxItem Content="WIF"/>
                </ComboBox>

                <CheckBox x:Name="IncludeEncryptedCheckBox" Grid.Column="4" Content="Include encrypted" Foreground="#CBD5E1" VerticalAlignment="Center" Margin="10,0"/>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="4" Header="Package Preview / Downloaded Packages" MinHeight="210">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <DataGrid x:Name="PackagesGrid" Grid.Row="0" SelectionMode="Extended" SelectionUnit="FullRow" AutoGenerateColumns="False" Height="145" MinHeight="105" VerticalAlignment="Stretch">
                    <DataGrid.Columns>
                        <DataGridCheckBoxColumn Header="Selected" Binding="{Binding Selected}" Width="75"/>
                        <DataGridTextColumn Header="Group" Binding="{Binding PackageGroup}" Width="120"/>
                        <DataGridTextColumn Header="Type" Binding="{Binding PackageType}" Width="95"/>
                        <DataGridTextColumn Header="Architecture" Binding="{Binding Architecture}" Width="95"/>
                        <DataGridTextColumn Header="Size MB" Binding="{Binding SizeMB}" Width="80"/>
                        <DataGridTextColumn Header="Signature" Binding="{Binding Signature}" Width="120"/>
                        <DataGridTextColumn Header="FileName" Binding="{Binding FileName}" Width="3*"/>
                        <DataGridTextColumn Header="SHA256" Binding="{Binding SHA256}" Width="2*"/>
                    </DataGrid.Columns>
                </DataGrid>
                <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right" Margin="3,5,3,2">
                    <Button x:Name="DownloadButton" Content="Download App + Dependencies" Width="220"/>
                    <Button x:Name="InstallButton" Content="Install Current User" Width="180" Margin="8,4,4,4" Visibility="Visible" IsEnabled="False" Background="#16A34A" ToolTip="Enabled after a successful download. Installs the downloaded main package with dependency packages for the current user."/>
                </StackPanel>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="5" Header="Download Destination">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="PathTextBox" Grid.Column="0" Height="36"/>
                <Button x:Name="BrowseButton" Grid.Column="1" Content="Browse" Width="95"/>
                <Button x:Name="OpenFolderButton" Grid.Column="2" Content="Open Folder" Width="115"/>
            </Grid>
        </GroupBox>

        <GroupBox Grid.Row="6" Header="Logs">
            <DataGrid x:Name="LogListBox" AutoGenerateColumns="True" IsReadOnly="True"/>
        </GroupBox>

        <Border Grid.Row="7" Background="#0F1B33" CornerRadius="8" Padding="10" Margin="6,8,6,0">
            <TextBlock x:Name="StatusTextBlock" Text="Ready." Foreground="#BFDBFE"/>
        </Border>
    </Grid>
</Window>
"@

# -----------------------------
# Load UI
# -----------------------------

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$script:SearchTextBox = $window.FindName("SearchTextBox")
$script:ManualTextBox = $window.FindName("ManualTextBox")
$script:SearchButton = $window.FindName("SearchButton")
$script:ResolveButton = $window.FindName("ResolveButton")
$script:UseManualButton = $window.FindName("UseManualButton")
$script:ResultsGrid = $window.FindName("ResultsGrid")
$script:PackagesGrid = $window.FindName("PackagesGrid")

# Search results are selection-only. This prevents slow/awkward cell editing behavior.
$script:ResultsGrid.IsReadOnly = $true
$script:ResultsGrid.CanUserAddRows = $false
$script:ResultsGrid.CanUserDeleteRows = $false
$script:DownloadButton = $window.FindName("DownloadButton")
$script:InstallButton = $window.FindName("InstallButton")
$script:InstallButton.Visibility = "Visible"
$script:InstallButton.IsEnabled = $false
$script:StopButton = $window.FindName("StopButton")
$script:ArchComboBox = $window.FindName("ArchComboBox")
$script:RingComboBox = $window.FindName("RingComboBox")
$script:IncludeEncryptedCheckBox = $window.FindName("IncludeEncryptedCheckBox")
$script:PathTextBox = $window.FindName("PathTextBox")
$script:BrowseButton = $window.FindName("BrowseButton")
$script:OpenFolderButton = $window.FindName("OpenFolderButton")
$script:LogListBox = $window.FindName("LogListBox")
$script:StatusTextBlock = $window.FindName("StatusTextBlock")

$defaultPath = Join-Path $env:USERPROFILE "Documents\StoreAppxPackages"
$script:PathTextBox.Text = $defaultPath

Write-Log -Level Info -Message "Ready. Search for an app name or paste a Store URL/ProductId."

# -----------------------------
# UI Events
# -----------------------------

$script:ManualTextBox.Add_GotFocus({
    if ($script:ManualTextBox.Text -eq "Optional manual Store URL or ProductId") {
        $script:ManualTextBox.Text = ""
        $script:ManualTextBox.Foreground = "#F9FAFB"
    }
})

$script:ManualTextBox.Add_LostFocus({
    if ([string]::IsNullOrWhiteSpace($script:ManualTextBox.Text)) {
        $script:ManualTextBox.Text = "Optional manual Store URL or ProductId"
        $script:ManualTextBox.Foreground = "#94A3B8"
    }
})

$script:SearchButton.Add_Click({
    try {
        $query = $script:SearchTextBox.Text
        Set-UiBusy -Busy $true
        Add-Log -Level Info -Message "Searching Store for: $query"

        $results = Search-MicrosoftStoreApp -Query $query

        if (-not $results -or @($results).Count -eq 0) {
            Add-Log -Level Warning -Message "No Store results found. Try another query or manual ProductId/URL."
            $script:ResultsGrid.ItemsSource = $null
            $script:CurrentPackages = @()
            $script:PackagesGrid.ItemsSource = $null
            return
        }

        $script:ResultsGrid.ItemsSource = $null
        $script:ResultsGrid.ItemsSource = @($results)
        $script:ResultsGrid.Items.Refresh()
        $script:ResultsGrid.SelectedIndex = 0
        try { $script:ResultsGrid.ScrollIntoView($script:ResultsGrid.SelectedItem) } catch { }
        Add-Log -Level Info -Message "Bound $(@($results).Count) result row(s) to Search Results grid. First result: $(@($results)[0].Name) / $(@($results)[0].ProductId)"
        $script:CurrentPackages = @()
        $script:PackagesGrid.ItemsSource = $null
        Add-Log -Level Success -Message "Found $(@($results).Count) Store result(s). Select a row and click Preview Packages."
    }
    catch {
        Add-Log -Level Error -Message $_.Exception.Message
        Show-StoreLiftMessage -Message $_.Exception.Message -Title "Search Error" -Icon Error | Out-Null
    }
    finally {
        Set-UiBusy -Busy $false
    }
})

$script:UseManualButton.Add_Click({
    try {
        $manualText = $script:ManualTextBox.Text
        if ($manualText -eq "Optional manual Store URL or ProductId") {
            throw "Paste a Microsoft Store URL or ProductId first."
        }

        $manualApp = Resolve-ManualStoreInput -InputText $manualText
        $script:ResultsGrid.ItemsSource = @($manualApp)
        $script:ResultsGrid.SelectedIndex = 0
        $script:CurrentApp = $manualApp
        Hide-InlineInstallButton
        Write-Log -Level Success -Message "Manual input resolved to ProductId: $($manualApp.ProductId)"
    }
    catch {
        Write-Log -Level Error -Message $_.Exception.Message
        Show-StoreLiftMessage -Message $_.Exception.Message -Title "Manual Input Error" -Icon Error | Out-Null
    }
})

$script:ResolveButton.Add_Click({
    try {
        $selected = $script:ResultsGrid.SelectedItem
        if (-not $selected) {
            throw "Select a search result first, or use manual URL/ProductId."
        }

        $script:CancelRequested = $false
        Set-UiBusy -Busy $true
        $script:CurrentApp = $selected

        $arch = ([System.Windows.Controls.ComboBoxItem]$script:ArchComboBox.SelectedItem).Content.ToString()
        $ring = ([System.Windows.Controls.ComboBoxItem]$script:RingComboBox.SelectedItem).Content.ToString()
        $includeEncrypted = [bool]$script:IncludeEncryptedCheckBox.IsChecked

        $packages = Get-StorePackageLinks -StoreUrl $selected.StoreUrl -ProductId $selected.ProductId -Architecture $arch -Ring $ring -IncludeEncrypted $includeEncrypted
        $script:CurrentPackages = @($packages)
        $script:PackagesGrid.ItemsSource = $null
        $script:PackagesGrid.ItemsSource = $script:CurrentPackages
        $script:PackagesGrid.Items.Refresh()
    }
    catch {
        $detail = $_.Exception.Message
        if ($_.InvocationInfo -and $_.InvocationInfo.ScriptLineNumber) {
            $detail = "$detail (line $($_.InvocationInfo.ScriptLineNumber))"
        }
        Write-Log -Level Error -Message $detail
        Show-StoreLiftMessage -Message $detail -Title "Preview Error" -Icon Error | Out-Null
    }
    finally {
        Set-UiBusy -Busy $false
    }
})

$script:DownloadButton.Add_Click({
    try {
        if (-not $script:CurrentApp) {
            throw "Select and preview an app first."
        }
        if (-not $script:CurrentPackages -or $script:CurrentPackages.Count -eq 0) {
            throw "Preview packages before downloading."
        }

        $script:CancelRequested = $false
        Set-UiBusy -Busy $true

        $appFolder = Get-SafeFolderName -Name ("{0}_{1}" -f $script:CurrentApp.Name, $script:CurrentApp.ProductId)
        $destination = Join-Path $script:PathTextBox.Text $appFolder

        $downloaded = @(Download-StorePackages -Packages $script:CurrentPackages -DestinationPath $destination)
        Write-Log -Level Info -Message "Download function returned $($downloaded.Count) verified file object(s). Updating UI paths."

        # Keep this simple. The package objects were already updated in-place by Download-StorePackages.
        # Rebinding the WPF DataGrid after the download can throw 'Argument types do not match' on some Windows PowerShell/WPF builds.
        $script:DownloadedFiles = $downloaded
        $script:PathTextBox.Text = [string]$destination
        Show-InlineInstallButton -Path $destination

        try {
            $script:PackagesGrid.Items.Refresh()
        }
        catch {
            Write-Log -Level Warning -Message "Package grid refresh skipped: $($_.Exception.Message)"
        }

        Write-Log -Level Success -Message "Download UI update completed. Files are saved in: $destination"
    }
    catch {
        $detail = $_.Exception.Message
        if ($_.InvocationInfo -and $_.InvocationInfo.ScriptLineNumber) {
            $detail = "$detail (line $($_.InvocationInfo.ScriptLineNumber))"
        }
        Write-Log -Level Error -Message $detail
        Show-StoreLiftMessage -Message $detail -Title "Download Error" -Icon Error | Out-Null
    }
    finally {
        Set-UiBusy -Busy $false
    }
})

$script:InstallButton.Add_Click({
    try {
        $path = if (-not [string]::IsNullOrWhiteSpace($script:LastDownloadPath)) {
            $script:LastDownloadPath
        }
        else {
            $script:PathTextBox.Text
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            throw "No download folder is selected."
        }

        if (-not (Test-Path $path)) {
            throw "Folder does not exist: $path"
        }

        $confirm = Show-StoreLiftMessage `
            -Message "Install AppX/MSIX package for the current user from:`n$path`n`nThis uses Add-AppxPackage and usually does not require Administrator." `
            -Title "Confirm Current User Install" `
            -Buttons YesNo `
            -Icon Warning

        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
            Write-Log -Level Info -Message "Current-user install cancelled by user."
            return
        }

        $script:CancelRequested = $false
        Set-UiBusy -Busy $true

        Install-CurrentUserPackages -Path $path

        Write-Log -Level Success -Message "Current-user install completed."
    }
    catch {
        Write-Log -Level Error -Message $_.Exception.Message
        Show-StoreLiftMessage -Message $_.Exception.Message -Title "Install Error" -Icon Error | Out-Null
    }
    finally {
        Set-UiBusy -Busy $false
    }
})

$script:StopButton.Add_Click({
    $script:CancelRequested = $true
    Write-Log -Level Warning -Message "Stop requested. Current web/install operation may finish before stopping."
})

$script:BrowseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select download folder"
    $dialog.SelectedPath = $script:PathTextBox.Text

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:PathTextBox.Text = $dialog.SelectedPath
    }
})


$script:OpenFolderButton.Add_Click({
    try {
        $path = $script:PathTextBox.Text
        if ([string]::IsNullOrWhiteSpace($path)) {
            throw "No folder path is set."
        }

        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }

        Start-Process explorer.exe -ArgumentList "`"$path`""
    }
    catch {
        Write-Log -Level Error -Message $_.Exception.Message
        Show-StoreLiftMessage -Message $_.Exception.Message -Title "Open Folder Error" -Icon Error | Out-Null
    }
})



# -----------------------------
# Show Window
# -----------------------------

[void]$window.ShowDialog()
