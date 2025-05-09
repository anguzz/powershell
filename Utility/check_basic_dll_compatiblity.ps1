[string]$NewDllPath = Join-Path $PSScriptRoot "files\example.dll"   #new dll you want to replace the old one with, run from the same directory as the script
[string]$OldDllPath =   "" 


Function Get-PEArchitecture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    $ErrorOccurred = $false
    $FileStream = $null
    $BinaryReader = $null

    try {
        $FileStream = New-Object System.IO.FileStream($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $BinaryReader = New-Object System.IO.BinaryReader($FileStream)

        if ($FileStream.Length -lt 0x3C + 4) {
            return "File too small (DOS Header)"
        }
        $FileStream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peHeaderOffset = $BinaryReader.ReadUInt32()

        if ($FileStream.Length -lt ($peHeaderOffset + 4 + 2)) {
            return "File too small (PE Header/COFF)"
        }
        $FileStream.Seek($peHeaderOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $peSignature = $BinaryReader.ReadUInt32() # Reads 4 bytes "PE\0\0"
        if ($peSignature -ne 0x00004550) { # "PE\0\0" (little-endian)
            return "Not a PE file (Invalid Signature)"
        }

        $machineType = $BinaryReader.ReadUInt16()

        switch ($machineType) {
            0x0     { return "Unknown" }              # IMAGE_FILE_MACHINE_UNKNOWN
            0x014c  { return "x86 (32-bit)" }         # IMAGE_FILE_MACHINE_I386
            0x8664  { return "x64 (64-bit)" }         # IMAGE_FILE_MACHINE_AMD64
            0x0200  { return "IA64 (Itanium)" }      # IMAGE_FILE_MACHINE_IA64 (less common now)
            0xaa64  { return "ARM64" }                # IMAGE_FILE_MACHINE_ARM64
            0x01c4  { return "ARM (Thumb-2 LE)" }    # IMAGE_FILE_MACHINE_ARMNT
            # Add other common ARM variants if needed
            # 0x01c0  { return "ARM" }                # IMAGE_FILE_MACHINE_ARM
            default { return "Other ($('0x{0:X4}' -f $machineType))" }
        }
    } catch {
        $ErrorOccurred = $true # Variable not used, but kept for consistency if you extend
        Write-Warning "Error reading PE architecture for '$FilePath': $($_.Exception.Message)"
        return "Error Reading Architecture"
    } finally {
        if ($BinaryReader -ne $null) { $BinaryReader.Close() } # This also closes the FileStream
        elseif ($FileStream -ne $null) { $FileStream.Close() } # Ensure FileStream is closed if BinaryReader wasn't created
    }
}

# --- Main Logic ---
$results = [ordered]@{
    Timestamp           = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    OldDllPath          = $OldDllPath
    NewDllPath          = $NewDllPath
    OverallStatus       = "PASS" # Default to PASS, change on warnings or failures
    Checks              = @()
}

Function Add-CheckResult {
    param(
        [string]$CheckName,
        [string]$Status, # "PASS", "WARN", "FAIL"
        [string]$Message,
        [hashtable]$Details = @{}
    )
    $results.Checks += [PSCustomObject]@{
        CheckName = $CheckName
        Status    = $Status
        Message   = $Message
        Details   = $Details
    }
    if ($Status -eq "FAIL") {
        $results.OverallStatus = "CRITICAL_FAIL"
    } elseif ($Status -eq "WARN" -and $results.OverallStatus -ne "CRITICAL_FAIL") {
        $results.OverallStatus = "WARNING"
    }
}

# 1. File Existence
Write-Verbose "Checking file existence..."
$oldDllExists = Test-Path $OldDllPath -PathType Leaf
$newDllExists = Test-Path $NewDllPath -PathType Leaf

if (-not $oldDllExists) {
    Add-CheckResult -CheckName "Old DLL Existence" -Status "FAIL" -Message "Old DLL not found at '$OldDllPath'."
} else {
    Add-CheckResult -CheckName "Old DLL Existence" -Status "PASS" -Message "Old DLL found."
}
if (-not $newDllExists) {
    Add-CheckResult -CheckName "New DLL Existence" -Status "FAIL" -Message "New DLL not found at '$NewDllPath'."
} else {
    Add-CheckResult -CheckName "New DLL Existence" -Status "PASS" -Message "New DLL found."
}

if (-not ($oldDllExists -and $newDllExists)) {
    $earlyExitStatusColor = "Red" 
    Write-Host "Overall Status: " -NoNewline
    Write-Host $results.OverallStatus -ForegroundColor $earlyExitStatusColor
    Write-Output ($results | ConvertTo-Json -Depth 4) 
    Write-Warning "Cannot proceed with further checks as one or both DLLs were not found."
    exit 1
}

try {
    $oldDllInfo = Get-Item $OldDllPath
    $newDllInfo = Get-Item $NewDllPath
    $oldVersionInfo = $oldDllInfo.VersionInfo
    $newVersionInfo = $newDllInfo.VersionInfo
} catch {
    Add-CheckResult -CheckName "File Info Retrieval" -Status "FAIL" -Message "Error getting file info for one or both DLLs: $($_.Exception.Message)"
    $earlyExitStatusColor = "Red"
    Write-Host "Overall Status: " -NoNewline
    Write-Host $results.OverallStatus -ForegroundColor $earlyExitStatusColor
    Write-Output ($results | ConvertTo-Json -Depth 4)
    exit 1
}

Write-Verbose "Checking PE Architecture..."
$oldArch = Get-PEArchitecture -FilePath $OldDllPath
$newArch = Get-PEArchitecture -FilePath $NewDllPath
$archDetails = @{ OldArchitecture = $oldArch; NewArchitecture = $newArch }

if ($oldArch -eq "Error Reading Architecture" -or $newArch -eq "Error Reading Architecture" -or $oldArch -like "File too small*" -or $newArch -like "File too small*" -or $oldArch -like "Not a PE file*" -or $newArch -like "Not a PE file*") {
    Add-CheckResult -CheckName "PE Architecture" -Status "FAIL" -Message "Could not determine architecture for one or both DLLs." -Details $archDetails
} elseif ($oldArch -ne $newArch) {
    Add-CheckResult -CheckName "PE Architecture" -Status "FAIL" -Message "Architecture mismatch: Old is '$oldArch', New is '$newArch'." -Details $archDetails
} else {
    Add-CheckResult -CheckName "PE Architecture" -Status "PASS" -Message "Architectures match: '$oldArch'." -Details $archDetails
}

Write-Verbose "Checking Product Version (Major)..."
$oldProdMajor = if ($oldVersionInfo.ProductVersion) {($oldVersionInfo.ProductVersion -split '\.')[0]} else {$null}
$newProdMajor = if ($newVersionInfo.ProductVersion) {($newVersionInfo.ProductVersion -split '\.')[0]} else {$null}
$prodVerDetails = @{ OldProductVersion = $oldVersionInfo.ProductVersion; NewProductVersion = $newVersionInfo.ProductVersion }

if (-not $oldProdMajor -or -not $newProdMajor) {
     Add-CheckResult -CheckName "Product Version (Major)" -Status "WARN" -Message "Could not determine Product Major Version for one or both DLLs (ProductVersion string might be empty or malformed)." -Details $prodVerDetails
} elseif ($oldProdMajor -ne $newProdMajor) {
    Add-CheckResult -CheckName "Product Version (Major)" -Status "WARN" -Message "Product Major Versions differ: Old='($oldVersionInfo.ProductVersion)', New='($newVersionInfo.ProductVersion)'. Potential breaking changes." -Details $prodVerDetails
} else {
    Add-CheckResult -CheckName "Product Version (Major)" -Status "PASS" -Message "Product Major Versions match: '$oldProdMajor'." -Details $prodVerDetails
}

Write-Verbose "Checking File Version (Major)..."
$oldFileMajor = if ($oldVersionInfo.FileVersion) {($oldVersionInfo.FileVersion -split '\.')[0]} else {$null}
$newFileMajor = if ($newVersionInfo.FileVersion) {($newVersionInfo.FileVersion -split '\.')[0]} else {$null}
$fileVerDetails = @{ OldFileVersion = $oldVersionInfo.FileVersion; NewFileVersion = $newVersionInfo.FileVersion }

if (-not $oldFileMajor -or -not $newFileMajor) {
     Add-CheckResult -CheckName "File Version (Major)" -Status "WARN" -Message "Could not determine File Major Version for one or both DLLs (FileVersion string might be empty or malformed)." -Details $fileVerDetails
} elseif ($oldFileMajor -ne $newFileMajor) {
    Add-CheckResult -CheckName "File Version (Major)" -Status "WARN" -Message "File Major Versions differ: Old='($oldVersionInfo.FileVersion)', New='($newVersionInfo.FileVersion)'. Potential breaking changes." -Details $fileVerDetails
} else {
    Add-CheckResult -CheckName "File Version (Major)" -Status "PASS" -Message "File Major Versions match: '$oldFileMajor'." -Details $fileVerDetails
}

Write-Verbose "Checking Digital Signatures..."
$oldSig = Get-AuthenticodeSignature -FilePath $OldDllPath -ErrorAction SilentlyContinue
$newSig = Get-AuthenticodeSignature -FilePath $NewDllPath -ErrorAction SilentlyContinue

$sigDetails = @{} 

$oldDllStatus = "N/A"
if ($oldSig) { $oldDllStatus = ($oldSig.Status | Out-String).Trim() }
$sigDetails.Add("OldDll_Status", $oldDllStatus)

$oldDllSigner = "N/A (Certificate not found or no subject)"
if ($oldSig.SignerCertificate) {
    $oldDllSigner = ($oldSig.SignerCertificate.Subject -replace "`n|`r", " ").Trim()
}
$sigDetails.Add("OldDll_Signer", $oldDllSigner)

$newDllStatus = "N/A"
if ($newSig) { $newDllStatus = ($newSig.Status | Out-String).Trim() }
$sigDetails.Add("NewDll_Status", $newDllStatus)

$newDllSigner = "N/A (Certificate not found or no subject)"
if ($newSig.SignerCertificate) {
    $newDllSigner = ($newSig.SignerCertificate.Subject -replace "`n|`r", " ").Trim()
}
$sigDetails.Add("NewDll_Signer", $newDllSigner)

$sigMessage = ""
$sigStatus = "PASS"

if (-not $oldSig -or $oldSig.Status -ne "Valid") {
    $sigMessage += "Old DLL: $($oldSig.Status). " 
    $sigStatus = "WARN"
} else {
    $sigMessage += "Old DLL: Valid. "
}
if (-not $newSig -or $newSig.Status -ne "Valid") {
    $sigMessage += "New DLL: $($newSig.Status). " 
    if ($sigStatus -ne "FAIL") { $sigStatus = "WARN" } 
} else {
    $sigMessage += "New DLL: Valid. "
}

if ($oldSig.Status -eq "Valid" -and $newSig.Status -eq "Valid") {
    if (($oldSig.SignerCertificate.Thumbprint) -ne ($newSig.SignerCertificate.Thumbprint)) {
        $sigMessage += "Signers differ (Thumbprints do not match). "
        $sigStatus = "WARN" 
    } else {
        $sigMessage += "Signers match. "
    }
} elseif (($oldSig.Status -eq "Valid" -and $newSig.Status -ne "Valid") -or `
           ($oldSig.Status -ne "Valid" -and $newSig.Status -eq "Valid") ) { 
    $sigMessage += "One DLL is validly signed, the other is not or has an issue. "
    if ($sigStatus -ne "FAIL") {$sigStatus = "WARN"}
}

Add-CheckResult -CheckName "Digital Signatures" -Status $sigStatus -Message $sigMessage.Trim() -Details $sigDetails

$statusColors = @{
    "PASS"          = "Green"
    "WARN"          = "Yellow"
    "FAIL"          = "Red"
    "CRITICAL_FAIL" = "Red" 
    "N/A"           = "Gray" 
}

Write-Host "`n`n--------------------------------- DLL Compatibility Check Summary---------------------------" -ForegroundColor Cyan
Write-Host "Old DLL: $OldDllPath"
Write-Host "New DLL: $NewDllPath"

$overallStatusForDisplay = $results.OverallStatus
$overallStatusColor = $statusColors[$overallStatusForDisplay]
if (-not $overallStatusColor) { $overallStatusColor = "White" } 

Write-Host "Overall Status: " -NoNewline
Write-Host $overallStatusForDisplay -ForegroundColor $overallStatusColor

Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor Cyan
foreach ($check in $results.Checks) {
    $currentStatusColor = $statusColors[$check.Status]
    if (-not $currentStatusColor) { $currentStatusColor = "White" } 

    Write-Host "[ " -NoNewline
    Write-Host $check.Status -ForegroundColor $currentStatusColor -NoNewline
    Write-Host " ] " -NoNewline
    Write-Host "$($check.CheckName): $($check.Message)" 

    if ($check.Details.Count -gt 0) {
        $check.Details.GetEnumerator() | ForEach-Object {
            Write-Host "      " -NoNewline 
            Write-Host "$($_.Name): " -ForegroundColor Gray -NoNewline 
            Write-Host $_.Value 
        }
    }
}
Write-Host "------------------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Warning "REMINDER: Exported function compatibility is a critical check NOT performed by this lightweight script. Use tools like dumpbin.exe for that analysis if issues are suspected or for higher assurance."
Write-Host "------------------------------------------------------------------------------------------`n`n" -ForegroundColor Cyan


