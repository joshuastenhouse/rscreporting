################################################
# Function - Get-RSCMSSQLLiveMounts - Getting all MSSQL Live Mounts on RSC
################################################
Function Get-RSCMSSQLLiveMounts {

<#
.SYNOPSIS
Returns a list of all active live mounts for SQL databases.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCLiveMounts
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
# Getting a list of hosts, needed for missing data on APIs
$RSCHostList = Get-RSCHosts
# Creating array across all object types
$RSCLiveMounts = [System.Collections.ArrayList]@()
################################################
# Querying RSC GraphQL API for MSSQL DB Live Mounts
################################################
# Creating array
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "MssqlDatabaseLiveMountListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query MssqlDatabaseLiveMountListQuery(`$first: Int!, `$after: String, `$filters: [MssqlDatabaseLiveMountFilterInput!], `$sortBy: MssqlDatabaseLiveMountSortByInput) {
  mssqlDatabaseLiveMounts(after: `$after, first: `$first, filters: `$filters, sortBy: `$sortBy) {
    edges {
      cursor
      node {
        id: fid
        creationDate
        mountedDatabaseName
        isReady
        recoveryPoint
        targetInstance {
          name
          logicalPath {
            name
            objectType
            __typename
          }
          __typename
        }
        sourceDatabase {
          id
          name
          __typename
        }
        cluster {
          id
          name
          version
          status
          timezone
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
$RSCObjectList += $RSCResponse.data.mssqlDatabaseLiveMounts.edges.node
# Getting all results from paginations
While ($RSCResponse.data.mssqlDatabaseLiveMounts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.mssqlDatabaseLiveMounts.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCResponse.data.mssqlDatabaseLiveMounts.edges.node
}
################################################
# Processing MSSQL_DATABASE
################################################
# Creating URL
$RSCLiveMountURL = $RSCURL + "/live_mounts?snappable_type=MSSQL_DATABASE"
# For Each Object Getting Data
ForEach ($LiveMount in $RSCObjectList)
{
# Setting variables
$LiveMountID = $LiveMount.id
$LiveMountSnapshotUNIX = $LiveMount.recoveryPoint
$LiveMountRubrikCluster = $LiveMount.cluster.name
$LiveMountRubrikClusterID = $LiveMount.cluster.id
$LiveMountObject = $LiveMount.mountedDatabaseName
$LiveMountStatus = "MOUNTED"
$LiveMountTimeUNIX = $LiveMount.creationDate
$LiveMountSourceObject = $LiveMount.sourceDatabase.name
$LiveMountSourceObjectID = $LiveMount.sourceDatabase.id
$LiveMountHost = $LiveMount.targetInstance.logicalPath.name
$LiveMountIsReady = $LiveMount.isReady
# Host ID not on the API, so getting it from the name
$LiveMountHostID = $RSCHostList | Where-Object {$_.Host -eq $LiveMountHost} | Select-Object -ExpandProperty HostID -First 1
# Deciding if migrating
$LiveMountMigrating = "N/A"
# Converting times
IF($LiveMountSnapshotUNIX -ne $null){$LiveMountSnapshotUTC = Convert-RSCUNIXTime $LiveMountSnapshotUNIX}ELSE{$LiveMountSnapshotUTC = $null}
IF($LiveMountTimeUNIX -ne $null){$LiveMountTimeUTC = Convert-RSCUNIXTime $LiveMountTimeUNIX}ELSE{$LiveMountTimeUTC = $null}
# Calculating duration
$UTCDateTime = [System.DateTime]::UtcNow
IF($LiveMountTimeUTC -ne $null)
{
$RSCLiveMountTimespan = New-TimeSpan -Start $LiveMountTimeUTC -End $UTCDateTime
$RSCLiveMountDays = $RSCLiveMountTimespan | Select-Object -ExpandProperty TotalDays
$RSCLiveMountDays = [Math]::Round($RSCLiveMountDays)
$RSCLiveMountHours = $RSCLiveMountTimespan | Select-Object -ExpandProperty TotalHours
$RSCLiveMountHours = [Math]::Round($RSCLiveMountHours)
$RSCLiveMountMinutes = $RSCLiveMountTimespan | Select-Object -ExpandProperty TotalMinutes
$RSCLiveMountMinutes = [Math]::Round($RSCLiveMountMinutes)
$RSCLiveMountDuration = "{0:g}" -f $RSCLiveMountTimespan
IF($RSCLiveMountDuration -match "."){$RSCLiveMountDuration = $RSCLiveMountDuration.split('.')[0]}
}
ELSE
{
$RSCLiveMountDays = $null
$RSCLiveMountHours = $null
$RSCLiveMountMinutes = $null
$RSCLiveMountDuration = $null
}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "LiveMountID" -Value $LiveMountID
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $LiveMountObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceDB" -Value $LiveMountSourceObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceDBID" -Value $LiveMountSourceObjectID
$Object | Add-Member -MemberType NoteProperty -Name "Snapshot" -Value $LiveMountSnapshotUTC
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $LiveMountStatus
$Object | Add-Member -MemberType NoteProperty -Name "IsReady" -Value $LiveMountIsReady
$Object | Add-Member -MemberType NoteProperty -Name "MountPath" -Value "N/A"
$Object | Add-Member -MemberType NoteProperty -Name "MountTimeUTC" -Value $LiveMountTimeUTC
$Object | Add-Member -MemberType NoteProperty -Name "Duration" -Value $RSCLiveMountDuration
$Object | Add-Member -MemberType NoteProperty -Name "TotalDays" -Value $RSCLiveMountDays
$Object | Add-Member -MemberType NoteProperty -Name "TotalHours" -Value $RSCLiveMountHours
$Object | Add-Member -MemberType NoteProperty -Name "TotalMinutes" -Value $RSCLiveMountMinutes
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $LiveMountHost
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $LiveMountHostID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $LiveMountRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $LiveMountRubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $RSCLiveMountURL
# Adding
$RSCLiveMounts.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Strange bug whereby it returns 1 null entry if no mounts, so removing
$RSCLiveMounts = $RSCLiveMounts | Where-Object {$_.LiveMountID -ne $null}

# Returning array
Return $RSCLiveMounts
# End of function
}