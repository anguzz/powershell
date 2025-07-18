# Chrome Bookmark Backup Script

This script provides a simple way to back up a user's local Chrome bookmarks to their OneDrive folder. It's intended for environments where Chrome Enterprise profiles or Single Sign-On (SSO) are not in use or configured yet, and a local backup is needed via a scheduled remediation. 

---

## Functionality

The script automatically:

1. Detects the currently logged-in user.
2. Locates their Chrome Bookmarks file.
3. Copies the file to a date-stamped folder within their OneDrive.
4. Deletes old backups to save space.

---

## Configuration

Before deploying, update the variables at the top of the script.  
The most important one is:

- `$oneDriveRootFolderName`:  
  Set this to your organization's OneDrive folder name (e.g., `"OneDrive - YourCompanyName"`).

---

##  Deployment

This script is designed to be deployed as a PowerShell script through a management tool like **Microsoft Intune**, running under the **SYSTEM** context.
