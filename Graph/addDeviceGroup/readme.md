# Overview
This folder contains collection of scripts to add devices to a group via different criteria.

### addDeviceObject.ps1
- Simple script to add a device to a group based on the Entra Object id. Used this to build out my logic for further iterations.
- input: `DeviceID`


### addDevicesObjectCSV.ps1
- Takes in a csv of Entra Device Object ids to add them to a group. 
input: CSV of `DeviceIds` with column DeviceID


### addDeviceDisplayName.ps1
- This script used the device host name to attempt to add it to a group..
- input: `Device Display Name`
- Usage: Change the `$DisplayName` and `$GroupId` values 

### addDevicesDisplayNameCSV.ps1
- Takes in a csv of device host names to attempt to add them to a group. 
input: CSV of Device HostNames