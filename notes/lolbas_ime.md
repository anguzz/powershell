# Intune IME and AgentExecutor Security Notes

## What is IME?

The Intune Management Extension (IME) is installed on Intune-enrolled Windows devices. It runs as SYSTEM and is used to execute:

* Win32 apps
* PowerShell scripts
* Proactive Remediations
* Endpoint Privilege Management actions

IME executes scripts and installers through a helper binary called `AgentExecutor.exe`.

Path:

```
C:\Program Files (x86)\Microsoft Intune Management Extension\
```

---

## Why AgentExecutor is a LOLBAS

AgentExecutor.exe is a Microsoft-signed binary that can launch PowerShell or executables. Attackers can abuse it for proxy execution because:

* It runs scripts as SYSTEM when invoked through IME.
* It bypasses PowerShell ExecutionPolicy (by design).
* IME activity is often trusted and whitelisted, it might not be monitored as heavily as PsExec, WMI ,etc
* It blends into normal Intune agent behavior.

This makes it a valid post-exploitation technique if an attacker already has local admin.

---

## Key Limitations

AgentExecutor cannot:

* Elevate privileges on its own.
* Bypass UAC.
* Run privileged actions without the attacker already having admin.
* Provide remote access or initial compromise.

It is only useful after a local compromise.

---

## When an Attacker Can Abuse It

Requirements:

1. The device must be Intune-enrolled (IME installed).
2. The attacker must already have local admin privileges.
3. They can drop a script or executable into a writable path.
4. They can manually invoke AgentExecutor with valid arguments.

This gives them SYSTEM-level proxy execution under a trusted Microsoft process.

---

## Why Attackers Prefer It Over PsExec

* PsExec is noisy and heavily monitored.
* PsExec creates services and logs that are easy to detect.
* AgentExecutor is Microsoft-signed and normally runs PowerShell.
* IME process activity blends into legitimate Intune agent jobs.
* SYSTEM execution through IME leaves fewer obvious artifacts.

---

## Detection Recommendations

Monitor for any of the following:

### 1. AgentExecutor spawning PowerShell from unexpected paths

Examples:

* Temp directories
* Downloads
* AppData

### 2. AgentExecutor executed by a user instead of SYSTEM

Normal behavior:

```
NT AUTHORITY\SYSTEM -> AgentExecutor.exe
```

Suspicious:

```
UserAccount -> AgentExecutor.exe
```

### 3. Command-line arguments that do not match normal IME patterns

### 4. AgentExecutor spawning non-standard executables

Example:

```
AgentExecutor.exe -> payload.exe
```

---

## Key Takeaways

* IME and AgentExecutor are not vulnerabilities.
* They are common post-exploitation targets after admin access is gained.
* Companies that monitor PsExec but ignore IME may miss SYSTEM-level attacker activity.
* Strong EDR solutions (CrowdStrike, Defender ATP) should be configured to inspect IME activity.

