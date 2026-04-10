# Notes on Custom Content Creation (Tanium)

## Objectives

After this course, you should be able to:

* Explain how content runs in Tanium on endpoints
* Explain Tanium’s safeguards for content
* Explain how sensors can impact endpoints
* Use Tanium-specific best practices for sensors and packages
* Test content created for Tanium
* Review built-in Tanium content


## What “Content” Means in Tanium

Content is:

* Anything that runs on the endpoint that is **not** the Tanium Client itself
* Scripts, packages, sensors, etc.
* Whatever operators use inside **Tanium Interact**
* Dashboards, questions, sensors, actions (packages)
* Tanium’s flexibility layer
* Arbitrary data selection and machine filtering
* Arbitrary file distribution

## Initial Registration & Client Topology

* When a computer boots or connects:

  * It creates a list of peers
  * **10 forward and 10 backward** in its linear chain
* This happens:

  * On every boot
  * On reconnects
  * On topology changes

## Strings, Answers, and Reporting

### Strings & Reporting Mechanics

* String reports are **key-value pairs**:

  * Hash → text string
* Every new question:

  * Is converted to a hash
  * Cached and reused
  * Counts are tracked

### Example

* Asking for `"Windows 10"`:

  * Creates or increments a string hash
* Discovering a new Linux OS like `"Ubuntu"`:

  * Client sends a string report
  * Server creates an entry with a count of `1`

### Why This Matters

* String hashing improves communication speed
* **New strings consume network bandwidth**
* Strings are cached on the server
* Strings are one of the **largest RAM consumers** on the Tanium Server

## Answer Reports vs String Reports

### Answer Report

* Hash-based
* Optimized for speed
* Sent first

### String Report

* Maps hash → human-readable value
* Stored in server memory and disk
* Can lag behind answer reports

### Tooling

* **TPAN (Tanium Platform Analyzer)**:

  * Identifies “stringiest” sensors
  * Helps determine refactoring or removal targets

## “Current Result Unavailable” vs “Results Currently Unavailable”

### Current Result Unavailable

* Client is busy
* Question is passed along the chain
* Temporary placeholder
* Common causes:

  * Slow endpoints
  * Resource contention
  * Poor sensor design

### Results Currently Unavailable

* Answer hash received
* Matching string not yet received
* Often because:

  * String is newly seen
  * String was purged from the database
* Server requests resend
* Temporary until resolved

## Example: Bad Sensor (Good Data, Poor Design)

### Context

A real-world sensor returned **accurate and valuable data**, but was **poorly designed for scale**.

* Customer suspected `sudo` access compromise
* Requested file timestamps across endpoints
* Data was powerful — but design was dangerous

### What the Sensor Did

Returned file timestamps:

* `ctime` (change time)
* `atime` (access time)
* `mtime` (modified time)

Output was **highly dynamic** per endpoint.

### Why This Is a Bad Sensor

* Each timestamp change = **new string**
* Tanium hashes **every unique string**
* At scale, this explodes the strings database

### Observed Impact

* ~15,000 endpoints
* ~3 timestamps per endpoint
* ~45,000 unique string hashes
* Resulted in:

  * Frequent **Current Result Unavailable**
  * Increased endpoint CPU usage
  * Server-side string matching delays

### Key Takeaways

* Correct data can still be **harmful at scale**
* Highly dynamic values are dangerous:

  * Timestamps
  * Counters
  * Volatile state
* Sensors with volatile output should:

  * Be tightly scoped
  * Use low **Max String Age**
  * Avoid enterprise-wide targeting

### Best Practice

Use sensors like this only for:

* Small, targeted investigations
* Short-term troubleshooting

Prefer outputs that are:

* Aggregated
* Boolean
* Numeric
* Stable strings

**Rule of Thumb**

> If a sensor’s output changes frequently per endpoint, it probably doesn’t belong in a broad question.

## Reducing Strings (Part 1)

### DO List — Best Practices

* **Set Max Sensor Age as high as feasible**

  * Fewer executions = fewer answer reports

* **Set Max Strings and Max String Age as low as feasible**

  * More aggressive cleanup

* **Reduce sensor output to the minimum**

  * Less output = fewer strings

### DON’T List — Anti-Patterns

* **Don’t include unnecessary data**

  * Duplicate data = duplicate strings

* **Don’t include overly unique or verbose data**

  * Timestamps, ephemeral ports, etc.
  * Unique data = string explosion

## Reducing Strings (Part 2)

### Bucketing (Grouping Results)

* Generalize unique values
* Reduces number of returned strings
* Tradeoff:

  * You may lose precise comparison ability

Examples:

* `"165 MB"` → `"< 200MB"`
* `"12%"` → `"10–20%"`

### When Bucketing Is Not Appropriate

* Trace sensors
* Index sensors
* Forensic or investigative data

These should be **tightly scoped**, not global.

## Max Age Guidance

* Use the **highest Max Age** that makes sense
* Infrequently changing data → high Max Age
* Frequently changing data → lower Max Age

### Critical Warning

* **Never use a default Max Age below 10 minutes**
* Low Max Age causes:

  * Multiple executions
  * High endpoint CPU usage
  * Increased network traffic

### Overriding Max Age in Questions

```text
Get IP Address?maxAge=120 from all machines
```

* Overrides Max Age to 120 seconds
* Not saved in saved questions
* `?maxAge` is **case sensitive**

## 32-bit vs 64-bit (“Bitness”) on Windows

### File Redirection

* Tanium Client is **32-bit**
* On 64-bit Windows:

  * `System32` = 64-bit binaries
  * 32-bit apps are redirected to `SysWOW64`

### Native Access Workaround

* Use `%windir%\Sysnative` to access real 64-bit paths

### Redirection Examples

| Original Path                | Redirected for 32-bit           |
- - |
| `%windir%\System32`          | `%windir%\SysWOW64`             |
| `%windir%\lastgood\system32` | `%windir%\lastgood\SysWOW64`    |
| `%windir%\regedit.exe`       | `%windir%\SysWOW64\regedit.exe` |

### Practical Tanium Takeaway

Sensors, packages, and scripts executed by the **32-bit Tanium Client** will hit **SysWOW64** unless `Sysnative` is used.

Critical when:

* Reading/writing registry
* Calling native binaries
* Checking drivers or services

## Delimiters & Output Design

* Tanium does **not understand columns**
* Everything is a **string**
* Each output line = one string
* CRLF (`\r\n`) = multiple strings

### Delimiter Best Practices

* Use uncommon, single ASCII characters
* Pipe (`|`) or semicolon (`;`) are safe
* Avoid two-character delimiters
* Avoid locale-specific or obscure characters (e.g. ASCII 170)

## Parameter Input (Critical Tanium Detail)

### URL Encoding

* Parameters are **URL-encoded**, not plain UTF-8
* This is expected behavior

### Required Decoding

* Always decode using:

```powershell
Tanium.UnescapeFromUTF8()
```

Example bug:

```
Tools%2FTanium%2DCustomer
```

instead of:

```
Tools/Tanium-Customer
```

### Security Warning

* Decoding ≠ safe input
* Always validate decoded values
* Never blindly concatenate parameters into shell commands

### Slide-Friendly Summary

> **Note:** Tanium passes sensor parameters as URL-encoded strings (even file paths). This is normal. Always decode using `Tanium.UnescapeFromUTF8()` and validate input before use.

## Sensor Reuse Warning

* Sensors can call other sensors:

  * By name
  * By hash
* Instructor recommendation:

  * **Do not do this**
  * Avoids hidden dependencies and reuse bugs

## Client Versions & Platform Constraints

* Tanium Cloud supports **7.4+ clients only**
* Older content:

  * May lack encryption
  * Exists mainly for XP / 2003 compatibility
* Do **not** write new content for legacy clients

> Tanium Cloud Engineering can disable custom content that negatively impacts platform performance.

## Sensors & RBAC (High Impact, Easy to Miss)

* RBAC Computer Groups evaluate sensors on **every question**
* If string-heavy sensors are used in:

  * Computer Groups
  * RBAC Personas
* They will run **even when unrelated questions are asked**

### Impact

* Increased endpoint CPU
* Increased server memory usage
* Slower global question performance

**Rule of Thumb**

> Never use volatile or string-heavy sensors in RBAC definitions.

## Sensor Execution Boundaries (Read-Only Rule)

Sensors must **never**:

* Write files
* Modify registry
* Start or stop services
* Change system state

### Why

* Breaks RBAC trust boundaries
* Enables privilege escalation

### Design Pattern

* Long or stateful work:

  * Use a **package**
  * Write output to a file
  * Read it with a **sensor**

## Execution Context (SYSTEM Gotchas)

* Windows: runs as **LOCAL SYSTEM**
* Linux/macOS: runs as **root (uid 0)**

### Implications

* `HKCU` = SYSTEM hive
* `%USERPROFILE%` = SYSTEM
* Environment variables differ
* You can enumerate `HKEY_USERS`

### User Session Tools

* Run as logged-in user
* Do **not** elevate privileges

> All scripts must be **fully non-interactive**

## Max Strings & Max String Age (Details)

* **Max Strings**

  * Maximum strings retained per sensor
* **Max String Age**

  * Age threshold for cleanup

When exceeded:

* Strings older than Max String Age removed
* If none qualify:

  * Oldest or least-used removed

> Cleanup is **server-side**, not endpoint-side

## Sensor Naming Conventions

* Sensors **cannot be renamed**
* Dependencies rely on **hash**
* Best practices:

  * Use nouns
  * Avoid parser keywords:

    * `where`, `and`, `or`, `contains`, etc.
  * Prefix custom sensors:

    * `Org_`
    * `Custom_`

Same rules apply to packages.

## Package Execution Caveats

If a package launches background processes using:

* `start /B`
* `&`

Then Tanium:

* Immediately reports success
* Loses control and visibility
* Cannot enforce timeouts

Risks:

* Orphaned processes
* Zombie jobs
* Conflicting executions

> Background execution should be rare and intentional.

## Parameter Injection Risks

* URL-decoded parameters + shell execution = danger
* Example:

  * Parameter starts with `&`
  * Appended to `cmd.exe /c`
  * Executes arbitrary SYSTEM commands

### Mitigations

* Decode explicitly
* Validate input
* Never concatenate directly
* Use full executable paths
* Do not rely on PATH

## Sensor & Package Limits

### Sensors

* Runtime target: **< 1 minute**
* Script size:

  * ~28k chars (Windows)
  * ~27k chars (non-Windows)
* Output:

  * ~1000 answer lines max

### Packages

* Configurable timeouts
* Suitable for long-running tasks
* Can distribute execution

## Final Design Principle

> If it’s slow, volatile, dangerous, or state-changing —
> **it belongs in a package, not a sensor.**

# Lab Notes

## Sensor Error Visibility & Troubleshooting

* Preferences → uncheck **Hide error results from questions**
* Forces Tanium to show:

  * PowerShell syntax errors
  * Actual error messages in output column

If errors appear:

* Open sensor in edit mode
* Fix PowerShell syntax or logic

Here is a **clean, copy-pasteable text version** of the slide, lightly clarified but **content-equivalent**:

## Prompted Inputs (Parameters)

* Allow variable values to be declared at runtime

* Regular packages with parameters provided by a user at deployment time

  * Passed in the package command as `$1`, `$2`, etc.

    * Example:

      ```sh
      /bin/sh CustomTagAdd.sh "$1"
      ```
  * Referenced as variables in the package as `$1`, `$2`, etc.

* Sensor-sourced packages require the output of a sensor to be used as the parameter when deployed from a question

  * Passed in the package command line using sensor syntax enclosed in double pipes `||`

    * Example:

      ```sh
      /bin/sh CustomTagRemove.sh "||Custom Tags||"
      ```
  * Referenced as variables in the package as `$1`, `$2`, etc.

* Parameters are **always URL-encoded** (same behavior as sensors) and must be URL-decoded before use

* Be aware of how your scripting language indexes parameters:

  * **PowerShell**: `$args[0]`, `$args[1]`, etc. — starts at index **0**
  * **Python**: `sys.argv[1]`, `sys.argv[2]`, etc. — starts at index **1**
  * **Shell scripts**: `$1`, `$2`, etc. — starts at index **1**



## Creating a Sensor (Delimiter Example)

Using PowerShell with pipe delimiter:

```powershell
Get-LocalUser | ForEach-Object { Write-Output "$($_.Name) | $($_.Enabled) | $($_.Description)" }
```

Output:

```
Administrator | False | Built-in account for administering the computer/domain
DefaultAccount | False | A user account managed by the system.
FBMIT | True |
Guest(Disabled) | False | Built-in account for guest access to the computer/domain
WDAGUtilityAccount | False | A user account managed and used by the system for Windows Defender Application Guard scenarios.
```

## 32-bit PowerShell Limitation & Workaround

`Get-LocalUser` does not work under 32-bit PowerShell.

### CIM-Based Alternative

```powershell
Get-CimInstance -Namespace "root\cimv2" -ClassName "Win32_UserAccount"
```

Filtered output:

```powershell
Get-CimInstance -Namespace "root\cimv2" -ClassName "Win32_UserAccount" |
Select-Object Name, Disabled, Description |
ForEach-Object { Write-Output "$($_.Name) | $($_.Disabled) | $($_.Description)" }
```

Output preserved exactly as provided.

## Using 64-bit PowerShell in Packages

### Using TPowershell

```cmd
cmd.exe /d /c ..\..\Tools\StdUtils\TPowershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -NoProfile -File "Lab4-1 Local Users.ps1"
```

### Using Sysnative

```cmd
cmd.exe /d /c %SystemRoot%\sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -NoProfile -File "Lab4-1 Local Users.ps1"
```

## Parameter Handling in Scripts

Script expects three parameters:

```powershell
[string] $namelist = [System.Uri]::UnescapeDataString($args[0])
[string] $group    = [System.Uri]::UnescapeDataString($args[1])
[string] $groupid  = [System.Uri]::UnescapeDataString($args[2])
```

## Passing Parameters in Packages

Always quote parameters:

```cmd
cmd.exe /d /c PowerShell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -NonInteractive -File "Lab4-2 Parameters.ps1" "$1" "$2" "$3"
```

Verify ASCII quotes and hyphens when copy/pasting.

## Using Sensors as Parameters

Add sensor variables via **Add Sensor Variable**.

Example:

```cmd
cmd.exe /d /c PowerShell.exe -ExecutionPolicy ByPass -NoProfile -WindowStyle Hidden -NonInteractive -File "4-3 Sensor Sourced Parameters.ps1" "||Computer Name||" "$1" "$2" "$3"
```

## Lab scripting resources

* [https://shellcheck.net](https://shellcheck.net)
* [https://regex101.com](https://regex101.com)
