# Install-OutlookSignatureManager

$ColorInfo = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"
$ColorSection = "Magenta"
$ColorDebug = "Gray"

Function Write-ColoredHost {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White",

        [Parameter(Mandatory = $false)]
        [string]$BackgroundColor = "Black"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
}

# Ensure the script runs in 64-bit PowerShell if applicable
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

# Start logging
$logFilePath = "C:\Temp\OutlookSignatureLog.txt"
try {
    Start-Transcript -Path $logFilePath 
}
catch {
    Write-ColoredHost "Error starting transcript. Logging to console only. Error: $($_.Exception.Message)" -ForegroundColor $ColorError
}

Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "SCRIPT STARTED: Outlook Signature Manager Installation" -ForegroundColor $ColorSection
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "Logging to $logFilePath (if transcript started successfully)" -ForegroundColor $ColorInfo
Write-ColoredHost "Current Date/Time: $(Get-Date)" -ForegroundColor $ColorInfo
Write-ColoredHost "Running as user: $(whoami)" -ForegroundColor $ColorInfo
Write-ColoredHost "PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor $ColorInfo
Write-ColoredHost "PowerShell Bitness: $(if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {'64-bit'} else {'32-bit'})" -ForegroundColor $ColorInfo
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-Host "" 

# --- NuGet Package Provider Check ---
Write-ColoredHost "[NuGet Package Provider Check]" -ForegroundColor $ColorSection
try {
    Write-ColoredHost "Checking/Installing/Updating NuGet Package Provider..." -ForegroundColor $ColorInfo
    Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue | Out-Null # Check if it exists
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force -ErrorAction Stop
    Write-ColoredHost "NuGet Package Provider is available and up-to-date." -ForegroundColor $ColorSuccess
}
catch {
    Write-Warning "NuGet Package Provider installation/update failed: $($_.Exception.Message). This might affect module installations."
}
Write-Host ""

# --- Microsoft Graph Module Installation ---
Write-ColoredHost "[Microsoft Graph Module Installation]" -ForegroundColor $ColorSection

$requiredGraphModules = @("Microsoft.Graph.Authentication")

try {
    Write-ColoredHost "Ensuring required Microsoft Graph modules are installed..." -ForegroundColor $ColorInfo
    foreach ($moduleName in $requiredGraphModules) {
        if (Get-Module -ListAvailable -Name $moduleName) {
            Write-ColoredHost "$moduleName is already available." -ForegroundColor $ColorInfo
        } else {
            Write-ColoredHost "Installing $moduleName..." -ForegroundColor $ColorWarning
            Install-Module -Name $moduleName -Scope AllUsers -Force -AllowClobber -ErrorAction Stop
            Write-ColoredHost "$moduleName installed successfully." -ForegroundColor $ColorSuccess
        }
    }
    Write-ColoredHost "Microsoft Graph modules are ready." -ForegroundColor $ColorSuccess
}
catch {
    Write-Error "Failed to ensure Microsoft Graph modules are installed. Error: $($_.Exception.Message)"
    if (Get-Transcript) { Stop-Transcript }
    exit 1
}
Write-Host "" 

Write-ColoredHost "[Microsoft Graph Connection & User Data Retrieval]" -ForegroundColor $ColorSection
$userProperties = @(
    "displayName", "givenName", "surname", "mail", "userPrincipalName",
    "mobilePhone", "businessPhones", "jobTitle", "department", "city",
    "state", "streetAddress", "postalCode", "country", "officeLocation"
)

$mgUserResponse = $null 
$userAttributes = $null

try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    Write-ColoredHost "Attempting to connect to Microsoft Graph..." -ForegroundColor $ColorInfo

    $tenantID = ""    
    $clientID = ""     
    $clientSecretValue = ""

    $secureSecret = ConvertTo-SecureString $clientSecretValue -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($clientID, $secureSecret)

    Write-ColoredHost "Connecting with Tenant ID: $tenantID and Client ID: $clientID" -ForegroundColor $ColorInfo
    # Check existing connection
    if (-not (Get-MgContext)) {
        Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credential -ErrorAction Stop
        Write-ColoredHost "Successfully connected to Microsoft Graph." -ForegroundColor $ColorSuccess
    } else {
        Write-ColoredHost "Already connected to Microsoft Graph as '$((Get-MgContext).Account)' on tenant '$((Get-MgContext).TenantId)'." -ForegroundColor $ColorInfo
    }


    Write-ColoredHost "Retrieving current logged-in user's username..." -ForegroundColor $ColorInfo
    $currUser = $null
    $explorerProcess = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($explorerProcess) {
        $ownerInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwner -ErrorAction SilentlyContinue
        if ($ownerInfo -and $ownerInfo.User) {
            $currUser = $ownerInfo.User
            Write-ColoredHost "Determined user from explorer.exe: $currUser" -ForegroundColor $ColorDebug
        }
    }
    
    if (-not $currUser) {
        Write-Warning "Could not determine logged-in user from explorer.exe owner. Falling back to \$env:USERNAME."
        $currUser = $env:USERNAME
        Write-ColoredHost "Using \$env:USERNAME: $currUser" -ForegroundColor $ColorDebug
    }

    if (-not $currUser) {
        throw "Could not determine the current user."
    }
    
     $domainExtension = "@email.com"

    Write-ColoredHost "Configured domain extension: $domainExtension (Ensure this is correct!)" -ForegroundColor $ColorWarning

    $userToCheck = "$currUser$domainExtension" 
    Write-ColoredHost "Attempting to retrieve Graph data for user: '$userToCheck'" -ForegroundColor $ColorInfo
    
    $selectQuery = $userProperties -join ','

    $uri = "https://graph.microsoft.com/v1.0/users/$($userToCheck)?`$select=$($selectQuery)"

    Write-ColoredHost "Graph API Request URI: $uri" -ForegroundColor $ColorDebug
    Write-ColoredHost "Attempting to retrieve user: $userToCheck with properties: $($userProperties -join ', ')" -ForegroundColor $ColorInfo
    
    $mgUserResponse = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
    
    if ($mgUserResponse) {
        Write-ColoredHost "Successfully retrieved user object for '$($mgUserResponse.DisplayName)' (UPN: $($mgUserResponse.UserPrincipalName))" -ForegroundColor $ColorSuccess
        $userAttributes = [PSCustomObject]@{
            DisplayName             = $mgUserResponse.DisplayName
            GivenName               = $mgUserResponse.GivenName
            Surname                 = $mgUserResponse.Surname
            Mail                    = if ([string]::IsNullOrWhiteSpace($mgUserResponse.Mail)) { $mgUserResponse.UserPrincipalName } else { $mgUserResponse.Mail }
            Mobile                  = $mgUserResponse.MobilePhone 
            TelephoneNumber         = if ($mgUserResponse.BusinessPhones -and $mgUserResponse.BusinessPhones.Count -gt 0) { $mgUserResponse.BusinessPhones[0] } else { "" }
            JobTitle                = $mgUserResponse.JobTitle
            Department              = $mgUserResponse.Department
            City                    = $mgUserResponse.City
            Country                 = $mgUserResponse.Country
            StreetAddress           = $mgUserResponse.StreetAddress
            PostalCode              = $mgUserResponse.PostalCode
            State                   = $mgUserResponse.State
            PhysicalDeliveryOfficeName = $mgUserResponse.OfficeLocation
        }
        Write-ColoredHost "User attributes populated." -ForegroundColor $ColorSuccess
  
    } else {
       
        throw "Could not retrieve user information for '$userToCheck'. Invoke-MgGraphRequest returned a null or empty response without throwing an error."
    }
}
catch {
    Write-Error "Error during Microsoft Graph connection or user retrieval: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $errorResponse = $_.Exception.Response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($errorResponse -and $errorResponse.error) {
            Write-Error "Graph API Error Code: $($errorResponse.error.code)"
            Write-Error "Graph API Error Message: $($errorResponse.error.message)"
        } else {
            Write-Error "Full Graph API Response (if available and not JSON): $($_.Exception.Response.Content)"
        }
    } elseif ($_.ErrorDetails) {
         Write-Error "Error Details: $($_.ErrorDetails.Message)"
    }
    Write-Error "Script will terminate. Please ensure the user context is correct, Azure AD credentials/permissions are valid, and Graph modules are functioning."
    if (Get-Transcript) { Stop-Transcript }
    exit 1
}
Write-Host ""

# --- Outlook Signature Processing ---
Write-ColoredHost "[Outlook Signature Processing]" -ForegroundColor $ColorSection
if (-not $userAttributes) {
    Write-Error "User attributes not populated from Graph. Cannot proceed with signature creation."
    if (Get-Transcript) { Stop-Transcript }
    exit 1
}

# Use the $currUser variable determined earlier for the path
$signaturesPath = "C:\Users\$currUser\AppData\Roaming\Microsoft\Signatures"
Write-ColoredHost "Target Outlook Signatures folder: $signaturesPath" -ForegroundColor $ColorInfo
if (-not (Test-Path $signaturesPath)) {
    try {
        Write-ColoredHost "Creating signatures folder: $signaturesPath" -ForegroundColor $ColorWarning
        $null = New-Item -Path $signaturesPath -ItemType Directory -Force -ErrorAction Stop # Added -Force
        Write-ColoredHost "Successfully created signatures folder." -ForegroundColor $ColorSuccess
    }
    catch {
        Write-Error "Failed to create signatures folder at $signaturesPath. Error: $($_.Exception.Message)"
        if (Get-Transcript) { Stop-Transcript }
        exit 1
    }
} else {
    Write-ColoredHost "Signatures folder already exists." -ForegroundColor $ColorSuccess
}

$scriptRootSignaturesPath = Join-Path -Path $PSScriptRoot -ChildPath "Signatures" # Assumes a "Signatures" subfolder in the script's location
Write-ColoredHost "Signatures source template path: $scriptRootSignaturesPath" -ForegroundColor $ColorInfo
if (-not (Test-Path $scriptRootSignaturesPath)) {
    Write-Error "Signatures source folder not found at '$scriptRootSignaturesPath'. Ensure it exists and contains your signature templates and assets."
    if (Get-Transcript) { Stop-Transcript }
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
    elseif ($item.Name -like "*.htm" -or $item.Name -like "*.rtf" -or $item.Name -like "*.txt") { # If it's a template file
        Write-ColoredHost "Processing template file: '$itemName'" -ForegroundColor $ColorInfo
        try {
            $signatureFileContent = Get-Content -Path $itemFullName -Raw -ErrorAction Stop
            
            Write-ColoredHost "  Replacing placeholders in '$itemName'..." -ForegroundColor $ColorDebug
            # Replace placeholder values using the $userAttributes custom object
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
            # Ensure UTF8 encoding for HTM/TXT files, RTF is binary so -Encoding might not be ideal or needed.
            if ($item.Extension -eq ".rtf") {
                Set-Content -Path $destinationPath -Value $signatureFileContent -Force -ErrorAction Stop 
            } else {
                Set-Content -Path $destinationPath -Value $signatureFileContent -Force -Encoding UTF8 -ErrorAction Stop
            }
            Write-ColoredHost "Successfully updated and saved signature file: '$destinationPath'" -ForegroundColor $ColorSuccess
        }
        catch {
            Write-Error "Failed to process or write signature file '$itemFullName'. Error: $($_.Exception.Message)"
        }
    } else { # Other files, copy them as is (e.g., images not in an asset folder)
        Write-ColoredHost "Copying other file: '$itemName' to '$signaturesPath'" -ForegroundColor $ColorInfo
        $destinationFile = Join-Path -Path $signaturesPath -ChildPath $itemName
        try {
            Copy-Item -Path $itemFullName -Destination $destinationFile -Force -ErrorAction Stop
            Write-ColoredHost "Successfully copied file '$itemName' to '$destinationFile'." -ForegroundColor $ColorSuccess
        }
        catch {
            Write-Error "Failed to copy file '$itemFullName' to '$destinationFile'. Error: $($_.Exception.Message)"
        }
    }
    Write-Host "" 
}

# ----------------------------------logic below will force the signature at the registry level and not allow user changes on the UI at all-------------------------------

<# 
$signatureName = "Standard" #

$OutlookVersionForRegistry = "16.0" 

$loggedOnUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName

try {
    $ntAccount = New-Object System.Security.Principal.NTAccount($loggedOnUser)
    $userSID = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
}
catch {
    Write-Error "Failed to resolve SID for $loggedOnUser. $_"
    exit 1
}


$registryPath = "Registry::HKEY_USERS\$userSID\Software\Microsoft\Office\$OutlookVersionForRegistry\Common\MailSettings"
try {
    Write-ColoredHost "Setting default signature for new emails and replies/forwards..." -ForegroundColor $ColorInfo
    Set-ItemProperty -Path $registryPath -Name "NewSignature" -Value $signatureName -ErrorAction Stop
    Set-ItemProperty -Path $registryPath -Name "ReplySignature" -Value $signatureName -ErrorAction Stop
    Write-ColoredHost "Default signature set successfully." -ForegroundColor $ColorSuccess
}
catch {
    Write-Error "Failed to set default signature in registry. Error: $($_.Exception.Message)"
}
#>
Write-Host ""
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "SCRIPT FINISHED: Outlook Signature Manager Installation" -ForegroundColor $ColorSection
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection

Stop-Transcript 
