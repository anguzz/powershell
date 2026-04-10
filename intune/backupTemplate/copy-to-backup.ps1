#this source folder should point to the local folder you want copied
$source = "C:\myLocalApp"  

#should point to a location backed up by one drive, but im using documents.
$folderBackupName = "myBackup"
$destinationBase = "C:\Users\$env:USERNAME\OneDrive\Documents\Backups\$folderBackupName"  


$backupDate = Get-Date -Format "MM-dd-yy"  
$backupFolder = "$destinationBase\MDS_$backupDate" 
$logFolder = "$backupFolder\BackupLogs"
$logFile = "$logFolder\backup_log.txt"

if (!(Test-Path -Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
}

# robocopy operation, more info on this at  https://codingitch.com/robocopy-explained-secure-data-reliable-backups/
robocopy $source $backupFolder /MIR /COPYALL /Z /R:3 /W:5 /LOG:$logFile


$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    Write-Output "Robocopy encountered an error. Exit code: $exitCode" | Out-File -FilePath "$logFolder\error_log.txt" -Append
}

#removes all the previous backups except the most recent 3
$folders = Get-ChildItem -Path $destinationBase -Directory | Sort-Object CreationTime -Descending

$folders | Select-Object -Skip 3 | Remove-Item -Recurse -Force

Write-Output "Old folders deleted, kept the most recent one."
