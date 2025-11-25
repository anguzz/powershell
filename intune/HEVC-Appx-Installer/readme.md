# HEVC Manual Package Bundle

Microsoft provides a free HEIF Image Extension that enables Windows to read/write to `.HEIC` photo files (used by iPhones). 

- Link: https://apps.microsoft.com/detail/9pmmsr1cgpwg?hl=en-US&gl=US#activetab=pivot:overviewtab

However, the HEVC codec required for `.H265` / `.HEVC` video playback is a **paid Microsoft product**.

For testing and research, it is possible to obtain the publicly listed **HEVC Video Extensions** `.appxbundle` using the following:

1. Go to: https://store.rg-adguard.net/
2. Enter Product ID: `9N4WGH0Z6VHQ`
3. Download:  
   **`Microsoft.HEVCVideoExtension_2.4.39.0_neutral_~_8wekyb3d8bbwe.appxbundle`**
4. Install manually to validate how Windows handles the package when no license entitlement exists.

This can help with proof-of-concept testing (e.g., seeing how Windows reacts, license prompts, behavior across profiles, etc.).

## Disclaimer

This HEVC codec is a licensed Microsoft product.

Distributing, deploying, or enabling the paid HEVC codec in a production environment without proper licensing violates Microsoft’s Terms of Service.

This documentation and the included PowerShell scripts are strictly for testing, research, and analysis validation.

Confirmed functional as of 11/25/2025 for local + intune deployment. 

## References

- https://www.thewindowsclub.com/view-heic-hevc-files-windows-photos-app  
- https://www.howtogeek.com/680690/how-to-install-free-hevc-codecs-on-windows-10-for-h265-video/

## Intune deployment
install: `powershell -ex bypass -file install.ps1`
uninstall: `powershell -ex bypass -file uninstall.ps1`
detection: upload `detection.ps1`
Context: System