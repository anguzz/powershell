
# Intune Device Staging and Enrollment Runbook

## Windows Autopilot Device Preparation (v2) with Device Enrollment Manager and Primary User Automation


## Overview

This document describes a secure and scalable method for staging, enrolling, provisioning, and assigning ownership of corporate Windows devices using:

* Microsoft Intune
* Microsoft Entra ID
* Windows Autopilot Device Preparation (v2)
* Device Enrollment Manager (DEM) account
* Conditional Access controls
* Microsoft Graph automation

The design separates:

* enrollment
* provisioning
* identity
* ownership

This allows technicians or staging staff to enroll devices without becoming the permanent device owner, while still enforcing security controls and maintaining accurate user assignment after handoff.


### High level workflow

1. Device is reset to factory state
2. Technician signs in with DEM account
3. Device auto-enrolls into Intune
4. Device Preparation installs apps, scripts, and policies
5. Device is handed to the end user
6. User signs in normally
7. Automation updates device primary ownership


# Permissions and Control Model

This workflow relies on strict separation of responsibilities to avoid granting elevated access to technicians or staging accounts.

## Components configured

1. Device Enrollment Manager account
2. Conditional Access policy restricting the DEM account
3. Autopilot Device Preparation policy
4. Device and User security groups
5. Graph-based ownership reassignment

## Permission flow

DEM → allowed only to enroll devices
Device → enrolls automatically into Intune
Intune → applies provisioning policies
User → authenticates normally
Graph → assigns ownership

Result:

* safe staging
* limited privileges
* automated provisioning
* correct ownership
* minimal manual intervention


# Device Enrollment Manager Setup

## Purpose

A Device Enrollment Manager account allows bulk device enrollment without being subject to normal per-user device limits.

This account is used only during initial provisioning.

## Steps

Path
Intune → Devices → Enrollment → Device enrollment managers → Add

## Recommendations

* dedicated service account
* no daily usage
* no mailbox
* no admin permissions
* enrollment only


# Conditional Access for Enrollment Account

## Goal

Prevent the enrollment account from being used for normal sign-in while still allowing device enrollment.

## Configuration

Create a Conditional Access policy targeting the DEM account.

### Settings

Block all cloud apps
Exclude:

* Intune enrollment
* Device registration

## Outcome

* account cannot be used interactively
* reduces abuse risk
* safe for shared technician workflows


# Windows Autopilot Device Preparation (v2)

## Why Device Preparation

Compared to traditional Autopilot profiles:

* no hardware hash import
* uses serial numbers
* faster provisioning
* simplified setup
* easier troubleshooting


## Prerequisites

* Windows 11 22H2 or later
* Microsoft Entra Join only
* device not already registered in legacy Autopilot


## Enable automatic enrollment

Path
Entra → Mobility (MDM and MAM) → Intune

Set
MDM user scope

Required for devices to auto-enroll


## Allow device join

Path
Entra → Devices → Device settings

Allow users to join devices


# Groups

## Device group

Security group for:

* required apps
* scripts
* provisioning resources

### Required owner

Add:

Intune Provisioning Client
AppId: f1346770-5b25-470b-88bd-d5744ab7952c

This service principal is required for provisioning to function.


## User group

Security group used for policy assignment.

Users in this group receive the Device Preparation policy.


# Assign Required Resources

Assign to the device group:

* management agents
* security software
* configuration baselines
* cleanup scripts
* compliance tools

Keep installs lightweight to avoid long provisioning times.


# Create Device Preparation Policy

Path
Intune → Devices → Enrollment → Device preparation policies

## Recommended settings

Deployment
User driven
Single user
Microsoft Entra Join

Assignment
User group


# Add Corporate Identifiers

Device Preparation uses serial numbers instead of hardware hashes.

Path
Devices → Enrollment → Corporate identifiers → Serial number

Import serial numbers for corporate devices.


# Technician Staging Workflow

## Process

1. Factory reset device
2. Power on
3. Sign in with DEM account
4. Device auto-enrolls
5. Apps and scripts install
6. Provisioning completes
7. Device handed to user

No manual configuration required.


# Primary User Reassignment Automation

## Problem

Devices enrolled with DEM show:

Primary user = staging account

This causes:

* inaccurate reporting
* incorrect targeting
* licensing issues
* policy misalignment

## Solution

After the real user signs in, ownership is updated automatically.

## Implementation

A Microsoft Graph automation:

1. queries devices enrolled by the staging account
2. reads the `usersLoggedOn` property
3. parses the most recent login from the JSON response
4. calls the Graph API to update the device-to-user relationship
5. assigns the correct primary user

## Result

* accurate ownership
* correct targeting
* proper compliance reporting
* no manual reassignment required


# Benefits of This Approach

* scalable enrollment
* minimal technician privileges
* reduced manual effort
* faster provisioning
* improved security posture
* correct device ownership
* simplified lifecycle management


# Summary

This workflow combines:

* Device Enrollment Manager
* Conditional Access
* Autopilot Device Preparation (v2)
* group-based provisioning
* Graph ownership automation

Together, these components create a secure and repeatable device staging pipeline suitable for enterprise environments that need efficient provisioning with strong access control.

### Architecture diagram
```
                         ┌──────────────────────────────┐
                         │       Microsoft Entra ID     │
                         │  Identity + Device Join      │
                         │  Authentication + CA         │
                         └──────────────┬───────────────┘
                                        │
                                        │  Auth + Token issuance
                                        ▼
                         ┌──────────────────────────────┐
                         │          Intune Service      │
                         │  Device Enrollment + MDM     │
                         │  Apps + Scripts + Policies   │
                         └──────────────┬───────────────┘
                                        │
                                        │  Device Preparation (v2)
                                        ▼
                 ┌────────────────────────────────────────────┐
                 │   Intune Provisioning Client (Service SP)   │
                 │   - Linked to Device Group                  │
                 │   - Linked to User Group                    │
                 │   - Applies required resources              │
                 └──────────────┬─────────────────────────────┘
                                │
                                │  Policy targeting
                                ▼
────────────────────────────────────────────────────────────────────
                  Enrollment and Provisioning Workflow
────────────────────────────────────────────────────────────────────

┌───────────────────────┐
│  Technician Device    │
│  (Factory Reset OOBE) │
└───────────┬───────────┘
            │
            │  Sign-in
            ▼
┌──────────────────────────────┐
│ Device Enrollment Manager    │
│ (DEM Service Account)        │
│ - Enrollment only            │
└───────────┬──────────────────┘
            │
            │  Conditional Access
            │  - Block all apps
            │  - Allow enrollment only
            ▼
┌──────────────────────────────┐
│   Intune Enrollment          │
│   Automatic MDM Registration │
└───────────┬──────────────────┘
            │
            │  Provisioning
            ▼
┌──────────────────────────────┐
│ Device Preparation Policy    │
│ - Required apps              │
│ - Scripts                    │
│ - Baselines                  │
└───────────┬──────────────────┘
            │
            │  Handoff
            ▼
┌──────────────────────────────┐
│ End User Sign-in             │
│ (Real Employee Account)      │
└───────────┬──────────────────┘
            │
            │  Device telemetry
            │  usersLoggedOn (JSON)
            ▼
┌──────────────────────────────┐
│ Microsoft Graph Automation   │
│ - Read last logged-in user   │
│ - Parse JSON response        │
│ - Update primary user link   │
└───────────┬──────────────────┘
            │
            │  Ownership updated
            ▼
┌──────────────────────────────┐
│ Managed Corporate Device     │
│ - Correct primary user       │
│ - Correct targeting          │
│ - Accurate reporting         │
└──────────────────────────────┘
```

# References: 

- https://techuisitive.com/windows-autopilot-device-preparation-aka-autopilot-v2-step-by-step-guide/
- https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-policies
- https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-get?view=graph-rest-beta
- https://github.com/anguzz/powershell/tree/main/Graph/primary-user-bulk-reassign