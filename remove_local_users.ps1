$AccountsToKeep = @('Administrator', 'Admin', 'Public', 'Default') #can add more to keep here, if its domained account do domain.com\account_name
Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath.split('\')[-1] -notin $profilesToKeep } | Remove-CimInstance


