#taken from https://bonguides.com/how-to-cleanup-microsoft-graph-powershell-modules-in-windows/

#this is to remove all graph modules, sometimes updated sdks break, or multiple verisons of modules get installed and cause issues. 

#Required running with elevated right.

if (-not([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You need to have Administrator rights to run this script!`nPlease re-run this script as an Administrator in an elevated powershell prompt!"
    break
 }
 
 #Uninstall Microsoft.Graph modules except Microsoft.Graph.Authentication
 $Modules = Get-Module Microsoft.Graph* -ListAvailable | 
 Where-Object {$_.Name -ne "Microsoft.Graph.Authentication"} | Select-Object Name -Unique
 
 Foreach ($Module in $Modules){
   $ModuleName = $Module.Name
   $Versions = Get-Module $ModuleName -ListAvailable
   Foreach ($Version in $Versions){
     $ModuleVersion = $Version.Version
     Write-Host "Uninstall-Module $ModuleName $ModuleVersion"
     Uninstall-Module $ModuleName -RequiredVersion $ModuleVersion -ErrorAction SilentlyContinue
   }
 }
 
 #Fix installed modules
 $InstalledModules = Get-InstalledModule Microsoft.Graph* | 
 Where-Object {$_.Name -ne "Microsoft.Graph.Authentication"} | Select-Object Name -Unique
 
 Foreach ($InstalledModule in $InstalledModules){
   $InstalledModuleName = $InstalledModule.Name
   $InstalledVersions = Get-Module $InstalledModuleName -ListAvailable
   Foreach ($InstalledVersion in $InstalledVersions){
     $InstalledModuleVersion = $InstalledVersion.Version
     Write-Host "Uninstall-Module $InstalledModuleName $InstalledModuleVersion"
     Uninstall-Module $InstalledModuleName -RequiredVersion $InstalledModuleVersion -ErrorAction SilentlyContinue
   }
 }
 
 #Uninstall Microsoft.Graph.Authentication
 $ModuleName = "Microsoft.Graph.Authentication"
 $Versions = Get-Module $ModuleName -ListAvailable
 
 Foreach ($Version in $Versions){
   $ModuleVersion = $Version.Version
   Write-Host "Uninstall-Module $ModuleName $ModuleVersion"
   Uninstall-Module $ModuleName -RequiredVersion $ModuleVersion
 }
 
 Write-Host "`nInstalling the Microsoft Graph PowerShell module..."
 Install-Module Microsoft.Graph -Force
 Install-Module Microsoft.Graph.Beta -Force
 Write-Host "Done."