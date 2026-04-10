$destinationPath = "C:\pwExNotify"
 $scriptFile = "checkExpire.ps1"
 
 if (Test-Path $destinationPath) {
     $fullPath = Join-Path -Path $destinationPath -ChildPath $scriptFile
     
     if (Test-Path $fullPath) {
         Write-Output "Installation detected successfully."
         Exit 0  # Success code
     } else {
         Write-Output "Script file missing."
         Exit 1  
     }
 } else {
     Write-Output "Destination directory missing."
     Exit 1  
 }