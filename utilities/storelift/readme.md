# StoreLift

One PowerShell WPF script that helps download and install Microsoft Store AppX/MSIX packages when the Microsoft Store is blocked, unavailable, or restricted.

StoreLift started from the same general idea as my HEVC AppX installer:

- https://github.com/anguzz/powershell/tree/main/intune/HEVC-Appx-Installer

It was also inspired by this repo:

- https://github.com/schrebra/Microsoft.Store.Appx.Downloader

That repo had a good concept: take a Microsoft Store app URL, resolve the package links, and download the package locally.

StoreLift takes that idea further by combining it with my previous AppX installer workflow. Instead of manually finding and pasting a Store URL or ProductId every time, StoreLift can use `winget` to search Microsoft Store results by keyword, resolve the Store ProductId, preview package files, download the app with dependencies, and optionally install it for the current user.

The main goal is to keep this as a reusable one-file utility for myself and others, rather than a one-off installer for a single app.

<img width="1153" height="817" alt="image" src="https://github.com/user-attachments/assets/e8e985d5-c07f-474b-ba65-0749adb38cd9" />

<img width="330" height="116" alt="image" src="https://github.com/user-attachments/assets/7d4af865-14e6-4de7-b812-a78800ca493b" />

## Basic Flow

1. Search for an app, for example `paint`
2. Select the Store result
3. Preview the app package and dependencies
4. Click **Download App + Dependencies**
5. Optional: click **Install Current User**
6. Use **Open Folder** to view downloaded files or Search the Windows taskbar/start menu to find the installed app


## What It Does

StoreLift provides a simple GUI for:

* Searching Microsoft Store apps
* Resolving Store ProductIds and package links
* Downloading AppX/MSIX packages and dependencies
* Verifying SHA256 hashes
* Checking Authenticode signatures
* Installing downloaded packages for the current user
* Supporting manual ProductId or Store URL fallback

Current user install is used so the tool can usually run without local admin permissions.




## Important Notes

* Downloads dependencies, not just the main package.
* AppX/MSIX packages are not mounted.
* Installation uses `Add-AppxPackage`.
* Manual ProductId or Microsoft Store URL fallback is supported.
* SHA256 and Authenticode signature checks are shown after download.
* The script is intentionally kept as one `.ps1` file. 

## Troubleshooting

If a download gets stuck or leaves a `BIT*.tmp` file behind, restart BITS. `Restart-Service BITS -Force` (Requires admin)


## References

* [https://github.com/anguzz/powershell/tree/main/intune/HEVC-Appx-Installer](https://github.com/anguzz/powershell/tree/main/intune/HEVC-Appx-Installer)
* [https://github.com/schrebra/Microsoft.Store.Appx.Downloader](https://github.com/schrebra/Microsoft.Store.Appx.Downloader)
* [https://store.rg-adguard.net/](https://store.rg-adguard.net/)

## Winget Search

StoreLift uses `winget` to search the Microsoft Store source after that the script parses the search results, extracts the Store ProductId, and builds the Store URL automatically.

Instead of using `winget install`, StoreLift downloads the AppX/MSIX package files directly, verifies them, and installs them locally using `Add-AppxPackage`. 

This is useful for testing, troubleshooting, offline installs, restricted Store environments, or cases where you want to inspect the package files before installing them.


## Winget install vs StoreLift


| Use case                                  |                                                Winget install |                  StoreLift |
| ----------------------------------------- | ------------------------------------------------------------: | -------------------------: |
| Normal Store app install                  |                                                        Quicker |     Works, but extra steps |
| See actual AppX/MSIX files before install |                                                            No |                        Yes |
| Download package files locally            |                                                    Not really |                        Yes |
| Inspect hashes/signatures                 |                                                            No |                        Yes |
| Save packages for later/manual testing/repackaging    |                                                            No |                        Yes |
| Install from local folder                 |                                                            No |                        Yes |
| Learn/debug Store package dependencies    |                                                       Limited |                        Yes |
| Avoid Store UI when blocked               |                                                Yes, sometimes |             Yes, sometimes |
| Enterprise production deployment          | Better through Intune/Company Portal/winget/Store integration | More of a utility/lab tool |


