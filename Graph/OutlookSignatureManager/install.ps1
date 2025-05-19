
$ColorInfo    = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError   = "Red"
$ColorSection = "Magenta"
$ColorDebug   = "Gray" 


Function Write-ColoredHost {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White",

        [Parameter(Mandatory=$false)]
        [string]$BackgroundColor = "Black" 
    )
    Write-Host $Message -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
}

if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    try {
        Write-ColoredHost "Attempting to relaunch in 64-bit PowerShell..." -ForegroundColor $ColorInfo
        if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") {
            & "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCommandPath
            exit $LASTEXITCODE
        } else {
            Write-ColoredHost "Already running in 64-bit PowerShell." -ForegroundColor $ColorInfo
        }
    }
    catch {
        Write-Error "Failed to start $PSCommandPath in 64-bit PowerShell. Error: $($_.Exception.Message)" 
        throw "Failed to start $PSCommandPath in 64-bit PowerShell."
    }
}

$logFilePath = "$($env:TEMP)\IntuneSignatureManagerForOutlook-Graph-log.txt"
Start-Transcript -Path $logFilePath -Force
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "SCRIPT STARTED: Outlook Signature Manager Installation" -ForegroundColor $ColorSection
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "Logging to $logFilePath" -ForegroundColor $ColorInfo
Write-ColoredHost "Current Date/Time: $(Get-Date)" -ForegroundColor $ColorInfo
Write-ColoredHost "Running as user: $(whoami)" -ForegroundColor $ColorInfo
Write-ColoredHost "PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor $ColorInfo
Write-ColoredHost "PowerShell Bitness: $(if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {'64-bit'} else {'32-bit'})" -ForegroundColor $ColorInfo
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-Host "" 

Write-ColoredHost "[NuGet Package Provider Check]" -ForegroundColor $ColorSection
try {
    Write-ColoredHost "Checking NuGet Package Provider..." -ForegroundColor $ColorInfo
    $nuGetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if (-not $nuGetProvider -or ($nuGetProvider.Version -lt [System.Version]'2.8.5.201')) {
        Write-ColoredHost "Installing/Updating NuGet Package Provider (version 2.8.5.201 or newer)..." -ForegroundColor $ColorWarning
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force -ErrorAction Stop
        Write-ColoredHost "NuGet Package Provider installed/updated successfully." -ForegroundColor $ColorSuccess
    } else {
        Write-ColoredHost "NuGet Package Provider is up to date (Version: $($nuGetProvider.Version))." -ForegroundColor $ColorSuccess
    }
}
catch {
    Write-Warning "Failed to install/update NuGet Package Provider. This might not be an issue on newer PowerShell versions. Error: $($_.Exception.Message)"
}
Write-Host "" 

Write-ColoredHost "[Microsoft Graph Module Installation]" -ForegroundColor $ColorSection
$requiredGraphModules = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users")
try {
    Write-ColoredHost "Checking required Microsoft Graph modules: $($requiredGraphModules -join ', ')" -ForegroundColor $ColorInfo
    $installedModules = Get-Module -ListAvailable
    foreach ($moduleName in $requiredGraphModules) {
        if (-not ($installedModules.Name -contains $moduleName)) {
            Write-ColoredHost "Installing $moduleName module..." -ForegroundColor $ColorWarning
            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-ColoredHost "$moduleName module installed successfully." -ForegroundColor $ColorSuccess
        } else {
            $installedVersion = ($installedModules | Where-Object Name -eq $moduleName | Select-Object -First 1).Version
            Write-ColoredHost "$moduleName module already installed (Version: $installedVersion)." -ForegroundColor $ColorSuccess
        }
    }
    Write-ColoredHost "Importing Microsoft Graph modules..." -ForegroundColor $ColorInfo
    Import-Module Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
    Import-Module Microsoft.Graph.Users -ErrorAction SilentlyContinue
    Write-ColoredHost "Microsoft Graph modules imported." -ForegroundColor $ColorSuccess
}
catch {
    Write-Error "Failed to install/import required Microsoft Graph modules. Error: $($_.Exception.Message)"
    Stop-Transcript
    exit 1
}
Write-Host ""

Write-ColoredHost "[Microsoft Graph Connection & User Data Retrieval]" -ForegroundColor $ColorSection
$userProperties = @(
    "displayName", "givenName", "surname", "mail", "userPrincipalName",
    "mobilePhone", "businessPhones", "jobTitle", "department", "city",
    "state", "streetAddress", "postalCode", "country", "officeLocation"
)

$mgUser = $null
$userAttributes = $null

try {
    Write-ColoredHost "Attempting to connect to Microsoft Graph..." -ForegroundColor $ColorInfo
 

    $tenantID = "" 
    $clientID = "" 
    $clientSecretValue = "" 


    $secureSecret = ConvertTo-SecureString $clientSecretValue -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($clientID, $secureSecret)

    Write-ColoredHost "Connecting with Tenant ID: $tenantID and Client ID: $clientID" -ForegroundColor $ColorInfo
    Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credential -NoWelcome 
    Write-ColoredHost "Successfully connected to Microsoft Graph." -ForegroundColor $ColorSuccess

    Write-ColoredHost "Retrieving current logged-in user's username..." -ForegroundColor $ColorInfo
    $explorerProcess = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($explorerProcess) {
        $ownerInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwner -ErrorAction SilentlyContinue
        $currUser = $ownerInfo.User
    } else {
        Write-Warning "Could not determine the logged-in user via explorer.exe. This might affect user identification for Graph."
        $currUser = $env:USERNAME
    }
    
    $domainExtension  = "@email.com"  # add your domain extension here 
    Write-ColoredHost "Configured domain extension: $domainExtension (Ensure this is correct!)" -ForegroundColor $ColorWarning

    $userToCheck = "$currUser$domainExtension"
    Write-ColoredHost "Attempting to retrieve Graph data for user: $userToCheck" -ForegroundColor $ColorInfo
    
    $mgUser = Get-MgUser -UserId $userToCheck -Property $userProperties -ErrorAction Stop
    
    if ($mgUser) {
        Write-ColoredHost "Successfully retrieved user object for '$($mgUser.DisplayName)' (UPN: $($mgUser.UserPrincipalName))" -ForegroundColor $ColorSuccess
        $userAttributes = [PSCustomObject]@{
            DisplayName              = $mgUser.DisplayName
            GivenName                = $mgUser.GivenName
            Surname                  = $mgUser.Surname
            Mail                     = if ([string]::IsNullOrWhiteSpace($mgUser.Mail)) { $mgUser.UserPrincipalName } else { $mgUser.Mail }
            Mobile                   = $mgUser.MobilePhone
            TelephoneNumber          = if ($mgUser.BusinessPhones -and $mgUser.BusinessPhones.Count -gt 0) { $mgUser.BusinessPhones[0] } else { "" }
            JobTitle                 = $mgUser.JobTitle
            Department               = $mgUser.Department
            City                     = $mgUser.City
            Country                  = $mgUser.Country
            StreetAddress            = $mgUser.StreetAddress
            PostalCode               = $mgUser.PostalCode
            State                    = $mgUser.State
            PhysicalDeliveryOfficeName = $mgUser.OfficeLocation
        }
        Write-ColoredHost "User attributes populated." -ForegroundColor $ColorSuccess
    } else {
        throw "Could not retrieve user information for '$userToCheck'."
    }
}
catch {
    Write-Error "Error during Microsoft Graph connection or user retrieval: $($_.Exception.Message)"
    Write-Error "Script will terminate. Please ensure the user context is correct, Azure AD credentials/permissions are valid, and Graph modules are functioning."
    Stop-Transcript
    exit 1
}
Write-Host ""

Write-ColoredHost "[Outlook Signature Processing]" -ForegroundColor $ColorSection
if (-not $userAttributes) {
    Write-Error "User attributes not populated from Graph. Cannot proceed with signature creation."
    Stop-Transcript
    exit 1
}

$signaturesPath = "C:\Users\$currUser\AppData\Roaming\Microsoft\Signatures\"
Write-ColoredHost "Target Outlook Signatures folder: $signaturesPath" -ForegroundColor $ColorInfo
if (-not (Test-Path $signaturesPath)) {
    try {
        Write-ColoredHost "Creating signatures folder: $signaturesPath" -ForegroundColor $ColorWarning
        $null = New-Item -Path $signaturesPath -ItemType Directory -ErrorAction Stop
        Write-ColoredHost "Successfully created signatures folder." -ForegroundColor $ColorSuccess
    }
    catch {
        Write-Error "Failed to create signatures folder at $signaturesPath. Error: $($_.Exception.Message)"
        Stop-Transcript
        exit 1
    }
} else {
    Write-ColoredHost "Signatures folder already exists." -ForegroundColor $ColorSuccess
}

$scriptRootSignaturesPath = Join-Path -Path $PSScriptRoot -ChildPath "Signatures" 
Write-ColoredHost "Signatures source template path: $scriptRootSignaturesPath" -ForegroundColor $ColorInfo
if (-not (Test-Path $scriptRootSignaturesPath)) {
    Write-Error "Signatures source folder not found at '$scriptRootSignaturesPath'. Ensure it exists and contains your signature templates and assets."
    Stop-Transcript
    exit 1
}

$signatureFilesAndFolders = Get-ChildItem -Path $scriptRootSignaturesPath -ErrorAction SilentlyContinue

if (-not $signatureFilesAndFolders) {
    Write-Warning "No files or folders found in '$scriptRootSignaturesPath'. No signatures will be processed."
} else {
    Write-ColoredHost "Processing signature templates and assets from '$scriptRootSignaturesPath'..." -ForegroundColor $ColorInfo
}
Write-Host ""

Function Get-SafeAttributeString {
    param($AttributeValue)
    if ($null -eq $AttributeValue -or ([string]::IsNullOrWhiteSpace($AttributeValue.ToString()))) { return "" }
    return ($AttributeValue | Out-String).Trim()
}

foreach ($item in $signatureFilesAndFolders) {
    $itemName = $item.Name
    $itemFullName = $item.FullName
    
    if ($item.PSIsContainer) { 
        Write-ColoredHost "Processing asset directory: '$itemName'" -ForegroundColor $ColorInfo
        $destinationDir = Join-Path -Path $signaturesPath -ChildPath $itemName
        try {
            Write-ColoredHost "Copying directory '$itemFullName' to '$destinationDir'..." -ForegroundColor $ColorDebug
            Copy-Item -Path $itemFullName -Destination $destinationDir -Recurse -Force -ErrorAction Stop
            Write-ColoredHost "Successfully copied directory '$itemName' to '$destinationDir'." -ForegroundColor $ColorSuccess
        }
        catch {
            Write-Error "Failed to copy directory '$itemFullName' to '$destinationDir'. Error: $($_.Exception.Message)"
        }
    }
    elseif ($item.Name -like "*.htm" -or $item.Name -like "*.rtf" -or $item.Name -like "*.txt") {
        Write-ColoredHost "Processing template file: '$itemName'" -ForegroundColor $ColorInfo
        try {
            $signatureFileContent = Get-Content -Path $itemFullName -Raw -ErrorAction Stop
            
            Write-ColoredHost "  Replacing placeholders in '$itemName'..." -ForegroundColor $ColorDebug
            $signatureFileContent = $signatureFileContent -replace "%DisplayName%", (Get-SafeAttributeString $userAttributes.DisplayName)
            $signatureFileContent = $signatureFileContent -replace "%GivenName%", (Get-SafeAttributeString $userAttributes.GivenName)
            $signatureFileContent = $signatureFileContent -replace "%Surname%", (Get-SafeAttributeString $userAttributes.Surname)
            $signatureFileContent = $signatureFileContent -replace "%Mail%", (Get-SafeAttributeString $userAttributes.Mail)
            $signatureFileContent = $signatureFileContent -replace "%Mobile%", (Get-SafeAttributeString $userAttributes.Mobile)
            $signatureFileContent = $signatureFileContent -replace "%TelephoneNumber%", (Get-SafeAttributeString $userAttributes.TelephoneNumber)
            $signatureFileContent = $signatureFileContent -replace "%JobTitle%", (Get-SafeAttributeString $userAttributes.JobTitle)
            $signatureFileContent = $signatureFileContent -replace "%Department%", (Get-SafeAttributeString $userAttributes.Department)
            $signatureFileContent = $signatureFileContent -replace "%City%", (Get-SafeAttributeString $userAttributes.City)
            $signatureFileContent = $signatureFileContent -replace "%Country%", (Get-SafeAttributeString $userAttributes.Country)
            $signatureFileContent = $signatureFileContent -replace "%StreetAddress%", (Get-SafeAttributeString $userAttributes.StreetAddress)
            $signatureFileContent = $signatureFileContent -replace "%PostalCode%", (Get-SafeAttributeString $userAttributes.PostalCode)
            $signatureFileContent = $signatureFileContent -replace "%State%", (Get-SafeAttributeString $userAttributes.State)
            $signatureFileContent = $signatureFileContent -replace "%PhysicalDeliveryOfficeName%", (Get-SafeAttributeString $userAttributes.PhysicalDeliveryOfficeName)

            $destinationPath = Join-Path -Path $signaturesPath -ChildPath $itemName
            Write-ColoredHost "  Saving updated signature to: '$destinationPath'" -ForegroundColor $ColorDebug
            Set-Content -Path $destinationPath -Value $signatureFileContent -Force -Encoding UTF8 -ErrorAction Stop 
            Write-ColoredHost "Successfully updated and saved signature file: '$destinationPath'" -ForegroundColor $ColorSuccess
        }
        catch {
            Write-Error "Failed to process or write signature file '$itemFullName'. Error: $($_.Exception.Message)"
        }
    } else {
        Write-ColoredHost "Skipping non-template/non-asset file: '$itemName'" -ForegroundColor $ColorDebug
    }
    Write-Host "" 
}
Write-Host ""
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "SCRIPT FINISHED: Outlook Signature Manager Installation" -ForegroundColor $ColorSection
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Stop-Transcript
