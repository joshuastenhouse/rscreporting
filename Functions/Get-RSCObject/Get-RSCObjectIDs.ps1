################################################
# Function - Get-RSCObjectIDs - Getting all object IDs visible to the RSC instance
################################################
Function Get-RSCObjectIDs {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of every protectable object in RSC. Useful for obtaining ObjectIDs.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectIDs
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 08/21/2024
#>
################################################
# Paramater Config
################################################
Param
    (
        [Parameter(Mandatory=$false)]$ObjectQueryLimit
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting All Objects 
################################################
# Setting first value if null
IF($ObjectQueryLimit -eq $null){$ObjectQueryLimit = 1000}
# Creating array for objects
$RSCObjectsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "snappableConnection";

"variables" = @{
"first" = $ObjectQueryLimit
"filter" = @{
        "objectType" = $ObjectType
        }
};

"query" = "query snappableConnection(`$after: String, `$filter: SnappableFilterInput) {
  snappableConnection(after: `$after, filter: `$filter) {
    edges {
      node {
        fid
        name
        objectType
        protectionStatus
        awaitingFirstFull
        totalSnapshots
      }
    }
        pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      __typename
    }
  }
}
"
}
# Converting to JSON
$RSCJSON = $RSCGraphQL | ConvertTo-Json -Depth 32
# Converting back to PS object for editing of variables
$RSCJSONObject = $RSCJSON | ConvertFrom-Json
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCJSONObject | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
# Counters
$ObjectCount = 0
$ObjectCounter = $ObjectCount + $ObjectQueryLimit
# Getting all results from paginations
While ($RSCObjectsResponse.data.snappableConnection.pageInfo.hasNextPage) 
{
# Logging
Write-Host "GettingObjects: $ObjectCount-$ObjectCounter"
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectsResponse.data.snappableConnection.pageInfo.endCursor
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
# Incrementing
$ObjectCount = $ObjectCount + $ObjectQueryLimit
$ObjectCounter = $ObjectCounter + $ObjectQueryLimit
}
# Correcting column names
$RSCObjectIDs = $RSCObjectsList | Select-Object @{Name="ObjectID"; Expression = {$_.'fid'}},@{Name="Object"; Expression = {$_.'name'}},@{Name="Type"; Expression = {$_.'objectType'}},@{Name="ProtectionStatus"; Expression = {$_.'protectionStatus'}},@{Name="TotalSnapshots"; Expression = {$_.'totalSnapshots'}},@{Name="PendingFirstFull"; Expression = {$_.'awaitingFirstFull'}}

# Setting global variable for use in other functions so they don't have to collect it again
$Global:RSCGlobalObjectIDs = $RSCObjectIDs

# Returning array
Return $RSCObjectIDs
# End of function
}
