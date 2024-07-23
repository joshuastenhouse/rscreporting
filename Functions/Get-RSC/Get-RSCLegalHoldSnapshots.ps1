################################################
# Function - Get-RSCLegalHoldSnapshots - Getting all snapshots on legal hold
################################################
Function Get-RSCLegalHoldSnapshots {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all Legal Hold Snapshots.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCLegalHoldSnapshots
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 08/22/2023
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting Rubrik Clusters 
$RSCClusters = Get-RSCClusters
# Getting all objects
$RSCAllObjectList = Get-RSCObjects
################################################
# Getting All Legal Hold Snapshots Per Cluster 
################################################
# Creating array for objects
$RSCObjectList = @()
# For each cluster
ForEach($RSCCluster in $RSCClusters)
{
# Setting cluster ID
$RSCClusterID = $RSCCluster.ClusterID
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "SnapshotManagementLegalHoldObjectsQuery";

"variables"=@{
	"input"=@{
		"filterParams"=@{"snapshotCustomizations"= $null}
		"clusterUuid"="$RSCClusterID"
		}
	"first"=50
};

"query" = "query SnapshotManagementLegalHoldObjectsQuery(`$input: SnappablesWithLegalHoldSnapshotsInput!, `$first: Int, `$after: String, `$last: Int, `$before: String) {
  snappablesWithLegalHoldSnapshotsSummary(input: `$input, first: `$first, after: `$after, last: `$last, before: `$before) {
    edges {
      cursor
      node {
        name
        id
        snappableType
        snapshotCount
        snapshotDetails {
          customizations
          id
          legalHoldTime
          snapshotTime
          type
          __typename
        }
        physicalLocation {
          name
          managedId
          __typename
        }
        __typename
      }
      __typename
    }
    pageInfo {
      endCursor
      hasPreviousPage
      hasNextPage
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
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListResponse.data.snappablesWithLegalHoldSnapshotsSummary.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.snappablesWithLegalHoldSnapshotsSummary.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.snappablesWithLegalHoldSnapshotsSummary.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.snappablesWithLegalHoldSnapshotsSummary.edges.node
}
# End of for each cluster below
}
# End of for each cluster above
################################################
# Processing Objects
################################################
# Creating array
$RSCLegalHoldObjects = [System.Collections.ArrayList]@()
$RSCLegalHoldSnapshots = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCObject in $RSCObjectList)
{
# Setting variables
$RSCObjectName = $RSCObject.name
$RSCObjectID = $RSCObject.id
$RSCObjectType = $RSCObject.snappableType
$RSCObjectLegalHoldSnapshotCount = $RSCObject.snapshotCount
$RSCObjectLegalHoldSnapshots = $RSCObject.snapshotDetails
# Getting additional object info
$RSCObjectInfo = $RSCAllObjectList | Where-Object {$_.ObjectID -eq $RSCObjectID}
$RSCObjectRubrikCluster = $RSCObjectInfo.RubrikCluster
$RSCObjectRubrikClusterID = $RSCObjectInfo.RubrikClusterID
$RSCObjectURL = $RSCObjectInfo.URL
$RSCObjectProtectionStatus = $RSCObjectInfo.ProtectionStatus
$RSCObjectSLADomain = $RSCObjectInfo.SLADomain
$RSCObjectSLADomainID = $RSCObjectInfo.SLADomainID
# Processing snapshots
ForEach($RSCSnapshot in $RSCObjectLegalHoldSnapshots)
{
# Assigning variables
$RSCSnapshotID = $RSCSnapshot.id
$RSCSnapshotLegalHoldTimeUNIX = $RSCSnapshot.legalHoldTime
$RSCSnapshotTimeUNIX = $RSCSnapshot.snapshotTime
$RSCSnapshotType = $RSCSnapshot.type
# Converting times
IF($RSCSnapshotLegalHoldTimeUNIX -ne $null){$RSCSnapshotLegalHoldTimeUTC = Convert-RSCUNIXTime $RSCSnapshotLegalHoldTimeUNIX}ELSE{$RSCSnapshotLegalHoldTimeUTC = $null}
IF($RSCSnapshotTimeUNIX -ne $null){$RSCSnapshotTimeUTC = Convert-RSCUNIXTime $RSCSnapshotTimeUNIX}ELSE{$RSCSnapshotTimeUTC = $null}
# Getting age of hold
$UTCDateTime = [System.DateTime]::UtcNow
IF($RSCSnapshotLegalHoldTimeUTC -ne $null)
{
$RSCSnapshotLegalHoldTimespan = New-TimeSpan -Start $RSCSnapshotLegalHoldTimeUTC -End $UTCDateTime
$RSCSnapshotLegalHoldDays = $RSCSnapshotLegalHoldTimespan | Select-Object -ExpandProperty TotalDays
$RSCSnapshotLegalHoldDays = [Math]::Round($RSCSnapshotLegalHoldDays)
}
ELSE
{
$RSCSnapshotLegalHoldDays = $null
}
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $RSCObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $RSCObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $RSCObjectType
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotUTC" -Value $RSCSnapshotTimeUTC
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotType" -Value $RSCSnapshotType
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $RSCSnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "LegalHoldUTC" -Value $RSCSnapshotLegalHoldTimeUTC
$Object | Add-Member -MemberType NoteProperty -Name "DaysOnHold" -Value $RSCSnapshotLegalHoldDays
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RSCObjectRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RSCObjectRubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $RSCObjectURL
$RSCLegalHoldSnapshots.Add($Object) | Out-Null
}
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCLegalHoldSnapshots
# End of function
}