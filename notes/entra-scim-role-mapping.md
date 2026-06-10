# Entra ID SCIM Role Mapping Notes

## Overview

Some SaaS applications support SCIM provisioning but do not fully support standard SCIM role objects or group to role synchronization.

In these cases, Microsoft Entra ID App Roles can be used as a lightweight RBAC mapping mechanism by converting assigned App Roles into string values that are provisioned through SCIM attribute mappings.

This is commonly done using custom SCIM extension attributes and Entra provisioning expressions.

Reference:
- https://learn.microsoft.com/en-us/entra/identity/app-provisioning/customize-application-attributes#provisioning-a-role-to-a-scim-app [1](https://learn.microsoft.com/en-us/entra/identity/app-provisioning/customize-application-attributes)[2](https://learn.microsoft.com/en-us/entra/identity/app-provisioning/functions-for-customizing-application-data)

---

# How the Mapping Works

## High-Level Flow

```text
Entra App Role Assignment
        ↓
Provisioning Expression
        ↓
SCIM Attribute Mapping
        ↓
Target Application Role Lookup
        ↓
RBAC Assignment
```

---

# Why This Is Used

This approach allows:

- Centralized RBAC management through Entra ID
- Dynamic role assignment during SCIM provisioning
- Group-based role inheritance through App Role assignments
- Simpler provisioning logic for SaaS platforms that expect role names as string values

This is especially useful when:
- the SaaS platform does not support SCIM groups
- the SaaS platform expects a role string
- the SaaS platform uses vendor-specific SCIM extensions

---

# The Entra Expression

A commonly used expression is:

```text
SingleAppRoleAssignment([appRoleAssignments])
```

This expression returns the user's assigned Enterprise Application App Role as a string value during provisioning.

Example output:

```text
Engineer
```

That value can then be written into a SCIM attribute mapping.

Reference:
- https://learn.microsoft.com/en-us/entra/identity/app-provisioning/functions-for-customizing-application-data [2](https://learn.microsoft.com/en-us/entra/identity/app-provisioning/functions-for-customizing-application-data)[3](https://github.com/MicrosoftDocs/entra-docs/blob/main/docs/identity/app-provisioning/functions-for-customizing-application-data.md?toc=/entra/identity/multi-tenant-organizations/toc.json)

---

# Important Detail

The returned value behaves similarly to the App Role display name.

Because of this:
- role names are often case sensitive
- renaming App Roles may break provisioning
- the target application may perform exact string matching

Example:

```text
Engineer != engineer
```

For stability, App Role names should generally be treated as immutable identifiers once provisioning is in use.

---

# Why This Feels Non-Standard

Traditional SCIM role provisioning usually involves:
- SCIM role objects
- group objects
- immutable role IDs

This Entra pattern is different because:
- the role is effectively converted into a string
- the string is pushed through SCIM provisioning
- the SaaS platform performs its own internal role lookup

This is still a common Entra provisioning pattern for SaaS applications that implement simplified RBAC models.

---

# Generic Configuration Process

## 1. Create Enterprise Application

Create a dedicated Enterprise Application for:
- SSO/OIDC
- SCIM provisioning
- RBAC assignments

---

## 2. Create App Roles

Create App Roles inside the App Registration or Enterprise Application.

Examples:
- Engineer
- Admin
- Analyst

Important:
- naming consistency matters
- role names may be case-sensitive

---

## 3. Add Custom SCIM Attribute (if required)

Some applications require vendor-specific SCIM extension attributes.

Example format:

```text
urn:ietf:params:scim:schemas:extension:vendor:2.0:User:role
```

These are usually added under:

```text
Provisioning > Attribute Mapping > Show advanced options > Edit attribute list
```

---

# 4. Configure Provisioning Expression

Typical mapping:

| Setting | Value |
|---|---|
| Mapping Type | Expression |
| Expression | `SingleAppRoleAssignment([appRoleAssignments])` |

This dynamically converts App Role assignments into provisioned role values.

---

# 5. Assign Users or Groups

Users or groups receive App Role assignments through the Enterprise Application.

Provisioning then:
- evaluates the role assignment
- runs the expression
- provisions the mapped value through SCIM

---

# Known Limitations

- Role mappings are often string-based
- Exact naming consistency matters
- Multi-role provisioning behavior varies by SaaS platform
- Vendor-specific SCIM extensions may be required
- Some SaaS platforms do not support SCIM groups or standard role objects

---

# Additional Reading

## Microsoft Learn

### Attribute Mapping Customization
- https://learn.microsoft.com/en-us/entra/identity/app-provisioning/customize-application-attributes [1](https://learn.microsoft.com/en-us/entra/identity/app-provisioning/customize-application-attributes)

### Provisioning Expressions
- https://learn.microsoft.com/en-us/entra/identity/app-provisioning/functions-for-customizing-application-data [2](https://learn.microsoft.com/en-us/entra/identity/app-provisioning/functions-for-customizing-application-data)[3](https://github.com/MicrosoftDocs/entra-docs/blob/main/docs/identity/app-provisioning/functions-for-customizing-application-data.md?toc=/entra/identity/multi-tenant-organizations/toc.json)

### SCIM API Reference
- https://github.com/MicrosoftDocs/entra-docs/blob/main/docs/identity/app-provisioning/entra-id-scim-api-reference.md [4](https://github.com/MicrosoftDocs/entra-docs/blob/main/docs/identity/app-provisioning/entra-id-scim-api-reference.md)

---

# Notes

This approach is effectively using:
- Entra App Roles
- plus provisioning expressions
- plus SCIM extension attributes

as a lightweight RBAC federation mechanism for SaaS applications.