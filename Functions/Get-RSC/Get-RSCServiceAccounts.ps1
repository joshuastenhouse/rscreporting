################################################
# Function - Get-RSCServiceAccounts - Getting Service Accounts within RSC
################################################
Function Get-RSCServiceAccounts {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returns a list of all service accounts configured.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCServiceAccounts
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
$RSCGraphQL = @{"operationName" = "GetServiceAccountsQuery";

"variables" = @{
"first" = 1000
};

"query" = "query GetServiceAccountsQuery(`$after: String, `$before: String, `$first: Int, `$roleIds: [UUID!]) {
  serviceAccounts(after: `$after, before: `$before, first: `$first, roleIds: `$roleIds) {
    edges {
      cursor
      node {
        clientId
        name
        description
        lastLogin
        roles {
          id
          name
          __typename
        }
        __typename
      }
      __typename
    }
    pageInfo {
      startCursor
      endCursor
      hasNextPage
      hasPreviousPage
      __typename
    }
    __typename
  }
}
"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.serviceAccounts.edges.node
# Getting all results from paginations
While ($RSCResponse.data.serviceAccounts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.serviceAccounts.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.serviceAccounts.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCServiceAccounts = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Account in $RSCList)
{
# Setting variables
$ClientID = $Account.clientID
$Name = $Account.name
$Description = $Account.description
$Roles = $Account.roles
$RoleCount = $Roles | Measure-Object | Select-Object -ExpandProperty Count
$UserLastLoginUNIX = $Account.lastLogin
# Converting UserLastLoginUNIX
IF($UserLastLoginUNIX -ne $null){$UserLastLoginUTC = Convert-RSCUNIXTime $UserLastLoginUNIX}ELSE{$UserLastLoginUTC = $null}
$UTCDateTime = [System.DateTime]::UtcNow
IF($UserLastLoginUTC -ne $null){$UserLastLoginTimespan = New-TimeSpan -Start $UserLastLoginUTC -End $UTCDateTime;$UserLastLoginHoursSince = $UserLastLoginTimespan | Select-Object -ExpandProperty TotalHours;$UserLastLoginHoursSince = [Math]::Round($UserLastLoginHoursSince,1)}ELSE{$UserLastLoginHoursSince = $null}
IF($UserLastLoginUTC -ne $null){$UserLastLoginMinutesSince = $UserLastLoginTimespan | Select-Object -ExpandProperty TotalMinutes;$UserLastLoginMinutesSince = [Math]::Round($UserLastLoginMinutesSince)}ELSE{$UserLastLoginMinutesSince = $null}
IF($UserLastLoginUTC -ne $null){$UserLastLoginDaysSince = $UserLastLoginTimespan | Select-Object -ExpandProperty TotalDays;$UserLastLoginDaysSince = [Math]::Round($UserLastLoginDaysSince,1)}ELSE{$UserLastLoginDaysSince = $null}
# Checking if in default admin group
IF($Roles.id -match "00000000-0000-0000-0000-000000000000"){$HasDefaultAdminRole = $TRUE}ELSE{$HasDefaultAdminRole = $FALSE}
# Creating URL
$ServiceAccountURL = $RSCURL + "/service_accounts"
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ServiceAccount" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "ClientID" -Value $ClientID
$Object | Add-Member -MemberType NoteProperty -Name "Description" -Value $Description
$Object | Add-Member -MemberType NoteProperty -Name "RoleCount" -Value $RoleCount
$Object | Add-Member -MemberType NoteProperty -Name "HasDefaultAdminRole" -Value $HasDefaultAdminRole
$Object | Add-Member -MemberType NoteProperty -Name "LastLoginUTC" -Value $UserLastLoginUTC
$Object | Add-Member -MemberType NoteProperty -Name "LastLoginDaysSince" -Value $UserLastLoginDaysSince
$Object | Add-Member -MemberType NoteProperty -Name "LastLoginHoursSince" -Value $UserLastLoginHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "LastLoginMinutesSince" -Value $UserLastLoginMinutesSince
$Object | Add-Member -MemberType NoteProperty -Name "Roles" -Value $Roles
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ServiceAccountURL
# Adding
$RSCServiceAccounts.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCServiceAccounts
# End of function
}