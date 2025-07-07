
# Outlook 16 Signature Migrator

This remediation renames/duplicates Outlook signature files located at:
`C:\Users\<Username>\AppData\Roaming\Microsoft\Signatures`

After a domain change (e.g., `user@domain1.com` ➝ `user@domain2.com`), Outlook may no longer associate the existing signature files with the user's new email identity. As a result, signatures appear under "Signatures on this device" instead of under the user's active profile, or may not appear at all.

To resolve this, the script renames signature files that include the old domain in parentheses to reflect the user's updated email address. This ensures that Outlook correctly associates the signatures with the new domain and current user's email identity. This is currently configured for Outlook 16. 

---

### Files

- `Duplicate.ps1` - Performs a duplicate of the old domain files to the new one, meant to prepare ahead of time so users have access to both. Sometimes outlook 16 profiles stay stuck locally on their old domain profile, so doing a simple rename may not give them visibility if they don't succesfully migrate clientside. Recommend using this going forward. Added 7/7/25  Verified functionality. 

- `Rename.ps1` – Performs the file rename operation. Meant to be deployed via Intune against clients. Does not function if a local account is stuck on old profile which occurs sometimes.



---

### Example

**Before rename/dupe:**
```powershell
MyEmailSignature (firstname.lastname@domain1.com).htm
MyEmailSignature (firstname.lastname@domain1.com).rtf
MyEmailSignature (firstname.lastname@domain1.com).txt
MyEmailSignature (firstname.lastname@domain1.com)_files
```

**After rename:**
```powershell
MyEmailSignature (firstname.lastname@domain2.com).htm
MyEmailSignature (firstname.lastname@domain2.com).rtf
MyEmailSignature (firstname.lastname@domain2.com).txt
MyEmailSignature (firstname.lastname@domain2.com)_files
```

---

### File Content Changes

The script also updates references inside `.htm` and `.rtf` files. These files typically reference the signature folder (e.g., `_files` directory), so we update those references to reflect the new domain. This keeps embedded images and formatting intact.


---

### Caution

This script renames signature files/folders and updates internal domain references in `.htm`, `.rtf`, and `.txt` files. While designed to avoid partial matches, changes may still have unintended effects when updating file content.

Recommend testing on a few pilot users first and backing up signature folders beforehand.

