################################################
# Function - Get-RSCM365Objects - Getting o365 Objects connected to RSC
################################################
Function Get-RSCM365Objects {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all M365 objects (I.E mailboxes, onedrive, sharepoint sites, teams).

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCM365Objects
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
# Getting all RSC Objects
$RSCM365ObjectsList = Get-RSCObjects | Where-Object {$_.Type -match "o365"}
################################################
# Getting All o365 Subscriptions 
################################################
# Creating array for objects
$o365SubscriptionList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "o365Orgs";

"variables" = @{
"first" = 1000
};

"query" = "query o365Orgs(`$first: Int, `$after: String) {
  o365Orgs(first: `$first, after: `$after) {
    edges {
      node {
        status
        past1DayMailboxComplianceCount
        past1DayMailboxOutOfComplianceCount
        past1DayOnedriveComplianceCount
        past1DayOnedriveOutOfComplianceCount
        past1DaySharepointComplianceCount
        past1DaySharepointOutOfComplianceCount
        past1DayTeamsComplianceCount
        past1DayTeamsOutOfComplianceCount
        past1DaySpListComplianceCount
        past1DaySpListOutOfComplianceCount
        past1DaySpSiteCollectionComplianceCount
        past1DaySpSiteCollectionOutOfComplianceCount
        id
        unprotectedUsersCount
        name
        objectType
        slaAssignment
        searchDescendantConnection {
          edges {
            node {
              id
              name
              objectType
              slaAssignment
              effectiveSlaDomain {
                id
                name
              }
            }
          }
          }
        effectiveSlaDomain {
          id
          name
        }
        numWorkloadDescendants
      }
    }
              pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
    }
  }
}
"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$o365SubscriptionResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$o365SubscriptionList += $o365SubscriptionResponse.data.o365Orgs.edges.node
# Getting all results from paginations
While ($o365SubscriptionResponse.data.o365Orgs.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $o365SubscriptionResponse.data.o365Orgs.pageInfo.endCursor
$o365SubscriptionResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$o365SubscriptionList += $o365SubscriptionResponse.data.o365Orgs.edges.node
}
################################################
# Processing 
################################################
# Creating array
$o365Objects = [System.Collections.ArrayList]@()
# Time for refresh since
$UTCDateTime = [System.DateTime]::UtcNow
# For Each Object Getting Data
ForEach ($o365Sub in $o365SubscriptionList)
{
# Setting variables
$o365SubName = $o365Sub.name
$o365SubID = $o365Sub.id
$o365SubUnprotectedUsers = $o365Sub.unprotectedUsersCount
$o365SubStatus = $o365Sub.status
$o365SubSLAAssignment = $o365Sub.slaAssignment
$o365SubSLADomain = $o365Sub.effectiveSlaDomain.name
$o365SubSLADomainID = $o365Sub.effectiveSlaDomain.id
# Selecting oject types
$O365ObjectList = $o365Sub.searchDescendantConnection.edges.node
# For each object adding to array
ForEach($O365Object in $O365ObjectList)
{
# Setting variables
$o365objectName = $O365Object.name
$o365objectID = $O365Object.id
$o365objectType = $O365Object.objectType
$o365objectSLAAssignment = $O365Object.slaAssignment
$o365objectSLADomain = $O365Object.effectiveSlaDomain.name
$o365objectSLADomainID = $O365Object.effectiveSlaDomain.id
# Getting info from objects list
$ObjectInfo = $RSCM365ObjectsList | Where-Object {$_.ObjectID -eq $o365objectID}
$o365objectProtectionStatus = $ObjectInfo.ProtectionStatus
$o365objectLastSnapshot = $ObjectInfo.LastSnapshot
$o365objectHoursSince = $ObjectInfo.HoursSince
$o365objectTotalSnapshots = $ObjectInfo.TotalSnapshots
$o365objectURL = $ObjectInfo.URL
# If protection status is null, must be unprotected
IF($o365objectProtectionStatus -eq $null){$o365objectProtectionStatus = "NoSla"}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $o365SubName
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $o365SubID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value $o365objectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $o365objectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $o365objectType
$Object | Add-Member -MemberType NoteProperty -Name "ProtectionStatus" -Value $o365objectProtectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $o365objectSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $o365objectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $o365objectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "TotalSnapshots" -Value $o365objectTotalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $o365objectLastSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $o365objectHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $o365objectURL
# Adding
$o365Objects.Add($Object) | Out-Null
# End of for each o365 object below
}
# End of for each o365 object above
#
# End of for each o365 subscription below
}
# End of for each o365 subscription above
# Returning array
Return $o365Objects
# End of function
}