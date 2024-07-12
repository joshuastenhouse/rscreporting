################################################
# Function - Get-RSCLiveMounts - Getting all Live Mounts on RSC
################################################
Function Get-RSCLiveMounts {

<#
.SYNOPSIS
Returns a list of all active live mounts across VMware, HyperV, AHV, Volume Groups, Managed Volumes, SQL and Oracle databases.

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
# Querying RSC GraphQL API for VMware Live Mounts
################################################
# Creating array
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "vSphereMountQuery";

"variables" = @{
"first" = 1000
};

"query" = "query vSphereMountQuery(`$first: Int, `$after: String) {
  vSphereLiveMounts(first: `$first, after: `$after) {
    edges {
      cursor
      __typename
      node {
        __typename
        id
        isReady
        attachingDiskCount
        hasAttachingDisk
        migrateDatastoreRequestId
        sourceSnapshot {
          __typename
          date
          snappableNew {
            ... on VsphereVm {
              physicalPath {
                fid
                name
                objectType
                __typename
              }
              vsphereVirtualDisks {
                nodes {
                  size
                  excludeFromSnapshots
                  datastoreFid
                  fileName
                  size
                  deviceKey
                  datastore {
                    id
                    isArchived
                    __typename
                  }
                  __typename
                }
                __typename
              }
              __typename
            }
            __typename
          }
        }
        cluster {
          __typename
          id
          name
          status
        }
        ...VsphereLiveMountTimeFragment
        ...VsphereLiveMountNameFragment
        ...VsphereLiveMountHostFragment
      }
    }
    pageInfo {
      startCursor
      endCursor
      hasPreviousPage
      hasNextPage
      __typename
    }
    __typename
  }
}

fragment VsphereLiveMountHostFragment on VsphereLiveMount {
  host {
    id
    name
    __typename
  }
  __typename
}

fragment VsphereLiveMountNameFragment on VsphereLiveMount {
  vmStatus
  newVmName
  sourceVm {
    __typename
    id
    name
  }
  hasAttachingDisk
  attachingDiskCount
  mountedVm {
    __typename
    name
  }
  __typename
}

fragment VsphereLiveMountTimeFragment on VsphereLiveMount {
  mountTimestamp
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCResponse.data.vSphereLiveMounts.edges.node
# Getting all results from paginations
While ($RSCResponse.data.vSphereLiveMounts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.vSphereLiveMounts.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCResponse.data.vSphereLiveMounts.edges.node
}
################################################
# Processing VSPHERE_VIRTUAL_MACHINE
################################################
# Creating URL
$RSCLiveMountURL = $RSCURL + "/live_mounts?snappable_type=VSPHERE_VIRTUAL_MACHINE"
# For Each Object Getting Data
ForEach ($LiveMount in $RSCObjectList)
{
# Setting variables
$LiveMountID = $LiveMount.id
$LiveMountSnapshotUNIX = $LiveMount.sourceSnapshot.date
$LiveMountRubrikCluster = $LiveMount.cluster.name
$LiveMountRubrikClusterID = $LiveMount.cluster.id
$LiveMountIsReady = $LiveMount.isReady
$LiveMountObject = $LiveMount.newVmName
$LiveMountSourceObject = $LiveMount.sourceVm.name
$LiveMountSourceObjectID = $LiveMount.sourceVm.name
$LiveMountHost = $LiveMount.host.name
$LiveMountHostID = $LiveMount.host.id
$LiveMountStatus = $LiveMount.vmStatus
$LiveMountTimeUNIX = $LiveMount.mountTimestamp
# Deciding if migrating
$LiveMountMigrationID = $LiveMount.migrateDatastoreRequestId
IF($LiveMountMigrationID -eq ""){$LiveMountMigrating = $FALSE}ELSE{$LiveMountMigrating = $TRUE}
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
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "VMWareVM"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $LiveMountObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObject" -Value $LiveMountSourceObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObjectID" -Value $LiveMountSourceObjectID
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
################################################
# Querying RSC GraphQL API for HyperV Live Mounts
################################################
# Creating array
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "HypervMountQuery";

"variables" = @{
"first" = 1000
};

"query" = "query HypervMountQuery(`$first: Int, `$after: String, `$filters: [HypervLiveMountFilterInput!], `$sortBy: HypervLiveMountSortByInput) {
  hypervMounts(first: `$first, after: `$after, filters: `$filters, sortBy: `$sortBy) {
    edges {
      cursor
      node {
        name
        id
        mountedVmStatus
        mountTime
        serverFid
        serverName
        cluster {
          id
          timezone
          __typename
        }
        sourceSnapshot {
          date
          snappableNew {
            name
            id
            __typename
          }
          __typename
        }
        cluster {
          id
          name
          version
          status
          __typename
        }
        __typename
      }
      __typename
    }
    pageInfo {
      startCursor
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
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCResponse.data.hypervMounts.edges.node
# Getting all results from paginations
While ($RSCResponse.data.hypervMounts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.hypervMounts.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCResponse.data.hypervMounts.edges.node
}
################################################
# Processing HYPERV_VIRTUAL_MACHINE
################################################
# Creating URL
$RSCLiveMountURL = $RSCURL + "/live_mounts?snappable_type=HYPERV_VIRTUAL_MACHINE"
# For Each Object Getting Data
ForEach ($LiveMount in $RSCObjectList)
{
# Setting variables
$LiveMountID = $LiveMount.id
$LiveMountSnapshotUNIX = $LiveMount.sourceSnapshot.date
$LiveMountRubrikCluster = $LiveMount.cluster.name
$LiveMountRubrikClusterID = $LiveMount.cluster.id
$LiveMountObject = $LiveMount.name
$LiveMountStatus = $LiveMount.mountedVmStatus
$LiveMountTimeUNIX = $LiveMount.mountTime
$LiveMountSourceObject = $LiveMount.sourceSnapshot.snappableNew.name
$LiveMountSourceObjectID = $LiveMount.sourceSnapshot.snappableNew.id
$LiveMountHost = $LiveMount.serverName
$LiveMountHostID = $LiveMount.serverFid
# Not on this API but on VMware
$LiveMountIsReady = $TRUE
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
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "HypervVM"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $LiveMountObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObject" -Value $LiveMountSourceObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObjectID" -Value $LiveMountSourceObjectID
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
################################################
# Querying RSC GraphQL API for AHV Live Mounts
################################################
# Creating array
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "NutanixMountQuery";

"variables" = @{
"first" = 1000
};

"query" = "query NutanixMountQuery(`$first: Int, `$after: String, `$filters: [NutanixLiveMountFilterInput!], `$sortBy: NutanixLiveMountSortByInput) {
  nutanixMounts(first: `$first, after: `$after, filters: `$filters, sortBy: `$sortBy) {
    count
    edges {
      cursor
      node {
        isVmReady
        powerStatus
        name
        id
        isMigrationDisabled
        migrationJobInstanceId
        migrationJobStatus
        mountedDate
        cluster {
          id
          name
          version
          status
          timezone
          __typename
        }
        snapshotDate
        sourceVmName
        sourceVmFid
        nutanixClusterFid
        nutanixClusterId
        nutanixClusterName
        __typename
      }
      __typename
    }
    pageInfo {
      startCursor
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
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCResponse.data.nutanixMounts.edges.node
# Getting all results from paginations
While ($RSCResponse.data.nutanixMounts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.nutanixMounts.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCResponse.data.nutanixMounts.edges.node
}
################################################
# Processing NUTANIX_VIRTUAL_MACHINE
################################################
# Creating URL
$RSCLiveMountURL = $RSCURL + "/live_mounts?snappable_type=NUTANIX_VIRTUAL_MACHINE"
# For Each Object Getting Data
ForEach ($LiveMount in $RSCObjectList)
{
# Setting variables
$LiveMountID = $LiveMount.id
$LiveMountSnapshotUNIX = $LiveMount.snapshotDate
$LiveMountRubrikCluster = $LiveMount.cluster.name
$LiveMountRubrikClusterID = $LiveMount.cluster.id
$LiveMountObject = $LiveMount.name
$LiveMountStatus = $LiveMount.powerStatus
$LiveMountTimeUNIX = $LiveMount.mountedDate
$LiveMountSourceObject = $LiveMount.sourceVmName
$LiveMountSourceObjectID = $LiveMount.sourceVmFid
$LiveMountHost = $LiveMount.nutanixClusterName
$LiveMountHostID = $LiveMount.nutanixClusterFid
$LiveMountIsReady = $LiveMount.isVmReady
# Deciding if migrating
$LiveMountMigrationID = $LiveMount.migrationJobInstanceId
IF($LiveMountMigrationID -eq ""){$LiveMountMigrating = $FALSE}ELSE{$LiveMountMigrating = $TRUE}
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
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "AHVVM"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $LiveMountObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObject" -Value $LiveMountSourceObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObjectID" -Value $LiveMountSourceObjectID
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
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "MSSQLDatabase"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $LiveMountObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObject" -Value $LiveMountSourceObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObjectID" -Value $LiveMountSourceObjectID
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
################################################
# Querying RSC GraphQL API for Windows Volume Live Mounts
################################################
# Creating array
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "WindowsVolumeGroupLiveMountsQuery";

"variables" = @{
"first" = 1000
};

"query" = "query WindowsVolumeGroupLiveMountsQuery(`$first: Int!, `$after: String, `$filters: [VolumeGroupLiveMountFilterInput!], `$sortBy: VolumeGroupLiveMountSortByInput) {
  volumeGroupMounts(first: `$first, after: `$after, filters: `$filters, sortBy: `$sortBy) {
    edges {
      cursor
      node {
        id
        name
        restoreScriptPath
        cluster {
          id
          name
          timezone
          __typename
        }
        sourceSnapshot {
          date
          __typename
        }
        sourceHost {
          id
          name
          __typename
        }
        targetHostName
        mountedVolumes {
          originalMountPoints
          smbPath
          hostMountPath
          size
          __typename
        }
        authorizedOperations {
          id
          operations
          __typename
        }
        mountTimestamp
        __typename
      }
      __typename
    }
    pageInfo {
      endCursor
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
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCResponse.data.volumeGroupMounts.edges.node
# Getting all results from paginations
While ($RSCResponse.data.volumeGroupMounts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.volumeGroupMounts.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCResponse.data.volumeGroupMounts.edges.node
}
################################################
# Processing VOLUME_GROUP
################################################
# Creating URL
$RSCLiveMountURL = $RSCURL + "/live_mounts?snappable_type=VOLUME_GROUP"
# For Each Object Getting Data
ForEach ($LiveMount in $RSCObjectList)
{
# Setting variables
$LiveMountID = $LiveMount.id
$LiveMountSnapshotUNIX = $LiveMount.sourceSnapshot.date
$LiveMountRubrikCluster = $LiveMount.cluster.name
$LiveMountRubrikClusterID = $LiveMount.cluster.id
$LiveMountObject = $LiveMount.name
$LiveMountStatus = "MOUNTED"
$LiveMountTimeUNIX = $LiveMount.mountTimestamp
$LiveMountSourceObject = $LiveMount.sourceHost.name
$LiveMountSourceObjectID = $LiveMount.sourceHost.id
$LiveMountIsReady = $TRUE
$LiveMountHost = $LiveMount.targetHostName
$LiveMountPath = $LiveMount.mountedVolumes.hostMountPath
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
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "VolumeGroup"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $LiveMountObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObject" -Value $LiveMountSourceObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObjectID" -Value $LiveMountSourceObjectID
$Object | Add-Member -MemberType NoteProperty -Name "Snapshot" -Value $LiveMountSnapshotUTC
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $LiveMountStatus
$Object | Add-Member -MemberType NoteProperty -Name "IsReady" -Value $LiveMountIsReady
$Object | Add-Member -MemberType NoteProperty -Name "MountPath" -Value $LiveMountPath
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
################################################
# Querying RSC GraphQL API for Managed Volume Live Mounts
################################################
# Creating array
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "ManagedVolumesLiveMountListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query ManagedVolumesLiveMountListQuery(`$first: Int, `$after: String, `$filter: [Filter!], `$sortBy: HierarchySortByField, `$sortOrder: SortOrder) {
  managedVolumeLiveMounts(first: `$first, after: `$after, filter: `$filter, sortBy: `$sortBy, sortOrder: `$sortOrder) {
    count
    edges {
      cursor
      node {
        ...ManagedVolumesLiveMountFragment
        cluster {
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
      hasPreviousPage
      hasNextPage
      __typename
    }
    __typename
  }
}

fragment ManagedVolumesLiveMountFragment on ManagedVolumeMount {
  id
  authorizedOperations
  cluster {
    id
    name
    version
    status
    timezone
    __typename
  }
  sourceSnapshot {
    date
    __typename
  }
  channels {
    exportDate
    mountPath
    floatingIpAddress
    mountSpec {
      mountDir
      node {
        ipAddress
        __typename
      }
      __typename
    }
    __typename
  }
  managedVolume {
    id
    name
    managedVolumeType
    clientConfig {
      channelHostMountPaths
      __typename
    }
    __typename
  }
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCResponse.data.managedVolumeLiveMounts.edges.node
# Getting all results from paginations
While ($RSCResponse.data.managedVolumeLiveMounts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.managedVolumeLiveMounts.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCResponse.data.managedVolumeLiveMounts.edges.node
}
################################################
# Processing MANAGED_VOLUME_EXPORT
################################################
# Creating URL
$RSCLiveMountURL = $RSCURL + "/live_mounts?snappable_type=MANAGED_VOLUME_EXPORT"
# For Each Object Getting Data
ForEach ($LiveMount in $RSCObjectList)
{
# Setting variables
$LiveMountID = $LiveMount.id
$LiveMountSnapshotUNIX = $LiveMount.sourceSnapshot.date
$LiveMountRubrikCluster = $LiveMount.cluster.name
$LiveMountRubrikClusterID = $LiveMount.cluster.id
$LiveMountObject = $LiveMount.managedVolume.name
$LiveMountStatus = "MOUNTED"
$LiveMountTimeUNIX = $LiveMount.channels.exportDate
$LiveMountSourceObject = $LiveMount.managedVolume.name
$LiveMountSourceObjectID = $LiveMount.managedVolume.id
$LiveMountIsReady = $TRUE
$LiveMountHost = $LiveMount.managedVolume.name
$LiveMountPath = $LiveMount.channels.mountPath
# Host ID not on the API, so getting it from the name
$LiveMountHostID = $LiveMount.managedVolume.id
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
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "ManagedVolume"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $LiveMountObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObject" -Value $LiveMountSourceObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObjectID" -Value $LiveMountSourceObjectID
$Object | Add-Member -MemberType NoteProperty -Name "Snapshot" -Value $LiveMountSnapshotUTC
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $LiveMountStatus
$Object | Add-Member -MemberType NoteProperty -Name "IsReady" -Value $LiveMountIsReady
$Object | Add-Member -MemberType NoteProperty -Name "MountPath" -Value $LiveMountPath
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
################################################
# Querying RSC GraphQL API for ORACLE_DATABASE Live Mounts
################################################
# Creating array
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "OracleLiveMountListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query OracleLiveMountListQuery(`$first: Int!, `$after: String, `$filters: [OracleLiveMountFilterInput!], `$sortBy: OracleLiveMountSortBy) {
  oracleLiveMounts(after: `$after, first: `$first, filters: `$filters, sortBy: `$sortBy) {
    edges {
      cursor
      node {
        ...OracleLiveMountFragment
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

fragment OracleLiveMountFragment on OracleLiveMount {
  cluster {
    id
    name
    __typename
  }
  id
  status
  sourceDatabase {
    name
    id
    objectType
    __typename
  }
  mountedDatabase {
    name
    __typename
  }
  targetOracleHost {
    name
    __typename
  }
  targetOracleRac {
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
  cdmId
  mountedDatabaseName
  creationDate
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCResponse.data.oracleLiveMounts.edges.node
# Getting all results from paginations
While ($RSCResponse.data.oracleLiveMounts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.oracleLiveMounts.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCResponse.data.oracleLiveMounts.edges.node
}
################################################
# Processing ORACLE_DATABASE
################################################
# Creating URL
$RSCLiveMountURL = $RSCURL + "/live_mounts?snappable_type=ORACLE_DATABASE"
# For Each Object Getting Data
ForEach ($LiveMount in $RSCObjectList)
{
# Setting variables
$LiveMountID = $LiveMount.id
$LiveMountSnapshotUNIX = $null
$LiveMountRubrikCluster = $LiveMount.cluster.name
$LiveMountRubrikClusterID = $LiveMount.cluster.id
$LiveMountObject = $LiveMount.mountedDatabaseName
$LiveMountStatus = $LiveMount.status
$LiveMountTimeUNIX = $LiveMount.creationDate
$LiveMountSourceObject = $LiveMount.sourceDatabase.name
$LiveMountSourceObjectID = $LiveMount.sourceDatabase.id
$LiveMountIsReady = $TRUE
$LiveMountPath = "N/A"
# Host ID
$LiveMountHost = $LiveMount.targetOracleHost.name
$LiveMountHostID = $RSCHostList | Where-Object {$_.Host -eq $LiveMountHost} | Select-Object -ExpandProperty HostID -First 1
# Overriding if null and trying RAC
IF($LiveMountHost -eq $null)
{
$LiveMountHost = $LiveMount.targetOracleRac.name
$LiveMountHostID = $LiveMount.targetOracleRac.id
}
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
# Overiding snapshot as not available on API as of 08/17/23, don't want user to think it's a bug with the SDK!
$LiveMountSnapshotUTC = "NotAvailableOnAPI"
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "LiveMountID" -Value $LiveMountID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "OracleDatabase"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $LiveMountObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObject" -Value $LiveMountSourceObject
$Object | Add-Member -MemberType NoteProperty -Name "SourceObjectID" -Value $LiveMountSourceObjectID
$Object | Add-Member -MemberType NoteProperty -Name "Snapshot" -Value $LiveMountSnapshotUTC
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $LiveMountStatus
$Object | Add-Member -MemberType NoteProperty -Name "IsReady" -Value $LiveMountIsReady
$Object | Add-Member -MemberType NoteProperty -Name "MountPath" -Value $LiveMountPath
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