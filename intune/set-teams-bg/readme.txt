
--------------------
Package info
--------------------
This package allows you to deploy possible background images to users machines via intune. This may be similar to a setting in teams admin center 
where you can add company backgrounds. This is more of a manual approach that can be used to have backgrounds be avaialable as available applications
on the company portal or silently be pushed out to user groups. 


--------------------
Background
--------------------
Images seem to  have a naming convention that allows images to be read on teams. (tested this by renaming them, making them not visible on teams backgrounds)

The best course of action is to upload the image you want on teams to allow teams to apply the naming convention and pixel formatting.

Teams will generate two files, similar to this naming convention, 7c03394b-1ec0-4b9f-a40a-ab74e32ae822.png, and 7c03394b-1ec0-4b9f-a40a-ab74e32ae822_thumb.png

The uninstall PowerShell script that references the bg_images folder to obtain the names of the images
and then removes these images from the specific Teams background folder for the current user


--------------------
Instructions
--------------------
1. Upload the images via teams on the under more video effects -> add new background

2. After this go to C:\Users\%user%\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads 
 
3. Add the teams uploaded images here in the bg_images folder.

4. Run your Intune Win App Util tool on the setBackground.ps1 and upload to intune, it should be deployed as a user installation 


-------------------------
Deployment rules
-------------------------
powershell -ex bypass -file -windowstyle hidden -setBackground.ps1

powershell -ex bypass -file -windowstyle hidden -uninstall.ps1


-------------------------
Detection rules 
-------------------------
File 
C:\Users\%username%\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads
7c03394b-1ec0-4b9f-a40a-ab74e32ae822.png