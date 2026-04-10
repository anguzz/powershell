# Remove Microsoft Store / Appx Application 

Tanium can uninstall Appx packages from endpoints; however, it only removes the installed AppxPackage for existing users. It does not remove the AppxProvisionedPackage from the system image, `uninstall.ps1` does both. 

## Notes / Documentation

* **Packages** in Tanium = the executable action (e.g., run uninstall).
* **Sensors** = used to detect application presence (boolean logic).
* **Remediation logic** = runs the uninstall package only if the sensor reports the app is installed.
* **Store apps** require the `Installed Store Apps` sensor (not `Installed Application Exists`).

 Local validation example:

```powershell
Get-AppxPackage "<AppNameOrID>"
```

---

## Step 1 – Identify Correct Sensor

For Microsoft Store / Appx apps:

* Use **Installed Store Apps**
*  not Installed Application Exists
* Example query to detect presence:

```sql
Get Computer Name and Installed Store Apps
from all entities
with Installed Store Apps:Name contains <AppNameOrID>
```

---

## Step 2 – Create Uninstall Package

1. Go to **Administration (wrench icon) > Packages → + New Package**
2. Command line:

```cmd
cmd.exe /c powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -NoProfile -File uninstall.ps1
```

3. Attach a PowerShell script (`uninstall.ps1`) under *Files*.


---

## Step 3 – Configure Verification

Create a verification expression that ensures success = app not found:

```sql
Installed Store Apps does not contain <AppNameOrID>
```

---

## Step 4 – Test and Deploy

* Use **Interact** to target machines:

```sql
Get Computer Name and Installed Store Apps
from all entities
with Installed Store Apps:Name contains <AppNameOrID>
```

* Select endpoints → Deploy the uninstall package.
* Track status in **Action History** and **Client Status Details**.
* Great way to check if it worked is to re-run the query post-deployment to confirm the app is no longer installed.


 Example App Substitution:

* Replace `<AppNameOrID>` with the store package name, e.g.:

  * `Microsoft.Microsoft3DViewer`
  * `Microsoft.SkypeApp`
  * `Microsoft.MSPaint`
