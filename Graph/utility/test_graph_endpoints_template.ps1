#This script serves as a template/utility for testing Microsoft Graph API endpoints in powershell
#I use it when constructing and testing new endpoints to see how they behave in powershell

#instructions
#1. fill in the variables below with the id you need to test
#2. Construct the apiURL variable with the endpoint you want to test
# - Add to the url with ?select, ?filter, ?top, etc. to the URL as needed to see how it behaves in powershell





Connect-MgGraph -Scopes "User.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "Directory.ReadWrite.All"


#fil in the id you need for testing and visiblity on 
$deviceID = "" #add display name here
$groupID=""
$objectID=""
$userID=""

#some common endpoints i use
#devices
#https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceID

#users
#https://graph.microsoft.com/beta/users/$userID

#groups
#https://graph.microsoft.com/v1.0/groups/$GroupId/members



#--------------------------------------------------------------------------
#query the endpoint needed below
$apiURL = ""

$response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject

Write-output $response
Write-output $reponse.value




