#requires -Modules ActiveDirectory
Import-Module ActiveDirectory -ErrorAction Stop

$InputCsv  = "cleanup-groups.csv"
$OutputCsv = "groups-deleted.csv"

$items = Import-Csv $InputCsv
if (-not $items -or $items.Count -eq 0) {
    throw "No rows found in '$InputCsv'."
}

if (-not ($items[0].PSObject.Properties.Name -contains "ObjectGUID")) {
    throw "Input CSV must contain an 'ObjectGUID' column."
}

$results = foreach ($row in $items) {
    $rawGuid = $row.ObjectGUID

    $log = [ordered]@{
        Timestamp          = (Get-Date).ToString("s")
        InputObjectGUID    = $rawGuid
        GuidValid          = $false
        FoundInAD          = $false
        PlannedAction      = "SKIP"
        Status             = ""
        Error              = ""

        Name               = ""
        SamAccountName     = ""
        DistinguishedName  = ""
        ObjectGUID         = ""
        ObjectSID          = ""
        GroupCategory      = ""
        GroupScope         = ""
        whenCreated        = ""
        whenChanged        = ""
        Description        = ""
        ManagedBy          = ""
    }

    try {
        $guid = [guid]::Parse(($rawGuid -as [string]).Trim())
        $log.GuidValid = $true
    }
    catch {
        $log.Status = "Invalid GUID in input"
        $log.Error  = $_.Exception.Message
        [pscustomobject]$log
        continue
    }

    try {
        # Resolve group first
        $g = Get-ADGroup -Identity $guid -Properties ObjectGUID,ObjectSID,GroupCategory,GroupScope,whenCreated,whenChanged,Description,ManagedBy -ErrorAction Stop

        $log.FoundInAD         = $true
        $log.PlannedAction     = "DELETE"
        $log.Name              = $g.Name
        $log.SamAccountName    = $g.SamAccountName
        $log.DistinguishedName = $g.DistinguishedName
        $log.ObjectGUID        = $g.ObjectGUID.ToString()
        $log.ObjectSID         = $g.ObjectSID.Value
        $log.GroupCategory     = $g.GroupCategory
        $log.GroupScope        = $g.GroupScope
        $log.whenCreated       = $g.whenCreated
        $log.whenChanged       = $g.whenChanged
        $log.Description       = $g.Description
        $log.ManagedBy         = $g.ManagedBy

        # Delete group
        Remove-ADGroup -Identity $g.ObjectGUID -Confirm:$false -WhatIf -ErrorAction Stop
        # comment out Whatif when you're good to go for a live run

        $log.Status = "Deleted"
    }
    catch {
        $log.Status = "Lookup or delete failed"
        $log.Error  = $_.Exception.Message
    }

    [pscustomobject]$log
}

# if file doesnt exist this will create it, and if it does then it will append the deleted data only. 
if (-not (Test-Path $OutputCsv)) {
    $results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
} else {
    $results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 -Append
}

Write-Host "Wrote: $OutputCsv"
Write-Host ("Input rows: {0} | Deleted: {1} | Invalid GUID: {2} | Failed/Not Found: {3}" -f `
    $items.Count,
    ($results | Where-Object { $_.Status -eq "Deleted" }).Count,
    ($results | Where-Object { $_.GuidValid -eq $false }).Count,
    ($results | Where-Object { $_.GuidValid -eq $true -and $_.Status -ne "Deleted" }).Count
)