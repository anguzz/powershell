# Microsoft 365 Apps – Update Channels & Waves

## What this is

* Microsoft 365 Apps updates are controlled by:

  * **Update channel** → what version/features users get
  * **Update waves** → when users get that update


## Update channels (what users get)

### Monthly Enterprise Channel (recommended)

* Updates once per month (predictable schedule)
* Balanced between stability and new features
* Best default for most organizations

### Current Channel

* Updates more frequently (as features release)
* Gets newest features first
* Higher risk of issues

### Semi-Annual Enterprise Channel

* Updates twice per year
* Most stable, slowest feature delivery
* Used in highly controlled environments


## Update waves (when users get it)

### What update waves are

* **Staggered rollout** of updates within the same channel
* Control **timing**, not version
* All users stay on the **same channel**

### How it works

1. Microsoft releases update to the channel
2. **Wave 1** (IT/Test) gets it first
3. Delay (configurable days)
4. **Wave 2** (Pilot users)
5. More delay
6. **Wave 3+** (Broad rollout)
7. Final wave = remaining devices


## Portal

* **[https://config.office.com/](https://config.office.com/)**
* Microsoft 365 Apps admin center

### Path

* **Servicing → Servicing profiles**

  * Configure waves
  * Set rollout delays
  * Assign groups


## Wave membership

* Based on **Entra ID user/device groups**
* Devices not assigned → fall into **final wave**


## What they apply to

* Microsoft 365 Apps:

  * Outlook
  * Word
  * Excel
  * PowerPoint
  * Other Office apps


## What they are NOT

* Not different update channels
* Not Windows updates
* Not Intune update rings
* Not feature targeting


## Why orgs use this

* Reduce risk of bad updates
* Catch issues early (IT/pilot users)
* Prevent org-wide outages


## Important limitations

* Updates **cannot be skipped**
* Waves only **delay**, not block
* Everyone eventually updates (deadlines enforce this)


## Example rollout

* Wave 1: IT (Day 0)
* Wave 2: Pilot (Day 3)
* Wave 3: Broad (Day 7)


## Key concept

> Update channels = what version
> Update waves = when it is deployed

