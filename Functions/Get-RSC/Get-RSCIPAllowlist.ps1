################################################
# Function - Get-RSCIPAllowlist - Getting IPs added to the allow list on RSC
################################################
Function Get-RSCIPAllowlist {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all IP addresses allowed to authenticate.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCIPAllowlist
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Querying RSC GraphQL API
################################################
# Creating array for objects
$RSCList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "IPWhitelistQuery";

"variables" = @{
"first" = 1000
};

"query" = "query IPWhitelistQuery {
  ipWhitelist {
    enabled
    mode
    ipCidrs
    __typename
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variables
$RSCList += $RSCResponse.data.ipWhitelist.ipCidrs
$IPAllowlistEnabled = $RSCResponse.data.ipWhitelist.enabled
$Mode = $RSCResponse.data.ipWhitelist.mode
################################################
# Processing List
################################################
# Creating array
$RSCIPAllowList = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($IP in $RSCList)
{
# Setting variables
$Split = $IP.Split("/")
IF($Split -ne $null)
{
$IPAddress = $Split[0]
$Subnet = [int]$Split[1]
$SubnetMask = ("1" * $Subnet) + ("0" * (32 - $Subnet))
$SubnetMask = [IPAddress] ([Convert]::ToUInt64($SubnetMask, 2))
$SubnetMask = $SubnetMask.IPAddressToString
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "IP" -Value $IPAddress
$Object | Add-Member -MemberType NoteProperty -Name "Subnet" -Value $Subnet
$Object | Add-Member -MemberType NoteProperty -Name "SubnetMask" -Value $SubnetMask
$Object | Add-Member -MemberType NoteProperty -Name "IPCidrs" -Value $IP
$Object | Add-Member -MemberType NoteProperty -Name "Enabled" -Value $IPAllowlistEnabled
$Object | Add-Member -MemberType NoteProperty -Name "Mode" -Value $Mode
# Adding
$RSCIPAllowList.Add($Object) | Out-Null
}
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCIPAllowList
# End of function
}