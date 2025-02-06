#must install these modules
Import-Module ActiveDirectory

$csvFilePath= "c:\PATH TO THE CSV FILE"
$csvFile=Import-Csv -Path $csvFilePath

foreach ($row in $csvFile) {
    $userName = $row.SAMAccountName 
    $managerName = $row.Manager 
    
    $user = Get-ADUser -Filter {SamAccountName -eq $userName}
    $manager = Get-ADUser -Filter {SamAccountName -eq $managerName}

    if ($manager) {
      
        Set-ADUser -Identity $user -Manager $manager
        Write-Host "Manager updated for $userName to $managerName"
    } else {
        Write-Host "User or manager not found for $userName or $managerName"
    }
}