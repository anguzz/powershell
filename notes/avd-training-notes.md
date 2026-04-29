# Azure Virtual Desktop (AVD) 

## 1. Overall AVD Setup Flow

At a high level, the AVD environment is built in this order:

1. Create an Azure Virtual Desktop host pool
2. Deploy session host virtual machines
3. Configure identity and directory integration
4. Publish desktops and applications
5. Enable user profile persistence with FSLogix
6. Configure monitoring and diagnostics
7. Implement load balancing and autoscaling
8. Enable cost optimization features
9. Configure multimedia optimizations
10. Apply security controls

---

## 2. Host Pools

### Purpose
A **host pool** is the core AVD object that defines how desktops or apps are delivered and how users are distributed across VMs.

### High‑level setup

- Create a **Pooled** host pool (shared infrastructure)
- Choose Azure region for deployment
- Select preferred app group type:
  - Desktop (full desktop access)
  - RemoteApp (published applications)
- Configure:
  - Load balancing algorithm
  - Maximum sessions per host

### Key decisions

- Pooled vs Personal desktops
- Load balancing strategy (breadth-first vs depth-first)
- Session density limits

---

## 3. Session Hosts

### Purpose
Session hosts are the **actual Azure virtual machines** users connect to for desktops and apps.

### High‑level setup

- Deploy session hosts during host pool creation
- Use a standardized image:
  - Windows 11 Enterprise multi-session
  - Microsoft 365 Apps included
- Configure:
  - VM size (CPU / memory based on workload)
  - Disk size and type
  - Availability options
- Place VMs in the correct VNet and subnet

### Identity join options

Session hosts are joined to one of the following:

- Active Directory via **Microsoft Entra Domain Services (AAD DS)**
- Microsoft Entra ID (cloud-native join)

---

## 4. Workspaces

### Purpose
A **workspace** is how users discover desktops and applications across one or more host pools.

### High‑level setup

- Create or reuse a workspace
- Register application groups to the workspace
- Users connect through:
  - Web client
  - Desktop client

---

## 5. Application Groups

### Purpose
Application groups control **what users see and can launch** inside AVD.

### Types

- **Desktop Application Group**
  - Full virtual desktop
  - Created automatically with the host pool
- **RemoteApp Application Group**
  - Individual published applications

### High‑level setup

- Use default Desktop App Group for full desktops
- Create RemoteApp App Groups as needed
- Add applications from:
  - Start Menu
- Assign users or Entra ID security groups
- Register application groups to a workspace

---

## 6. User Access Methods

### Web Client (Browser)

**Purpose**

- Quick access without installing software

**Setup**

- Ensure application groups are registered to a workspace
- Users sign in via the AVD web URL

**Limitations**

- Reduced device redirection
- Not compatible with all security features

---

### Desktop Client
**Purpose**

- Best performance and full feature set

**Setup**

- Install Remote Desktop client on endpoint:  
  https://learn.microsoft.com/en-us/previous-versions/remote-desktop-client/connect-windows-cloud-services?tabs=windows-msrdc-msi
- Subscribe to AVD workspace using Entra ID
- Launch desktops or RemoteApps

**Required for**

- Screen capture protection
- Multimedia redirection
- Advanced device control

---

## 7. Profile Management (FSLogix)

### Purpose
FSLogix enables **persistent user profiles** on non-persistent session hosts.

### High‑level setup

- Create Azure Storage Account
- Create Azure Files share for profiles
- Enable identity-based authentication:
  - Entra Domain Services / AD authentication over SMB
- Create security group for profile access
- Assign SMB permissions to the group
- Install FSLogix agent on all session hosts
- Configure FSLogix profile container settings:
  - Profile location (UNC path)
  - Enable profile containers
  - Delete local profiles when applicable

### Result

- Profile follows user between session hosts
- Supports pooled, non-persistent VMs

### Variables

#### Script usage

The following PowerShell script is run **once per session host** (or baked into a golden image).

```powershell
$storageAccountName = "NameofStorageAccount"

Create Directories
$LabFilesDirectory = "C:\LabFiles"

if (!(Test-path -Path "$LabFilesDirectory")) {
   New-Item -Path $LabFilesDirectory -ItemType Directory | Out-Null
}
if (!(Test-path -Path "$LabFilesDirectory\FSLogix")) {
   New-Item -Path "$LabFilesDirectory\FSLogix" -ItemType Directory | Out-Null
}

Download FSLogix Installation bundle
$fsLogixZipPath = "$LabFilesDirectory\FSLogix_Apps_Installation.zip"

if (!(Test-path -Path $fsLogixZipPath)) {
   try {
      Invoke-WebRequest -Uri "https://experienceazure.blob.core.windows.net/templates/aiw-avd-v3/FSLogix_25.06.zip" -OutFile $fsLogixZipPath -UseBasicParsing
   }
   catch {
      Write-Error "Failed to download FSLogix bundle: $_"
      return
   }

   function Expand-ZIPFile($file, $destination) {
      $shell = New-Object -ComObject shell.application
      $zip = $shell.NameSpace($file)
      foreach ($item in $zip.items()) {
            $shell.Namespace($destination).CopyHere($item)
      }
   }

   Expand-ZIPFile -File $fsLogixZipPath -Destination "$LabFilesDirectory\FSLogix"
}

Install FSLogix
if (!(Get-WmiObject -Class Win32_Product | where vendor -eq "FSLogix, Inc.")) {
   Invoke-Expression "C:\LabFiles\FSLogix\x64\Release\FSLogixAppsSetup.exe /quiet /install"
}

Registry configuration
$registryPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
if (!(Test-path $registryPath)) {
   New-Item -Path $registryPath -Force | Out-Null
}

New-ItemProperty -Path $registryPath -Name "VHDLocations" -Value "\$storageAccountName.file.core.windows.net\userprofile" -PropertyType String -Force | Out-Null
New-ItemProperty -Path $registryPath -Name "Enabled" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $registryPath -Name "DeleteLocalProfileWhenVHDShouldApply" -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $registryPath -Name "FlipFlopProfileDirectoryName" -Value 1 -PropertyType DWord -Force | Out-Null

Write-Host "Script Executed successfully"
```
---

## 8. Monitoring & Observability

### Purpose
Provide visibility into health, performance, and user behavior.

### High‑level setup

- Create Log Analytics workspace
- Enable Azure Monitor Insights for AVD
- Configure diagnostics on host pools and workspaces
- Deploy Azure Monitor Agent (AMA)
- Route logs and metrics to Log Analytics

### What’s captured

- Session health
- User connections
- VM performance
- Capacity utilization

---
## 9. Load Balancing

### Breadth‑First

- Spread sessions evenly across hosts

### Depth‑First

- Pack users onto fewer hosts
- Typically combined with autoscaling

---

## 10. Autoscaling (Scaling Plans)

### Purpose
Automatically scale session hosts based on time and demand.

### High‑level setup

- Create scaling plan
- Define schedules:
  - Ramp-up
  - Peak
  - Ramp-down
  - Off-hours
- Assign scaling plan to host pool

---

## 11. Cost Optimization

### Start VM on Connect

- Create custom RBAC role allowing VM start
- Assign role to AVD service principal
- Enable **Start VM on Connect**

---

## 12. Multimedia Optimization

### Microsoft Teams

- Requires Desktop Client
- Enable audio/video redirection
- Validate SlimCore optimization

---

## 13. Security Controls

### MFA

- Enforced through Conditional Access

### Conditional Access

- Target Azure Virtual Desktop
- Require MFA

### Screen Capture Protection

- Requires Desktop Client
- Enable AVD GPO templates

### AVD Administrative Templates
- Download AVD Policy Templates: https://aka.ms/avdgpo
- Place ADMX and ADML files in PolicyDefinitions
- The download provides `AVDGPTemplate.cab`, which contains the AVD ADMX/ADML files.

Policy path:
```
Computer Configuration
└ Administrative Templates
  └ Windows Components
    └ Remote Desktop Services
      └ Remote Desktop Session Host
        └ Azure Virtual Desktop
```
---

## 14. Application Masking (FSLogix)

### Purpose
Hide applications without uninstalling them.

### Script usage


```powershell
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile("https://raw.githubusercontent.com/CloudLabsAI-Azure/AIW-Azure-Virtual-Desktop/Azure-Virtual-Desktop-v3/LabFiles/hiderule.fxa","C:/Program Files\FSLogix\Apps\Rules\hiderule.fxa")
$WebClient.DownloadFile("https://raw.githubusercontent.com/CloudLabsAI-Azure/AIW-Azure-Virtual-Desktop/Azure-Virtual-Desktop-v3/LabFiles/hiderule.fxr","C:/Program Files\FSLogix\Apps\Rules\hiderule.fxr")
Start-Process -Wait -FilePath "C:\LabFiles\fslogix\x64\Release\FSLogixAppsRuleEditorSetup.exe" -ArgumentList "/S"
Start-Process -Wait -FilePath "C:\LabFiles\fslogix\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/S"
Write-Host "Script Executed successfully"
```
---

## 15. Migration Support

- Assess existing VDI/RDS
- Plan phased AVD onboarding

---

## 16. Architectural Flow

1. User authenticates with Microsoft Entra ID
2. Conditional Access evaluates access
3. User launches desktop or RemoteApp
4. Session hosted on pooled VM
5. FSLogix mounts profile container
6. Telemetry sent to Log Analytics