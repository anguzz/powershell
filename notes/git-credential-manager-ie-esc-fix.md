# Git Credential Manager – IE ESC Login Issue (Azure / Entra)

## Summary

Git Credential Manager was attempting to authenticate using an embedded Internet Explorer (IE) WebView, which is blocked by **IE Enhanced Security Configuration (ESC)** on hardened systems (e.g., Windows Server).

This prevents Microsoft login from loading during Git operations.

***

## Error Observed

The authentication window displayed:

> Content within this application coming from the website listed below is being blocked by Internet Explorer Enhanced Security Configuration.
>
> <https://login.microsoftonline.com>

Additional context from the prompt:

* Suggests adding the site to **Trusted Sites**
* Warns that doing so lowers security for that site across applications

***

## Root Cause

* Git Credential Manager defaulted to **embedded browser (IE-based WebView)**
* IE ESC blocks external web content like Microsoft login
* Common in:
  * Windows Server
  * Hardened enterprise builds
  * Older/default auth flows

***

## Fix (Recommended)

Force Git Credential Manager to use the **system browser (Edge/Chrome)** instead of the embedded IE flow:

```bash
git config --global credential.helper manager
git config --global credential.msauthFlow system
git config --global credential.useHttpPath true
```

***

## Result

* Authentication opens in the system browser
* Avoids IE/ESC restrictions entirely
* Works with modern Entra ID + Conditional Access policies
* More reliable for enterprise environments

***

## Notes

* This is the preferred long-term fix vs modifying IE security settings
* Avoid adding Microsoft login to Trusted Sites unless absolutely necessary
* Aligns with modern authentication practices (no legacy IE dependencies)
