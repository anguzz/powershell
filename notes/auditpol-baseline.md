# **Audit Policy Baseline Notes**

## **Overview**

Configured and validated Windows Advanced Audit Policy settings using Intune to ensure required Success/Failure auditing is enabled across targeted endpoints.


## **Requested Changes**

Enable **Success + Failure** auditing for all required subcategories under specified audit categories.


## **Steps Completed**

### **1. Baseline Review**

Collected current audit settings:

```
auditpol /get /category:*
```

- Sample output with all fields set to all `No auditing` for visualization

```
C:\Windows\System32>auditpol /get /category:* 
System audit policy 
Category/Subcategory                      Setting 
System 
  Security System Extension               No Auditing 
  System Integrity                        No Auditing 
  IPsec Driver                            No Auditing 
  Other System Events                     No Auditing 
  Security State Change                   No Auditing  
Logon/Logoff 
  Logon                                   No Auditing 
  Logoff                                  No Auditing 
  Account Lockout                         No Auditing 
  IPsec Main Mode                         No Auditing 
  IPsec Quick Mode                        No Auditing 
  IPsec Extended Mode                     No Auditing 
  Special Logon                           No Auditing  
  Other Logon/Logoff Events               No Auditing 
  Network Policy Server                   No Auditing 
  User / Device Claims                    No Auditing 
  Group Membership                        No Auditing 
Object Access 
  File System                             No Auditing 
  Registry                                No Auditing 
  Kernel Object                           No Auditing 
  SAM                                     No Auditing 
  Certification Services                  No Auditing 
  Application Generated                   No Auditing 
  Handle Manipulation                     No Auditing 
  File Share                              No Auditing 
  Filtering Platform Packet Drop          No Auditing 
  Filtering Platform Connection           No Auditing 
  Other Object Access Events              No Auditing 
  Detailed File Share                     No Auditing 
  Removable Storage                       No Auditing 
  Central Policy Staging                  No Auditing 
Privilege Use 
  Non Sensitive Privilege Use             No Auditing 
  Other Privilege Use Events              No Auditing 
  Sensitive Privilege Use                 No Auditing 
Detailed Tracking 
  Process Creation                        No Auditing 
  Process Termination                     No Auditing 
  DPAPI Activity                          No Auditing 
  RPC Events                              No Auditing 
  Plug and Play Events                    No Auditing 
  Token Right Adjusted Events             No Auditing 
Policy Change 
  Audit Policy Change                     No Auditing 
  Authentication Policy Change            No Auditing 
  Authorization Policy Change             No Auditing 
  MPSSVC Rule-Level Policy Change         No Auditing 
  Filtering Platform Policy Change        No Auditing 
  Other Policy Change Events              No Auditing 
Account Management 
  Computer Account Management             No Auditing 
  Security Group Management               No Auditing 
  Distribution Group Management           No Auditing 
  Application Group Management            No Auditing 
  Other Account Management Events         No Auditing 
  User Account Management                 No Auditing 
DS Access 
  Directory Service Access                No Auditing 
  Directory Service Changes               No Auditing 
  Directory Service Replication           No Auditing 
  Detailed Directory Service Replication  No Auditing 
Account Logon 
  Kerberos Service Ticket Operations      No Auditing 
  Other Account Logon Events              No Auditing 
  Kerberos Authentication Service         No Auditing 
  Credential Validation                   No Auditing
  ```
Identified subcategories not configured according to the desired baseline.


### **2. Intune Policy Creation**

Created a new Intune device configuration profile with updated audit settings.

Enabled Success/Failure for all required subcategories.

Creation is under `Home` > `Devices` > `Configuration` > ***Your settings catalog policy name*** > `Add settings` > `Auditing` 


## **Verification Commands**

```
auditpol /get /category:*
auditpol /get /subcategory:"<Name>"
```

