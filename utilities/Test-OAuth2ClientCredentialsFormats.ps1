<#
.SYNOPSIS
    Tests a token/auth endpoint against 3 request formats to isolate whether it
    supports standards-compliant OAuth2 Client Credentials, or only a custom schema.

.DESCRIPTION
    Test 1 - Vendor's custom/documented JSON format
    Test 2 - Standard OAuth2 client_credentials grant (form-encoded)
    Test 3 - Standard OAuth2 client_credentials grant + Basic auth header
             (mimics Entra ID's provisioning connector behavior)

    Fill in the variables in the CONFIG section below, then run the script.
    No credentials are hardcoded below - this is a reusable template.

.NOTES
    Author: Angel Santoyo
    Usage : .\test-oauth2-auth-formats-template.ps1
#>

# =========================================
# CONFIG - fill these in before running
# =========================================

$authUrl      = ""   # e.g. "https://api.vendor.com/auth"
$clientId     = ""   # Client ID / Client Identifier
$clientSecret = ""   # Client Secret

# Custom JSON field names used by the vendor's documented/custom auth format.
# Update the hashtable keys below to match their schema (e.g. "client-id", "app-id").
$customJsonBody = @{
    "client-id" = $clientId
    "app-id"    = $clientId   # replace with a separate App ID variable if the vendor uses one
}

# =========================================
# TEST 1: Vendor's custom JSON format
# =========================================
Write-Host "==================================================="
Write-Host "TEST 1: Custom JSON format"
Write-Host "==================================================="

try {
    $jsonBody = $customJsonBody | ConvertTo-Json
    $response1 = Invoke-RestMethod -Uri $authUrl -Method Post -Body $jsonBody -ContentType "application/json"
    Write-Host "Custom JSON format SUCCESS:"
    $response1 | ConvertTo-Json
}
catch {
    Write-Host "Custom JSON format FAILED:"
    Write-Host $_.Exception.Response.StatusCode
    Write-Host $_.ErrorDetails.Message
}

Write-Host ""

# =========================================
# TEST 2: Standard OAuth2 client_credentials (form-encoded)
# =========================================
Write-Host "==================================================="
Write-Host "TEST 2: OAuth2 client_credentials (form-encoded)"
Write-Host "==================================================="

$oauthBody = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
}

try {
    $response2 = Invoke-RestMethod -Uri $authUrl -Method Post -Body $oauthBody -ContentType "application/x-www-form-urlencoded"
    Write-Host "OAuth2 form format SUCCESS:"
    $response2 | ConvertTo-Json
}
catch {
    Write-Host "OAuth2 form format FAILED:"
    Write-Host $_.Exception.Response.StatusCode
    Write-Host $_.ErrorDetails.Message
}

Write-Host ""

# =========================================
# TEST 3: OAuth2 client_credentials + Basic auth header
# (mimics Entra ID's provisioning connector, which can send
#  both a Basic auth header AND form body credentials together)
# =========================================
Write-Host "==================================================="
Write-Host "TEST 3: OAuth2 form + Basic auth header"
Write-Host "==================================================="

$pair      = "$($clientId):$($clientSecret)"
$bytes     = [System.Text.Encoding]::ASCII.GetBytes($pair)
$basicAuth = [System.Convert]::ToBase64String($bytes)

$headers = @{
    Authorization = "Basic $basicAuth"
}

try {
    $response3 = Invoke-RestMethod -Uri $authUrl -Method Post -Headers $headers -Body $oauthBody -ContentType "application/x-www-form-urlencoded"
    Write-Host "OAuth2 form + Basic auth SUCCESS:"
    $response3 | ConvertTo-Json
}
catch {
    Write-Host "OAuth2 form + Basic auth FAILED:"
    Write-Host $_.Exception.Response.StatusCode
    Write-Host $_.ErrorDetails.Message
}

Write-Host ""
Write-Host "==================================================="
Write-Host "Done. Compare the 3 results above:"
Write-Host " - If Test 1 succeeds and Tests 2/3 fail -> endpoint"
Write-Host "   only supports its own custom schema, not standard"
Write-Host "   OAuth2 client_credentials."
Write-Host "==================================================="
