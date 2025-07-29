# Windows Tray App Template

A simple and persistent Windows tray application that provides a quick link to a specified URL. The app is deployed via an installer script that creates a scheduled task to auto-run on user logon.

This project uses the `ps2exe` utility to compile the PowerShell tray script into a standalone `.exe` for easier and more reliable deployment.

---



##  Structure

```
/WintrayToURL/
│
├── install.ps1       # Installer script to deploy the tray app and create scheduled task
├── tray_app.ps1      # PowerShell script for the tray application
└── logo.ico          # Tray icon used in the app
```

---

##  Setup and Compilation

###  Prerequisites

Install the `ps2exe` PowerShell script compiler:

```powershell
Install-Script -Name ps2exe -Force
```

> [ps2exe GitHub Repository](https://github.com/MScholtes/PS2EXE)

---

###  Compilation Steps

In your project directory, run:
`ps2exe -inputFile '.\tray_app.ps1' -outputFile '.\tray_app.exe' -iconFile '.\logo.ico' -noConsole`

This creates `tray_app.exe` with the icon embedded.

  - note: ensure image is an actual ico or it will throw errors, can be converted at https://cloudconvert.com/png-to-ico
  - ensure variables\filenames matchup `.\tray_app.ps1` and `.\tray_app.exe` accordingly

---

##  Installation

1. Ensure `tray_app.exe` is in the same directory as `install.ps1`.
2. Right-click `install.ps1` → **Run with PowerShell** (as Administrator).

The script will:
- Create `C:\Program Files\anguzz_github_tray_app`
- Copy `tray_app.exe` to that location
- Create a `Scheduled Task` to run the app at user logon
- Launch the tray app immediately

---

##  Intune Deployment 

This project is ideal for deployment via **Microsoft Intune**.

###  Package

Bundle this folder using `.intunewin` on `install.ps1` using the **Win32 Content Prep Tool**.

###  Create Win32 App

1. In Intune, create a new **Windows app (Win32)**.
2. Set **Install command** to:
  `powershell -ex bypass -file install.ps1`
3. Set **Detection rule**:
   - **Path**: `C:\Program Files\Anguzz github tray`
   - **File or folder**: `tray_app.exe`
   - **Detection method**: *File or folder exists*

4. Assign to desired **user/device groups**.

> The scheduled task ensures the tray app runs at logon for every user.


#### install commands 
- `powershell -ex bypass -file install.ps1`  General install command

#### Testing 7/29/25
- Local install tested as both standard user and admin — working as intended
- Local install tested via SYSTEM context using PsExec — working as intended
- Intune deployment successful — app installs and scheduled task created as expected 
  -  Initial launch does not occur immediately for intune deployment, post-install; requires user sign-out/sign-in for scheduled task to trigger