# Network – Endpoint Connectivity Test

## Overview

The **Network – Endpoint Connectivity Test** package allows administrators to run connectivity diagnostics **from a selected endpoint** to a specified destination host or IP address via Tanium.

This package performs:

* ICMP test using `Test-Connection`
* Legacy `ping.exe` test
* TCP port connectivity checks on:

  * Port 80 (HTTP)
  * Port 443 (HTTPS)
  * Port 3389 (RDP)

The test executes in the SYSTEM context on the targeted endpoint.

---

## Package Configuration

### Command

```cmd
cmd.exe /d /c ""%WinDir%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -NoProfile -File network_test.ps1 "$1""
```

### Parameter Inputs

| Parameter           | Type       | Description                                                |
| ------------------- | ---------- | ---------------------------------------------------------- |
| $1 – destination IP | Text Input | Target IP address or hostname to test connectivity against |

### Prompt Text

> Enter the target IP address or hostname for testing.

---

## How It Works

1. User deploys action.
2. Tanium Cloud encodes parameter input.
3. PowerShell script decodes parameter using:

```powershell
[System.Uri]::UnescapeDataString()
```

4. Script performs:

   * 4 ICMP requests
   * 4 ping.exe requests
   * TCP port checks (80, 443, 3389)
5. Results are returned in action output.

---

## Operational Workflow (How to Use in Practice)

### Step 1 – Deploy the Package

Run the package against the target endpoint(s) from the Tanium Console.

Example:

```
Destination IP: 8.8.8.8
```

---

### Step 2 – Capture the Action ID

After deployment, note the **Action ID** shown in the Action Summary.

Example:

```
Action ID: 123526
```

---

### Step 3 – Direct Connect to Endpoint

Use Tanium Direct Connect (or remote session access) to connect to the targeted machine.

Navigate to:

```
Reporting → Actions → <Action ID>
```

Locate the matching Action ID (e.g., 123526) to review execution output.

---

### Step 4 – Review Output

Example action output:

```
=== Network Test Report ===
Target: 8.8.8.8
Timestamp: 02/25/2026 10:47:27

--- Test-Connection ---
Address  ResponseTime
8.8.8.8  3
8.8.8.8  3
8.8.8.8  3
8.8.8.8  4

--- ping.exe ---
Reply from 8.8.8.8: bytes=32 time=3ms TTL=117
...

--- TCP Port Checks ---
Port 80  : False
Port 443 : True
Port 3389: False

=== End of Report ===
```

---

## Interpretation Example

For `8.8.8.8`:

* ICMP successful (0% packet loss)
* Port 443 reachable
* Ports 80 and 3389 not reachable

This indicates outbound HTTPS connectivity is allowed from the endpoint.

---

## Use Cases

* Troubleshooting branch connectivity
* Validating firewall rules
* Testing service reachability
* Confirming RDP access
* Network team diagnostics
* Verifying outbound filtering policies

---

## Security & Execution Context

* Runs as **LOCAL SYSTEM**
* Executes non-interactively
* Read-only diagnostics
* No configuration changes
* Safe for production use

---

## Requirements

* Windows endpoint
* PowerShell 3.0+
* Test-NetConnection available (Windows 8+/Server 2012+)

---

## Known Limitations

* Fixed port checks (80, 443, 3389)
* No IPv6 validation
* DNS resolution depends on endpoint configuration
* Does not log to file locally (console output only)

---

## Possible Future Enhancements

* Custom port parameter
* Timeout parameter
* IPv4/FQDN validation regex
* JSON structured output
* Auto-log to local file
* Convert to sensor-based reporting
* Add traceroute functionality

