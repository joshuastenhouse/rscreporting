################################################
# Function - Get-RSCADDomainDNT - Getting All Active Directory Domain DNTs For the AD DNT & Snapshot Specified
################################################
Function Get-RSCADDomainDNT {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all DNTs on the specified DNT, used for browsing an AD snapshot.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCADDomainDNT
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 07/08/2024
#>

################################################
# Paramater Config
################################################	
	Param
    (
    [Parameter(Mandatory=$true)]
    [String]$SnapshotID,[int]$DNT,[switch]$ListContainers
    )
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
$AllDNTList = @()
# Building GraphQL query
IF($ListContainers)
{
$RSCGraphQL = @{"operationName" = "DcSnapshotBrowseQuery";

"variables" = @{
"activeDirectorySnapshotBrowseId" = $SnapshotID
"dnt" = $DNT
"first" = 1000
"listOnlyContainers" = $true
};

"query" = "query DcSnapshotBrowseQuery(`$activeDirectorySnapshotBrowseId: String!, `$dnt: Int!, `$first: Int, `$after: String, `$listOnlyContainers: Boolean, `$locationId: String, `$activeDirectoryObjectType: ActiveDirectoryObjectType) {
  activeDirectorySnapshotBrowse(id: `$activeDirectorySnapshotBrowseId, dnt: `$dnt, first: `$first, after: `$after, listOnlyContainers: `$listOnlyContainers, locationId: `$locationId, activeDirectoryObjectType: `$activeDirectoryObjectType) {
    count
    edges {
      cursor
      node {
        description
        dn
        dnt
        name
        activeDirectoryObjectType
        __typename
      }
      __typename
    }
    pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      startCursor
      __typename
    }
    __typename
  }
}"
}
}
ELSE
{
$RSCGraphQL = @{"operationName" = "DcSnapshotBrowseQuery";

"variables" = @{
"activeDirectorySnapshotBrowseId" = $SnapshotID
"dnt" = $DNT
"first" = 1000
"listOnlyContainers" = $false
};

"query" = "query DcSnapshotBrowseQuery(`$activeDirectorySnapshotBrowseId: String!, `$dnt: Int!, `$first: Int, `$after: String, `$listOnlyContainers: Boolean, `$locationId: String, `$activeDirectoryObjectType: ActiveDirectoryObjectType) {
  activeDirectorySnapshotBrowse(id: `$activeDirectorySnapshotBrowseId, dnt: `$dnt, first: `$first, after: `$after, listOnlyContainers: `$listOnlyContainers, locationId: `$locationId, activeDirectoryObjectType: `$activeDirectoryObjectType) {
    count
    edges {
      cursor
      node {
        description
        dn
        dnt
        name
        activeDirectoryObjectType
        __typename
      }
      __typename
    }
    pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      startCursor
      __typename
    }
    __typename
  }
}"
}
}
################################################
# API Call To RSC GraphQL URI 
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$AllDNTList += $RSCResponse.data.activeDirectorySnapshotBrowse.edges.node
# Removing 3804, this is just the top level structure of the domain in the snapshot browse view, it's not an OU/container
$AllDNTList = $AllDNTList | Where-Object {$_.dnt -ne "3804"}
# Getting all results from activeDirectorySnapshotBrowse
While ($RSCResponse.data.activeDirectorySnapshotBrowse.pageInfo.hasNextPage)
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.activeDirectorySnapshotBrowse.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$AllDNTList += $RSCResponse.data.activeDirectorySnapshotBrowse.edges.node
}

#
# Returning array
Return $AllDNTList
# End of function
}