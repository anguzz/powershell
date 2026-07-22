# CrowdStrike RTR: Collecting Diagnostic Logs (CSWinDiag)

This quick guide covers how to generate and retrieve a CrowdStrike diagnostic package using Real Time Response (RTR).

## Permission requirements

Before running `cswindiag`, verify:

- RTR permissions are assigned (RTR Admin or RTR Analyst)
- High-risk RTR commands are allowed in the host's Response Policy
- `put-and-run` is enabled in the Response Policy

> **Crowdstrike docs mention:** `cswindiag` is considered a high-risk command because it relies on `put-and-run` functionality.

---

## Generate Diagnostic Package

Launch an RTR session and run:

```bash
cswindiag
```

Expected output:

```bash
The process was successfully started
Please wait 3-4 minutes and check output ZIP file in directory:

C:\Program Files\CrowdStrike\Rtr\PutRun
```

Wait a few minutes for the collection process to complete.

---

## Verify Diagnostic Package

Navigate to the output directory:

```bash
cd "C:\Program Files\CrowdStrike\Rtr\PutRun"
```

List contents:

```bash
ls
```

Example:

```bash
Directory listing for C:\Program Files\CrowdStrike\Rtr\PutRun

Name
----
cswindiag.exe
CSWinDiag_<hostname>_<random>.zip
```

The generated ZIP file contains diagnostic information that can be provided to CrowdStrike Support when troubleshooting sensor issues.

---

## Retrieve the File

Download the package to CrowdStrike Cloud using:

```bash
get "CSWinDiag_<hostname>_<random>.zip"
```

Example:

```bash
get "CSWinDiag_SERVER01_ABCD1234.zip"
```

The `get` command does **not** download the file directly to your workstation, instead it gets downloaded to the falcon cloud, from which you can download it  to your local machine.

---

##  download 

After running `get`, a banner appears at the top of the RTR window showing upload progress.

Example:

```bash
\Device\HarddiskVolumeX\Program Files\CrowdStrike\Rtr\PutRun\CSWinDiag_<hostname>_<random>.zip

100% Complete
[Download]
(7 days left)
```

Once downloaded you should get a password since the file is password protected.

`"get" file download: Unzip the file and enter this password: <password>`

## Downloading Later

If you leave the RTR session before downloading:

```text
Activity
  → Real Time Response
    → Audit Logs
```

Locate your RTR session and open the session details.

Retrieved files remain available for download from the session record for the retention period shown by CrowdStrike.

---

## What CSWinDiag Collects

Some of the data gathered includes:

### Falcon Sensor Information

- Sensor installation and update logs
- Sensor services and configuration
- Falcon policies and registry settings
- Sensor crash dumps (if present)

### System Information

- Operating system details
- Installed software
- Microsoft hotfixes
- Running processes
- Running services
- Network configuration

### Security Information

- Installed AV products
- BitLocker status
- ELAM status
- Firewall configuration
- Certificate validation checks

### Connectivity and Troubleshooting

- Cloud connectivity tests
- TLS configuration and validation
- Proxy configuration
- DNS cache information
- Cipher support checks

### Event Collection

- Windows Application event log errors
- Windows System event log errors
- Falcon sensor events (if enabled)

### Additional Diagnostics

- MSInfo32 export
- Driver inventory
- Service dependency validation
- Device and hardware information

---

## Troubleshooting

### "Command disabled by policy"

Verify:

- RTR Admin / RTR Analyst permissions are assigned
- `put-and-run` is enabled
- The host's Response Policy has synced


docs:
https://docs.crowdstrike.com/r/en-US/a5kj6wfu/v0abcacf