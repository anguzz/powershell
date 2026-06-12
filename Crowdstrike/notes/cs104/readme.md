

## CrowdStrike 104 Endpoint security: Falcon Detections 

### Core Concept

* **Detection = start of investigation, not the end**
* Alerts indicate something suspicious → requires analysis

***

### Types of Detections

* **IOC (Indicator of Compromise)**
  * Known bad (e.g., malicious file hash)

* **IOA (Indicator of Attack)**
  * Suspicious behavior patterns (more subtle)

***

### How Detections Trigger

* Driven by **prevention policies**
* Policies define:
  * What behaviors Falcon monitors
  * Whether activity is:
    * **Blocked**
    * **Allowed + logged**

***

### Key Identifiers

* **AID (Agent ID)**
  * Unique per endpoint/sensor
  * 1 device = 1 AID

* **CID (Customer ID)**
  * Identifies your environment

* **Pattern ID**
  * Identifies specific detection rule/behavior

***

### Detection Behavior / Limits

* Max **1,000 detections per day per AID**
  * If hit → likely compromised/noisy host → investigate

* Detections sent:
  * Every **≥ 5 seconds per Pattern ID + AID**

* Deduplication:
  * Same:
    ```
    CID + AID + Pattern ID + Process ID
    ```
  → compressed into **1 pattern hit**

***

### Notifications

* **1 email per detection per day**

***

## Key Takeaways

* High detection volume = strong signal something is wrong
* IOA detections are often more important than IOC (behavior vs known bad)
* Prevention policy tuning directly impacts:
  * Detection volume
  * False positives
* Deduplication prevents alert flooding but still preserves signal
