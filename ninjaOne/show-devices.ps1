# quick script to show devices in NinjaRMM via API, and test api connectivity 

$ClientId     = "ADD_CLIENT_ID"
$ClientSecret = "ADD_CLIENT_SECRET"
$Base         = "https://us2.ninjarmm.com" #change region if necessary
$Scope        = "monitoring management control"   

$Body = "grant_type=client_credentials&client_id=$ClientId&client_secret=$ClientSecret&scope=$Scope"
$AccessToken = (Invoke-RestMethod "$Base/oauth/token" -Method POST -Body $Body -ContentType "application/x-www-form-urlencoded").access_token

$Headers = @{ Authorization = "Bearer $AccessToken"; Accept = "application/json" }
$Devices = Invoke-RestMethod "$Base/v2/devices" -Headers $Headers


Write-Host "`n----------------------------------------------"
"Total devices enrolled in NinjaRMM $($Devices.Count)"
Write-Host "`n----------------------------------------------"

$Devices | Select-Object id,systemName,@{n="LastContact";e={[DateTimeOffset]::FromUnixTimeMilliseconds($_.lastContact).DateTime}} | Format-Table -AutoSize
