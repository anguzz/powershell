# LDAP Overview 

## What is LDAP?
**LDAP (Lightweight Directory Access Protocol)** is used to:

- Authenticate users and services
- Read objects from a directory service (e.g., users, computers, groups)

LDAP is a **read / authentication protocol**, not a management or write-heavy protocol.

## Core LDAP Functions

LDAP does two main things:

1. **Bind** – authenticate to the directory
2. **Search / Query** – read directory data

## Common LDAP Bind Types

- **Simple bind**
  - Username + password
  - Least secure if not protected by TLS

- **Service account bind**
  - Most applications use this
  - Long-lived credentials
  - Should be tightly scoped

- **Kerberos / NTLM-backed LDAP**
  - Common on domain-joined systems
  - Uses existing Windows authentication context

## LDAP Destination (Directory Server)

**Example:**
192.0.2.10

This represents the system initiating the LDAP connection, commonly:

- Application servers
- Identity or access management tools
- SIEM collectors
- Monitoring or inventory systems

## LDAP Search Base

**Example:**
DC=example,DC=com

This defines **where in the directory tree the search begins**.

Think of the directory as a hierarchy:
```
DC=example,DC=com
├── OU=Users
├── OU=Computers
├── OU=Groups
├── CN=Schema
├── CN=Configuration
```

A broader search base = more data exposure.

## LDAP Queries

- LDAP queries are **filters**
- They define *what objects* and *attributes* are returned

Common use cases:
- Asset inventory
- Identity monitoring
- SIEM enrichment
- Device posture or compliance checks

## Why Security Teams Care About LDAP Binds

From a security perspective, LDAP activity answers:

- **Who** is reading directory data?
- **From where** are they connecting?
- **How much** are they allowed to see?
- **Is this behavior expected?**

LDAP logs effectively become an **audit trail of directory access**.

## Common Red Flags

- Non-service accounts performing frequent binds
- Service accounts binding from unexpected hosts
- Very broad search bases (e.g., domain root)
- Queries accessing:
  - `CN=Schema`
  - `CN=Configuration`
  without a clear operational reason

These patterns often indicate:
- Misconfiguration
- Excessive permissions
- Reconnaissance activity

## Key Takeaways

- **LDAP bind** = logging into the directory
- **LDAP query** = asking the directory questions
- LDAP monitoring dashboards = visibility into:
  - Who is asking
  - What they are asking
  - Whether it aligns with expected behavior


references:

https://ldapwiki.com/wiki/Wiki.jsp?page=LDAP%20Query%20Examples

https://theitbros.com/ldap-query-examples-active-directory/