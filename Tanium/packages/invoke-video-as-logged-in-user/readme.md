# Invoke-VideoAsLoggedInUser (Tanium Package)

## Overview
This package deploys and plays a video on an endpoint using **Windows Media Player**, launched in the **context of the currently logged-in user** from a Tanium package running as **SYSTEM**.

The script stages a video locally, suppresses Windows Media Player first-run prompts, launches playback in **fullscreen**, waits briefly, and then performs cleanup by deleting the staged file.

This pattern demonstrates how to **launch visible UI actions for the logged-in user from Tanium** using `runasuser64.exe`.

---

# How It Works

## 1. Stage the Video
The packaged video file is copied from the Tanium payload into a temporary staging directory.

**Destination**

```

C:\Temp\Tanium\rick.mp4

```

If the directory does not exist, it is created automatically.

---

## 2. Suppress Windows Media Player First-Run Prompts

Windows Media Player normally shows a **first-run setup wizard** which would interrupt automated execution.

The script pre-configures registry values so WMP launches immediately.

### Machine-Wide (HKLM)

```

HKLM\SOFTWARE\Microsoft\MediaPlayer\Preferences
AcceptedEULA = 1
FirstTime = 1

```
```

HKLM\SOFTWARE\Policies\Microsoft\WindowsMediaPlayer
GroupPrivacyAcceptance = 1

```

These settings indicate the EULA and privacy configuration have already been accepted.

---

## 3. Configure Current User Session (HKCU)

Because Tanium runs as **SYSTEM**, a registry value must be written in the **logged-in user's registry hive**.

This is executed using:

```

runasuser64.exe

```

Registry value created:

```

HKCU\Software\Microsoft\MediaPlayer\Preferences
AcceptedPrivacyGreeting = 1

```

---

## 4. Launch Video in Logged-In User Session

The video is launched using Windows Media Player with fullscreen playback.

```

wmplayer.exe <video> /play /fullscreen

```

Execution occurs in the **interactive user session** using:

```

runasuser64.exe /userenv /current

```

This ensures the video appears on the user’s desktop even though Tanium runs under SYSTEM.

---

## 5. Automatic Cleanup

After playback starts, the script waits **60 seconds** and then removes the staged video file.

```

Start-Sleep -Seconds 60
Remove-Item C:\Temp\Tanium\rick.mp4

```

If the file is still in use by Windows Media Player, deletion will silently fail without causing the package to fail.

---

# File Structure

```

Invoke-VideoAsLoggedInUser/
│
├── README.md
├── callVideo.ps1
└── rickRoll.mp4

```

---

# Tanium Package Configuration

## Install Command

```

cmd.exe /c powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -NoProfile -File callVideo.ps1

```

Runs the script silently.

---


# Key Paths

| Item | Path |
|-----|-----|
| Video Staging Directory | `C:\Temp\Tanium` |
| Video File | `C:\Temp\Tanium\rick.mp4` |
| Windows Media Player | `C:\Program Files (x86)\Windows Media Player\wmplayer.exe` |
| Tanium RunAsUser Tool | `C:\Program Files (x86)\Tanium\Tanium Client\Tools\StdUtils\runasuser64.exe` |

---

# Requirements

- Tanium Client installed
- `runasuser64.exe` available
- Windows Media Player installed
- An active interactive user session

---

# Notes

This technique can be reused for:

- Opening URLs in the user's browser
- Displaying notifications
- Launching applications for the logged-in user
- Triggering UI actions from Tanium Deploy

The key mechanism enabling this behavior is **`runasuser64.exe`**, which allows commands executed by SYSTEM to run within the active user session.

---

# Reference

Skipping Windows Media Player first-run wizard:

https://www.mydigitallife.net/skip-and-bypass-windows-media-player-initial-settings-wizard-on-first-run/
