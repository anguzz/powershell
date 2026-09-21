
# Defender Account Correlation Rules

Many orgs use alternate accounts for administration, or testing.

Example accounts:

```text
jdoe@contoso.com
admin.jdoe@contoso.com
tester.jdoe@contoso.com
alt.jdoe@contoso.com
```

Without account correlation, Microsoft Defender for Identity may display these as separate identities.

With account correlation rules configured, Defender can associate these accounts with the same user identity, improving investigation context and visibility.

---


## Supported Correlation Types

### Root UPN Prefix

Correlates accounts that share a common username after removing a defined prefix.

Example:

```text
jdoe@contoso.com
tester.jdoe@contoso.com
```

Defender associates the accounts based on the root username.

---

### Root UPN Suffix

Correlates accounts that share a common username after removing a defined suffix.

Example:

```text
jdoe@contoso.com
jdoe.tester@contoso.com
```

Defender associates the accounts based on the root username.

---

### Domain UPN

Correlates accounts with the same username across different domains.

Example:

```text
jdoe@contoso.com
jdoe@fabrikam.com
```

This can be useful for identities that exist in multiple domains but represent the same user. 

## How to Verify It Works

After creating a correlation rule and allowing time for processing:

```text
Microsoft Defender Portal
  > Assets
    > Identities
      > {User}
        > Observed in organization
          > Accounts
```

Review the identity profile and look for additional accounts associated with the identity.

Once correlation has been processed, Defender should display the related accounts as part of the same identity context.


## Microsoft Learn
- [Manage account correlation rules in Microsoft Defender for Identity](https://learn.microsoft.com/en-us/defender-for-identity/custom-account-correlation-rules)