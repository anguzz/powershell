# Overview

This collection of scripts demonstrates the progressive use of the Microsoft Graph API to query device ownership information. These scripts are essential for identifying the owners of devices based on the device name, which is particularly useful when processing large sets of device data.


- V1 (Get Device Owner): This initial script outlines the basic method to retrieve the device owner using device ID, providing a straightforward way to establish device-user associations.

- V2 (Query by Display Name): Enhancing functionality, this version allows querying the owner based on the device's display name. This is particularly useful when device IDs are not readily available but display names are known.

- V3 (Bulk Processing via CSV): The most advanced version, this script iterates through a CSV file containing device names, appending a new column with the owners' information to the original file. This version is tailored for bulk processing, ideal for scenarios where mass communication is required, such as updating a large user group about upcoming OS updates due to their devices reaching end-of-support.


# Use case
My current use case involves gathering device ownership details from a large export of devices. This device list export identifies devices that are reaching end-of-life support on their current operating system builds for our EDR. These devices current OS build will be updated to the newest version, It is necessary to gather a large number of primary user emails for each device to send a business notification to the affected users. 