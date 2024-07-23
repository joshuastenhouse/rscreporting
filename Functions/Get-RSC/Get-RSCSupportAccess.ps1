################################################
# Function - Get-RSCSupportAccess - Getting all support access sessions to RSC
################################################
Function Get-RSCSupportAccess {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returns a list of all reportable support sessions (current and recently expired) to your RSC instance.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSupportAccess
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
# Creating array
$RSCSupportAccessList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "SupportAccessTableQuery";

"variables" = @{
"first" = 1000
};

"query" = "query SupportAccessTableQuery(`$first: Int, `$after: String) {
  supportUserAccesses(first: `$first,after: `$after) {
    edges {
      cursor
      node {
        id
        accessStatus
        startTime
        endTime
        durationInHours
        ticketNumber
        accessProviderUser {
          id
          email
          __typename
        }
        impersonatedUser {
          id
          email
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
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCSupportAccessList += $RSCResponse.data.supportUserAccesses.edges.node
# Getting all results from paginations
While ($RSCResponse.data.supportUserAccesses.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.supportUserAccesses.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCSupportAccessList += $RSCResponse.data.supportUserAccesses.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCSupportAccess = [System.Collections.ArrayList]@()
# Creating URL
$RSCSupportAccessURL = $RSCURL + "/support_access"
# For Each Object Getting Data
ForEach ($Session in $RSCSupportAccessList)
{
# Setting variables
$SessionID = $Session.id
$SessionStatus = $Session.accessStatus
$SessionTicketNumber = $Session.ticketNumber
$SessionStartTimeUNIX = $Session.startTime
$SessionEndTimeUNIX = $Session.endTime
$SessionDurationHours = $Session.durationInHours
$SessionCreatedByUser = $Session.accessProviderUser.email
$SessionCreatedByUserID = $Session.accessProviderUser.id
$SessionAccessAsUser = $Session.impersonatedUser.email
$SessionAccessAsUserID = $Session.impersonatedUser.id
# Deciding if closed or not
IF($SessionStatus -match "CLOSED"){$SessionIsOpen = $FALSE}ELSE{$SessionIsOpen = $TRUE}
# Converting times
IF($SessionStartTimeUNIX -ne $null){$SessionStartTimeUTC = Convert-RSCUNIXTime $SessionStartTimeUNIX}ELSE{$SessionStartTimeUTC = $null}
IF($SessionEndTimeUNIX -ne $null){$SessionEndTimeUTC = Convert-RSCUNIXTime $SessionEndTimeUNIX}ELSE{$SessionEndTimeUTC = $null}
# Calculating duration days
IF(($SessionDurationHours -ne $null) -or ($SessionDurationHours -ne 0))
{
$SessionDurationDays = $SessionDurationHours / 24
$SessionDurationDays = [Math]::Round($SessionDurationDays)
}
ELSE
{
$SessionDurationDays = $null
}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "SessionID" -Value $SessionID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $SessionStatus
$Object | Add-Member -MemberType NoteProperty -Name "IsOpen" -Value $SessionIsOpen
$Object | Add-Member -MemberType NoteProperty -Name "TicketNumber" -Value $SessionTicketNumber
$Object | Add-Member -MemberType NoteProperty -Name "DurationHours" -Value $SessionDurationHours
$Object | Add-Member -MemberType NoteProperty -Name "DurationDays" -Value $SessionDurationDays
$Object | Add-Member -MemberType NoteProperty -Name "StartTimeUTC" -Value $SessionStartTimeUTC
$Object | Add-Member -MemberType NoteProperty -Name "EndTimeUTC" -Value $SessionEndTimeUTC
$Object | Add-Member -MemberType NoteProperty -Name "CreatedByUser" -Value $SessionCreatedByUser
$Object | Add-Member -MemberType NoteProperty -Name "CreatedByUserID" -Value $SessionCreatedByUserID
$Object | Add-Member -MemberType NoteProperty -Name "AccessAsUser" -Value $SessionAccessAsUser
$Object | Add-Member -MemberType NoteProperty -Name "AccessAsUserID" -Value $SessionAccessAsUserID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $RSCSupportAccessURL
# Adding
$RSCSupportAccess.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCSupportAccess
# End of function
}