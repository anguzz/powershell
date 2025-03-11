# Overview
Collection of powershell graph api scripts to get Devices by different criteria

- `GetDevicesByValue.ps1` gets a device by any of the values in its json body response 
- `GetWindowsDevices.ps1` will give you all windows devices in your tenant and puts them in a csv file
- `GetDeviceByDeviceID.ps1` is used to get a device by its Intune (MDM) device ID 




# Json response in GetDevicesByValue.ps1
  ```json
"value": [
        {
            "id": "",
            "userId": "",
            "deviceName": "",
            "managedDeviceOwnerType": "",
            "enrolledDateTime": "",
            "lastSyncDateTime": "",
            "operatingSystem": "",
            "complianceState": "",
            "jailBroken": "",
            "managementAgent": "",
            "osVersion": "",
            "easActivated": ,
            "easDeviceId": "",
            "easActivationDateTime": "",
            "azureADRegistered": true,
            "deviceEnrollmentType": "",
            "activationLockBypassCode": null,
            "emailAddress": "",
            "azureADDeviceId": "",
            "deviceRegistrationState": "registered",
            "deviceCategoryDisplayName": "Unknown",
            "isSupervised": false,
            "exchangeLastSuccessfulSyncDateTime": "",
            "exchangeAccessState": "none",
            "exchangeAccessStateReason": "none",
            "remoteAssistanceSessionUrl": null,
            "remoteAssistanceSessionErrorDetails": null,
            "isEncrypted": true,
            "userPrincipalName": "",
            "model": "",
            "manufacturer": "",
            "imei": "",
            "complianceGracePeriodExpirationDateTime": "",
            "serialNumber": "XXXXXX",
            "phoneNumber": "",
            "androidSecurityPatchLevel": "",
            "userDisplayName": "",
            "configurationManagerClientEnabledFeatures": null,
            "wiFiMacAddress": "",
            "deviceHealthAttestationState": null,
            "subscriberCarrier": "",
            "meid": "",
            "totalStorageSpaceInBytes": ,
            "freeStorageSpaceInBytes": ,
            "managedDeviceName": "",
            "partnerReportedThreatState": "unknown",
            "requireUserEnrollmentApproval": null,
            "managementCertificateExpirationDate": "",
            "iccid": null,
            "udid": null,
            "notes": null,
            "ethernetMacAddress": null,
            "physicalMemoryInBytes": 0,
            "enrollmentProfileName": null,
            "deviceActionResults": []
        }
    ]
}
```
