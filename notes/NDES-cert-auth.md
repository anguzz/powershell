Here’s your notes rewritten to be **simpler, linear, and easier to scan**, with fewer sections and only `-` bullets, while keeping your diagrams unchanged.


# NDES + Intune Certificate Connector – Quick Notes

## Purpose (what this stack actually does)

* Issues **device certificates only**
* Used for **EAP-TLS auth (Wi-Fi / VPN / 802.1X)**
* No cert = no authentication
* RADIUS does not create certs
* RADIUS only validates existing certs

Core rule:

* issuance happens first
* validation happens second

If issuance fails, authentication will always fail


## Simple flow (mental model)

```
Device
 → Intune policy
 → Certificate Connector
 → NDES (SCEP)
 → AD CS (CA signs cert)
 → Cert installed on device
 → Device authenticates to NPS
```

* every hop is required
* any break = no cert


## What each piece really does

* Intune → tells device to request cert
* Connector → broker between cloud and NDES
* NDES → SCEP web service
* AD CS → signs/creates cert
* NPS/RADIUS → validates cert at login

Remember:

* NDES issues
* NPS verifies

Separate systems


## Troubleshooting order

When EAP-TLS breaks:

* first question: does the device have a valid cert?

If no:

* problem is issuance side

If yes:

* problem is NPS/RADIUS side

Always check issuance first

Because:

* no cert = guaranteed failure


## Common issuance failures (look like Wi-Fi issues)

These all stop cert creation:

* event logs full
* connector service stopped
* IIS app pool stopped
* connector cert expired
* NDES RA cert expired
* CA unreachable
* bad template permissions
* CRL unreachable

All of these present as:

* “Wi-Fi broken”
* “auth failing”
* but are not network problems


## Event log exhaustion (real failure I hit)

Behavior:

* NDES + Connector constantly write logs
* if logs cannot write → requests fail

If logs set to:

* Do not overwrite

And become full:

* issuance fails silently
* renewals fail
* devices lose Wi-Fi
* looks like RADIUS issue
* actually backend logging failure

Symptoms:

* cert renewals failing
* Wi-Fi auth failing
* no clear NPS errors
* SCEP seems random

Fix:

* clear logs
* set Overwrite as needed
* increase log size
* restart services

Issuance resumes immediately

Lesson:

* issuance failure, not authentication failure


## Logs I watch first

Connector:

* 20100 → success
* 20102 → failure

NDES:

* 4000–4008 → request flow

Service:

* 10010 / 10020 → start/stop

If 20100 stops → issuance is broken


## Personal rule

* do not chase RADIUS first
* confirm device has a valid cert first
* most cert-auth Wi-Fi issues are upstream issuance problems


## Diagram (unchanged)

```
                           CLOUD (Microsoft)

                   ┌─────────────────────────────────┐
                   │     Microsoft Intune Service     │
                   │  Policy + SCEP Certificate Mgmt  │
                   │  *.manage.microsoft.com          │
                   └──────────────┬──────────────────┘
                                  │
                                  │ HTTPS 443
                                  ▼

────────────────────────────────────────────────────────────
                   Corporate Firewall / Security Edge
────────────────────────────────────────────────────────────

                                  │
                                  │ HTTPS 443
                                  ▼

                 ┌────────────────────────────────┐
                 │ Intune Certificate Connector   │
                 │ (on NDES server)               │
                 │ SCEP broker service            │
                 └──────────────┬─────────────────┘
                                │
                                │ Local HTTP / RPC
                                ▼
                 ┌────────────────────────────────┐
                 │ NDES (SCEP Endpoint)           │
                 │ /certsrv/mscep                 │
                 └──────────────┬─────────────────┘
                                │
                                │ RPC / DCOM
                                ▼
                 ┌────────────────────────────────┐
                 │ AD CS Certificate Authority    │
                 │ Issues device certificates     │
                 └────────────────────────────────┘


============================================================
                DEVICE CERTIFICATE INSTALLED
============================================================

                       INTERNAL NETWORK

┌───────────────┐
│   Endpoints   │
│  (User Device)│
│  Has cert     │
└───────┬───────┘
        │  802.1X / EAP-TLS
        ▼
┌────────────────────┐
│ Wireless AP / WLC  │
└─────────┬──────────┘
          │ RADIUS 1812
          ▼
┌────────────────────┐
│ NPS (RADIUS)       │
│ Cert validation    │
└─────────┬──────────┘
          │ Chain / CRL check
          ▼
┌────────────────────┐
│ AD CS (Trusted CA) │
└────────────────────┘
```


Refernce image:  from https://learn.microsoft.com/en-us/troubleshoot/mem/intune/certificates/troubleshoot-scep-certificate-profiles? 

![alt text](https://learn.microsoft.com/en-us/troubleshoot/mem/intune/certificates/media/troubleshoot-scep-certificate-profiles/scep-certificate-profile-flow.png)