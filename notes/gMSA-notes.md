# gMSA Notes

## What is a gMSA?

A Group Managed Service Account (gMSA) is an Active Directory account whose password is automatically managed by the domain.

Benefits:

* Automatic password management
* No manual password rotation
* Improved security over traditional service accounts
* Can be used by multiple servers
* Supports clustered applications
* Reduces credential sprawl

***

## Service Account Types

### Traditional Service Account

* Standard user account
* Password must be managed manually
* Often shared across multiple systems
* Common audit finding

### MSA

Managed Service Account

* Password managed by AD
* Single computer only
* Cannot be shared between servers

### gMSA

Group Managed Service Account

* Password managed by AD
* Multiple servers can use the account
* Ideal for:
  * SQL Servers
  * IIS Web Farms
  * Scheduled Tasks
  * Windows Services
  * Clusters

### dMSA

Delegated Managed Service Account

* Introduced with Windows Server 2025
* Designed to simplify migration away from traditional service accounts
* Uses device identity concepts

***

## Prerequisites

Before using a gMSA:

* Active Directory schema supports gMSA
* KDS Root Key exists
* Servers are domain joined
* Servers are authorized to retrieve the managed password

Verify KDS Root Key:

```powershell
Get-KdsRootKey
```

Create KDS Root Key (lab only):

```powershell
Add-KdsRootKey -EffectiveImmediately
```

***

## Creating a gMSA

Example:

```powershell
New-ADServiceAccount `
    -Name "gmsa-web01" `
    -DNSHostName "gmsa-web01.contoso.com" `
    -PrincipalsAllowedToRetrieveManagedPassword WebServers
```

Create security group:

```powershell
New-ADGroup `
    -Name "WebServers" `
    -GroupCategory Security `
    -GroupScope Global
```

Add servers:

```powershell
Add-ADGroupMember `
    -Identity WebServers `
    -Members WEB01$,WEB02$
```

***

## Installing on a Server

Install:

```powershell
Install-ADServiceAccount gmsa-web01
```

Verify:

```powershell
Test-ADServiceAccount gmsa-web01
```

Expected:

```text
True
```

***

## Using a gMSA for a Windows Service

Specify:

```text
DOMAIN\gmsa-web01$
```

Notice the trailing `$`.

No password is required.

***

## Using a gMSA for Scheduled Tasks

Example:

```powershell
$Action = New-ScheduledTaskAction -Execute "notepad.exe"

$Principal = New-ScheduledTaskPrincipal `
    -UserId "CONTOSO\gmsa-web01$" `
    -LogonType Password

Register-ScheduledTask `
    -TaskName "gMSA Test" `
    -Action $Action `
    -Principal $Principal
```

***

## Common Troubleshooting

### Test Account

```powershell
Test-ADServiceAccount gmsa-web01
```

### Verify Group Membership

```powershell
Get-ADGroupMember WebServers
```

### Verify Installation

```powershell
Get-ADServiceAccount gmsa-web01
```

### Common Issues

* Server not in authorized retrieval group
* Missing reboot after group membership changes
* Missing "Log on as a service" right
* Missing "Log on as a batch job" right
* KDS Root Key issues
* Replication delays

***

## When to Use gMSAs

Good candidates:

* SQL Services
* IIS Application Pools
* Windows Services
* Scheduled Tasks
* Middleware servers
* Clustered workloads

Avoid:

* Non-domain systems
* Applications that do not support managed service accounts
* Cross-forest scenarios without proper planning
