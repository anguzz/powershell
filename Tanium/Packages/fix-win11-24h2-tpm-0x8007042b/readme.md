in place upgrade failures 23h2 to 24h2 - tanium


# targetting info

```sql
Get Computer Name and Operating System and Deploy - Deployments?maxAge=60 matches "^252\|.*\|Not Applicable(\|.*)?$" and Operating System Build Number?maxAge=900 from all machines with Deploy - Deployments matches "^252\|.*\|Not Applicable(\|.*)?$"
```

- tags
deploying Custom Tag
FBM-UpdateDetectionNotMet


# Issue 1: Software package is Installed instead of Update Eligible
two problems, 
1) fix the OS migration issue 0x8007042b in staging
2) overwrite registry for OSD status to ensure update eligible status 

- panther logs can be pulled in a tanium export, its just a copy form C:\windows\panther folder
C:\Users\Angel.Santoyo\Downloads\emg-fbm_f1ltks{date}\software_manager\software-management-logs\{object_id}\WinIPU\Panther
- setuperr.log will gave us this 
- panther logs copied from C:\windows\panther folder


1) OS 0x8007042b  


```log
2026-02-10 14:23:55, Error                 SP     Operation failed: Offline portion of machine-specific and machine-independent apply operations. Error: 0x8007042B[gle=0x000000b7]
2026-02-10 14:23:55, Error                 SP     Cannot revert execution of operation 100 (Add boot entry for C:\$WINDOWS.~BT\NewOS\WINDOWS. Locale = en-US). Execution queue is now compromised.[gle=0x00000002]
```


- more then likely have to automote the fix according to this. could be any of these fixes. 

https://www.reddit.com/user/Zhlkk/

https://learn.microsoft.com/en-us/answers/questions/5649780/windows-11-education-23h2-to-25h2-upgrade-fails-tp

https://windowsreport.com/windows-10-update-error-0x8007042b-fix/

https://www.yourwindowsguide.com/2025/12/25h2-repair-install-failed.html

https://www.thewindowsclub.com/fix-windows-10-update-error-0x8007042b


1) gotta restage the update,
 currently the compat scan registry is set to in progress
 this makes it so in progress does not allow it apply updates.
 even after this is done though it will fail due to the problems below

-  `registry set value` package 
"HKEY_LOCAL_MACHINE\Software\WOW6432Node\Tanium\Tanium Client\OSD\Status"
set to 
"Compat Scan OK" 

- update in progress will be overwritten so it can say "update eligble again" 

- this will just make it so we can re-stage and make the update go through.
- delete, will show us update eligible again.



# issue 2: - Software package is not appicable (update detection not met)
re-run phase 1
since no scan data ()

deploying Custom Tag
FBM-UpdateDetectionNotMet
 
redeploy 24H2 Phase1 upgrade to these devices after Deploy- 'Windows Upgrade Cleanup'
 
Get Computer Name and Operating System and Deploy - Deployments?maxAge=60 matches "^252\|.*\|Not Applicable(\|.*)?$" and Operating System Build Number?maxAge=900 from all machines with Deploy - Deployments matches "^252\|.*\|Not Applicable(\|.*)?$"
 
 
 

# issue 3: system requirements not met
- upgrade machine 
- only 4



