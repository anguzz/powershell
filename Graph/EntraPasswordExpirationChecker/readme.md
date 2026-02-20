# Entra Password Expiration Checker

A lightweight Windows GUI utility for IT Support and Helpdesk teams to quickly determine a user’s password expiration status in Microsoft Entra ID (Azure AD).

This tool compares:

* The user’s **LastPasswordChangeDateTime**
* Your organization’s **password policy interval** (configured in script)

It calculates the remaining days until expiration and displays the result in a simple graphical interface.

---

## Purpose

This tool eliminates the need to:

* Manually query Microsoft Graph
* Search audit logs
* Check multiple portals
* Perform date calculations manually

It provides a fast, consistent method for support teams to verify password status during user calls.

---

## Features

* GUI-based input (no command-line required)
* Microsoft Graph integration
* Displays:

  * Password expired
  * Password expiring soon
  * Password within policy
  * Account disabled
* Clickable link to:
  [https://myaccount.microsoft.com](https://myaccount.microsoft.com)
* EXE conversion support via PS2EXE
* No local image dependencies (uses hosted image)

---

## Requirements

* Windows machine
* PowerShell 5.1+
* Microsoft Graph PowerShell SDK
* Appropriate Graph permissions:

  * `User.Read.All`

---

## Configuration

Inside the script, configure your password policy interval:

```powershell
$PasswordPolicyInterval = 90
```

Adjust this value to match your organization’s password expiration policy.

---

## How It Works

1. User enters the username (without domain).
2. Script constructs the UPN using the configured domain.
3. Script connects to Microsoft Graph.
4. Retrieves:

   * DisplayName
   * LastPasswordChangeDateTime
   * AccountEnabled
5. Calculates remaining days.
6. Displays result in a clean popup.

---

## Converting to EXE

You can compile the script into a standalone executable using PS2EXE:

```powershell
ps2exe .\passwordAgeChecker.ps1 .\passwordAgeChecker.exe -noConsole -iconFile .\icon.ico
```

Recommended flags:

* `-noConsole` → hides PowerShell window
* `-iconFile` → custom application icon

---

## Use Cases

* Helpdesk password expiration checks
* Internal IT support tooling
* Quick verification during user calls
* Self-service support kiosk environments

---

## Security Notes

* This tool requires Microsoft Graph authentication.
* Ensure appropriate least-privilege permissions are used.
* For production deployment, consider:

  * Certificate-based authentication
  * App registration instead of interactive login
  * Code signing the executable
