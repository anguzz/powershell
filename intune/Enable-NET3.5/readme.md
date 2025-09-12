# Overview
This Intune package enables `.NET framework 3.5 (includes .NET 2.0 and 3.0)` as a windows feature, as well as the following optional features.
- `Windows communicaiton foundation HTTP activation`
- `Windows communicaton foundation Non-HTTP Activation`

The [`dotNetFx35setup.exe](https://www.microsoft.com/en-us/download/details.aspx?id=21&msockid=3bb183d9d4606c1000569617d5f26d81)` from microsoft is a bootstrapper that does the same thing but calls a UI, which might cause some overhead, instead I just call on the feature directly here to be installled silently with powershell.

# References

# https://timmyit.com/2019/06/17/how-to-deploy-net-3-5-with-intune/#subparagraph2a


# Detection
 - Rule type: `Registry`
 - Key path `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v3.0`
 - Detectoion method:  `Key exists`

# Install commands
-  powershell.exe -Mode Install


# Get status command

```powershell
PS C:\Windows\System32> Get-WindowsOptionalFeature -Online -FeatureName "NetFx3"


FeatureName      : NetFx3
DisplayName      : .NET Framework 3.5 (includes .NET 2.0 and 3.0)
Description      : .NET Framework 3.5 (includes .NET 2.0 and 3.0)
RestartRequired  : Possible
State            : Enabled
CustomProperties :
                   \FWLink : http://go.microsoft.com/fwlink/?LinkId=296822
```
