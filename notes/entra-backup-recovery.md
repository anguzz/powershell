# Microsoft Entra Backup and Recovery

Behavior, limitations, documentation, and recovery demo

## Permissions needed to interact with Entra Backup and Recovery

- **Microsoft Entra Backup Reader**: Can view backups, review difference reports, and check recovery history. Read-only.
- **Microsoft Entra Backup Administrator**: Includes Backup Reader permissions, plus the ability to create difference reports and trigger recovery jobs.
- **Global Administrator**: Can access Backup and Recovery by default, but should not be used for routine backup or recovery work.

## Licensing

Microsoft Entra Backup and Recovery is enabled by default when the tenant has the required **Microsoft Entra ID P1 or P2** licensing.

## Where to find Backup and Recovery

Go to:

```text
Microsoft Entra admin center > Entra ID > Backup and Recovery
```

## Supported core tenant objects

- Users
- Groups
- Applications
- Conditional Access policies
- Service principals
- Organization
- Authentication method policy
- Authorization policy
- Named locations

## How the recovery model works

Before recovering anything, it helps to understand what the recovery action does under the hood. The action depends on what changed since the selected backup was taken.

| Change since backup | Recovery action |
|---|---|
| Object was added | Object is soft-deleted |
| Object was updated | Object is reverted to the backup value |
| Object was soft-deleted | Object is restored |
| Object was restored | Object is soft-deleted |

## Demo: restore a deleted group without knowing the GUID

We begin with a group that existed before the latest backup occurred.

For this demo, I used **Test group 1**.

Afterwards, I deleted the group to simulate an accidental deletion.

Before deleting it, I grabbed the object ID for reference. This demo assumes we did not have that value ahead of time, because realistically, nobody remembers random GUIDs before something gets deleted.

At this point, I deleted the group and verified it's gone and I need to restore it.

I started by creating a difference report for changes since yesterday's backup point around **3:00 PM**.

In the difference report, it is fine to include all objects because the report is only showing what changed. If you already know the object type, you can filter it down to reduce noise.

You can review all group changes, or filter the report down to one group object type.

After creating the report, it stayed in a loading state for a while and the object/link counts were initially blank. Microsoft documentation says this can take a while depending on the total number of objects in the tenant.

> Note: I suspect difference reports run faster when scoped to a specific object type. In my testing, a groups only report took around 10 minutes, while an all objects report took closer to 50 minutes. This is not documented Microsoft behavior, just an observation from testing. My theory is that behind the scenes the service is performing a comparison between the selected backup and the current state of every object in scope. When all objects are included, it has significantly more objects to process and compare. When filtered to a single object type, it only needs to iterate through that subset, which may explain the reduced processing time.


In the results, I saw that one test group had been created recently, while **Test group 1** already existed before the backup. Restoring all groups would touch more than I wanted. The safer path was to find the object ID for **Test group 1** and restore only that object. 

And boom, the group was recovered with its existing members.

## Summary

The cleanest restore path is to run a difference report, filter to the object type if possible, find the object GUID, and then restore that specific object by GUID.

If you already have the GUID, you can skip the discovery step and restore directly by object ID. This saves time and reduces the chance of touching unrelated objects.

## Limitations and considerations

**Slow if you do not have the GUID:** You need to run a difference report, find the GUID, and then restore by GUID.

Restoring **all objects** or **all groups** should be reserved for disaster recovery or extreme use cases because it can impact unrelated objects.

**Recovery timing consideration:** In my initial testing, I created a group and immediately tried to restore it. Because the group was created after the most recent backup, it did not have a restore point yet.

Backups appeared to run around **3:00 PM** in testing, so recently created objects may not be recoverable until the next backup cycle completes.

If an object did not exist before the selected backup cycle, running recovery against all groups may soft-delete that newer object because it was not part of the backup point.

## Additional documentation

- [Microsoft Entra Backup and Recovery overview](https://learn.microsoft.com/en-us/entra/backup/overview)
- [Microsoft Entra Backup and Recovery by LazyAdmin](https://lazyadmin.nl/office-365/microsoft-entra-backup-and-recovery/)

