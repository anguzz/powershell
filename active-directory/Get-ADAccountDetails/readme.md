
# Get-ADAccountDetails.ps1

This PowerShell script reads a CSV of account identifiers, queries Active Directory, and exports enriched account details to a new CSV.

It supports account formats such as:
- `DOMAIN\samAccountName`
- `samAccountName`

---

## Overview

The script:

- Imports account data from a CSV file  
- Normalizes account names to `samAccountName`  
- Attempts lookup in Active Directory using:
  - `Get-ADUser`
  - `Get-ADComputer`
  - `Get-ADObject` (fallback)  
- Collects selected directory attributes  
- Exports results to a structured CSV  

---

## Parameters

```powershell
-InputCsv   Path to input CSV (must contain column: Account)
-OutputCsv  Path to output CSV
````

---

## Expected Input Format

CSV must contain a column named `Account`.

Example:

```
Account
DOMAIN\user1
user2
DOMAIN\server01$
```

---

## Attributes Collected

The script retrieves the following properties (when available):

```powershell
Description
Department
Manager
Mail
CanonicalName
PasswordLastSet
WhenCreated
MemberOf
msExchRecipientTypeDetails
```

---

## Output Fields

Each row in the output CSV includes:

* Original input (`Account`)
* Parsed `SamAccountName`
* Resolution status (`Found`)
* Distinguished Name
* Selected directory attributes

---

## Usage

```powershell
.\Get-ADAccountDetails.ps1 `
    -InputCsv .\accounts.csv `
    -OutputCsv .\accounts_enriched.csv
```

---

## Behavior Details

* If `DOMAIN\user` format is provided, only `user` is used for lookup
* If lookup fails across all object types, the entry is still exported with:

  * `Found = False`
* `MemberOf` is flattened into a semicolon-separated string
* Script requires the **ActiveDirectory module (RSAT tools)**

---

## Customization

### Modify Queried Attributes

Update the `$searchFields` array:

```powershell
$searchFields = @(
    'Description'
    'Department'
    'Title'
    'EmployeeID'
)
```

### Add Fields to Output

Extend the output object:

```powershell
Title      = $adObj.Title
EmployeeID = $adObj.EmployeeID
```

### Discover Available Attributes

```powershell
Get-ADUser <username> -Properties *
```

---

## Notes

* Some attributes may be null depending on object type (e.g., computers vs users)
* `msExchRecipientTypeDetails` is only populated in environments with Exchange schema
* Ensure appropriate permissions to query directory objects

---

## Reference

* Microsoft documentation on recipient type values:
  [https://learn.microsoft.com/en-gb/answers/questions/4376081/(article)-recipient-type-values](https://learn.microsoft.com/en-gb/answers/questions/4376081/%28article%29-recipient-type-values)


