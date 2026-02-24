
# Windows Boot Configuration Status (Tanium)

Detects and remediates the Windows “boot selection prompt” issue caused by leftover **temporary feature upgrade** boot loader entries (typically referencing `$WINDOWS.~BT\NewOS`) that were not removed after the upgrade finalized.

---

## What “Affected” Means

On healthy machines, `bcdedit /enum` shows the Windows Boot Manager `default` pointing to `{current}` and the `displayorder` contains only `{current}` (plus standard tooling), with no `$WINDOWS.~BT\NewOS` loader.

Example (clean):
- `default {current}`
- `displayorder {current}`
- `timeout` commonly `30` or your standard value

On **affected** machines, `bcdedit /enum all` shows an additional Windows Boot Loader entry staged during the feature update and still present after finalization:

- A Windows Boot Loader identifier like:
  - `{56657411-0387-11f1-9d97-f4ce23929167}`
- With fields like:
  - `path  \$WINDOWS.~BT\NewOS\WINDOWS\system32\winload.efi`
  - `systemroot  \$WINDOWS.~BT\NewOS\WINDOWS`

And Windows Boot Manager still includes both entries in `displayorder`, e.g.:
- `displayorder {56657411-...} {current}`

Even if `timeout = 0`, firmware can still present a boot choice when multiple OS loaders exist in `displayorder`.

---

## Why `{current}` Is Filtered Out

In `bcdedit`, the active OS loader is normally referenced via the alias `{current}` (and may also have a long-form GUID). The detection logic filters out `{current}` so the sensor only flags **non-current** GUIDs that represent leftovers/duplicates (especially those referencing `$WINDOWS.~BT\NewOS`).

---

## Sensor

### Name
`Windows 11 24H2 Boot Configuration Status`

### Script
`Get-BCDSyncStatus.ps1`

### Intended Interact Usage
Query:
- `Get Windows 11 24H2 Boot Configuration Status from all machines`
- Or combined:
  - `Get Computer Name and Windows 11 24H2 Boot Configuration Status from all machines`

### Sensor Settings (Tanium)
- Platform: Windows only
- Query Type: PowerShell
- Result Type: Text
- Ignores case in result values: 
- Splits into multiple columns: 
- Delimiter: `|`
- Columns:
  1. `Status` (Text)
  2. `LoaderCount` (Text)
  3. `Timeout` (Text)
  4. `DuplicateIDs` (Text)

### Interact Grid Tip
In the Interact grid, you’ll see a `Status` value such as **Affected**. You can click the word **Affected** and immediately select **Deploy Action**.

---

## Columns Explained

- **Status**
  - `Clean` (or equivalent): no non-current upgrade loaders remain
  - `Affected`: duplicate/temporary upgrade loader(s) detected
- **LoaderCount**
  - Count of loader-like entries detected (used for quick triage)
- **Timeout**
  - Boot manager timeout value (24H2 staging sometimes sets this to `30`)
- **DuplicateIDs**
  - GUID list detected as duplicates / leftovers (excluding `{current}`)

---

## Manual Validation (Local Machine)

### 1) Check via MSConfig
- `msconfig` → **Boot** tab  
Expected clean state:
- Single entry: `(C:\WINDOWS): Current OS; Default OS`

Affected indication:
- A second entry referencing:
  - `(C:\$WINDOWS.~BT\NewOS\Windows)`  
  This is the staged feature update loader that should have been removed.

### 2) Check via BCDEdit
Run:

```powershell
bcdedit /enum all
````

Look for Windows Boot Loader entries referencing:

* `\$WINDOWS.~BT\NewOS`

If present and also listed in Boot Manager `displayorder`, the device is affected.

---

## Remediation

### Script

`Invoke-BCD-Orphan-Cleanup.ps1`

### Key Safety Behaviors

* **“In-Use” sweep**: scans `bcdedit /enum all` and builds a protected set of GUIDs referenced by the active OS configuration (recovery sequence, resume objects, etc.).
* **Orphan-only deletion**: deletes only entries that are truly unreferenced/orphans, rather than guessing.
* **Dual protection**: protects both aliases (like `{current}`) and long-form GUIDs that are actually in use.

### Why BitLocker Must Be Suspended

Modifying BCD triggers a BitLocker warning and can cause a recovery key prompt on next boot.

Before running cleanup, suspend BitLocker for one reboot:

```powershell
Suspend-BitLocker -MountPoint "C:" -RebootCount 1
```

After reboot:

* BitLocker automatically resumes
* TPM validation returns to normal
* No manual intervention required

---

## Tanium Package (Deploy Action)

### Package Name

`Boot Configuration Database Orphan Cleanup`

### Run Command

```cmd
cmd.exe /c powershell.exe -ExecutionPolicy bypass -WindowStyle Hidden -NonInteractive -NoProfile -File Invoke-BCD-Orphan-Cleanup.ps1
```

### Verification Query

Use the sensor output to validate remediation:

* `Windows 11 24H2 Boot Configuration Status contains "Clean"`

---

## Troubleshooting / Recovery

### If a bad cleanup removes boot configuration

If a machine loses its boot loader configuration due to an earlier/incorrect script iteration, re-stage boot files with:

```powershell
bcdboot C:\Windows
```

Then re-run the status sensor and confirm it returns `Clean`.

---

## Outcome Confirmed

The remediation was executed through Tanium on an affected machine and confirmed:

* the extra boot entry referencing `$WINDOWS.~BT\NewOS` was removed
* the boot prompt/recovery behavior related to the duplicate entry was no longer present

