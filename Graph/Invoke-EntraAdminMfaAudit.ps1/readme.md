## Background

Microsoft Entra provides visibility into administrative accounts and MFA registration status, but correlating that information with assigned administrative roles can require data from multiple sources.

This script helps correlate:

- Administrative account status
- MFA registration status
- Assigned administrative roles

using Microsoft Graph data, making it easier to identify and validate privileged accounts that may require review.

Potential use cases include:

- Administrative account audits
- MFA registration reviews
- Security and compliance assessments
- Microsoft Entra recommendation investigations
- Secure Score validation
- Identity governance reviews

Depending on the environment, findings may include administrative user accounts, service accounts, role-assignable group members, or other privileged identities that meet Microsoft's criteria for administrative access.

Not all findings necessarily represent a security issue. Some identities may be intentionally configured and should be reviewed in the context of your organization's security, operational, and compliance requirements before any changes are made.

The script uses Microsoft Graph to:

- Enumerate administrative accounts
- Validate MFA registration status
- Identify administrative accounts without MFA registration
- Display assigned Entra roles
- Provide a clear console-based audit report


## Notes

- This script performs read-only operations.
- No configuration changes are made.
- Results are displayed directly in the console.
- Useful for administrative account audits, MFA registration reviews, Secure Score validation, identity governance reviews, and security assessments.