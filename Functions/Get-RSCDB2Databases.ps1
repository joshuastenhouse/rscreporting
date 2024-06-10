################################################
# Function - Get-RSCDB2Databases - Getting all DB2 Databases connected to the RSC instance
################################################
Function Get-RSCDB2Databases {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all DB2 databases.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCDB2Databases
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
# Getting SLA domains
$RSCSLADomains = Get-RSCSLADomains
# Getting DB2 instances
$RSCDB2Instances = Get-RSCDB2Instances
################################################
# Getting Objects 
################################################
# Creating array for objects
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "Db2DatabaseListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query Db2DatabaseListQuery(`$first: Int!, `$after: String) {
  db2Databases(first: `$first, after: `$after) {
    count
    edges {
      cursor
      node {
        id
        name
        isRelic
        slaPauseStatus
        db2DbType
        db2Instance {
          id
          name
          __typename
        }
        ...CdmClusterColumnFragment
        ... on HierarchyObject {
          ...EffectiveSlaColumnFragment
          __typename
        }
        ...SlaAssignmentColumnFragment
        __typename
        cdmId
        db2HadrMetadata {
          instancesInfoList {
            db2Instance {
              id
              cdmId
              name
            }
          }
        }
        latestUserNote {
          time
          userNote
          userName
          objectId
        }
        objectType
        newestArchivedSnapshot {
          id
          date
        }
        effectiveSlaDomain {
          id
          name
        }
        lastSyncTime
        logBackupThreshold
        logSnapshots {
          edges {
            node {
              date
              fid
              cdmId
            }
          }
        }
        logicalPath {
          fid
          objectType
          name
        }
        slaAssignment
        replicatedObjectCount
        protectionDate
        physicalPath {
          fid
          name
          objectType
        }
        onDemandSnapshotCount
        oldestSnapshot {
          date
          id
        }
        newestSnapshot {
          date
          id
        }
        newestReplicatedSnapshot {
          date
          id
        }
        primaryClusterLocation {
          id
          name
          clusterUuid
        }
        recoverableRanges {
          edges {
            node {
              startTime
              endTime
              dbId
              cdmId
              fid
              isArchived
            }
          }
        }
        reportWorkload {
          archiveSnapshots
          archiveStorage
          awaitingFirstFull
          complianceStatus
          dataReduction
          lastSnapshotLogicalBytes
          localEffectiveStorage
          localMeteredData
          localOnDemandSnapshots
          localProtectedData
          localSnapshots
          localSlaSnapshots
          localStorage
          logicalDataReduction
          logicalBytes
          physicalBytes
          protectionStatus
          provisionedBytes
          replicaSnapshots
          protectedOn
          replicaStorage
          replicationSnapshotLag
          name
          missedSnapshots
          totalSnapshots
          usedBytes
          transferredBytes
        }
        snapshotDistribution {
          onDemandCount
          totalCount
          scheduledCount
          retrievedCount
        }
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

fragment CdmClusterColumnFragment on CdmHierarchyObject {
  replicatedObjectCount
  cluster {
    id
    name
    version
    status
    __typename
  }
  __typename
}

fragment EffectiveSlaColumnFragment on HierarchyObject {
  id
  effectiveSlaDomain {
    ...EffectiveSlaDomainFragment
    ... on GlobalSlaReply {
      description
      __typename
    }
    __typename
  }
  ... on CdmHierarchyObject {
    pendingSla {
      ...SLADomainFragment
      __typename
    }
    __typename
  }
  __typename
}

fragment EffectiveSlaDomainFragment on SlaDomain {
  id
  name
  ... on GlobalSlaReply {
    isRetentionLockedSla
    __typename
  }
  ... on ClusterSlaDomain {
    fid
    cluster {
      id
      name
      __typename
    }
    isRetentionLockedSla
    __typename
  }
  __typename
}

fragment SLADomainFragment on SlaDomain {
  id
  name
  ... on ClusterSlaDomain {
    fid
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  __typename
}

fragment SlaAssignmentColumnFragment on HierarchyObject {
  slaAssignment
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListResponse.data.db2Databases.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.db2Databases.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.db2Databases.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.db2Databases.edges.node
}
################################################
# Processing DBs
################################################
# Creating array
$RSCDBs = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCDB in $RSCObjectList)
{
# Setting variables
$DBName = $RSCDB.name
$DBID = $RSCDB.id
$DBCDMID = $RSCDB.cdmId
$DBReplicas = $RSCDB.replicatedObjectCount
$DBIsRelic = $RSCDB.isRelic
$DBType = $RSCDB.objectType
# SLA info
$DBSLADomainInfo = $RSCDB.effectiveSlaDomain
$DBSLADomain = $DBSLADomainInfo.name
$DBSLADomainID = $DBSLADomainInfo.id
$DBSLAAssignment = $RSCDB.slaAssignment
$DBSLAPaused = $RSCDB.slaPauseStatus
# Rubrik cluster info
$DBRubrikClusterInfo = $RSCDB.primaryClusterLocation
$DBRubrikCluster = $DBRubrikClusterInfo.name
$DBRubrikClusterID = $DBRubrikClusterInfo.id
# User note info
$DBNoteInfo = $RSCDB.latestUserNote
$DbNote = $DBNoteInfo.userNote
$DBNoteCreator = $DBNoteInfo.userName
$DBNoteCreatedUNIX = $DBNoteInfo.time
IF($DBNoteCreatedUNIX -ne $null){$DBNoteCreatedUTC = Convert-RSCUNIXTime $DBNoteCreatedUNIX}ELSE{$DBNoteCreatedUTC = $null}
# DB location
$DBInstanceID = $RSCDB.physicalPath.fid
$DBInstance = $RSCDB.physicalPath.name
$DBHostInfo = $RSCDB2Instances | Where-Object {$_.InstanceID -eq "$DBInstanceID"} | Select-Object -First 1
$DBHostName = $DBHostInfo.Host
$DBHostID = $DBHostInfo.HostID
# DB snapshot info
$DBOnDemandSnapshots = $RSCDB.onDemandSnapshotCount
$DBSnapshotDateUNIX = $RSCDB.newestSnapshot.date
$DBSnapshotDateID = $RSCDB.newestSnapshot.id
$DBReplicatedSnapshotDateUNIX = $RSCDB.newestReplicatedSnapshot.date
$DBReplicatedSnapshotDateID = $RSCDB.newestReplicatedSnapshot.id
$DBArchiveSnapshotDateUNIX = $RSCDB.newestArchivedSnapshot.date
$DBArchiveSnapshotDateID = $RSCDB.newestArchivedSnapshot.id
$DBOldestSnapshotDateUNIX = $RSCDB.oldestSnapshot.date
$DBOldestSnapshotDateID = $RSCDB.oldestSnapshot.id
# Converting snapshot dates
IF($DBSnapshotDateUNIX -ne $null){$DBSnapshotDateUTC = Convert-RSCUNIXTime $DBSnapshotDateUNIX}ELSE{$DBSnapshotDateUTC = $null}
IF($DBReplicatedSnapshotDateUNIX -ne $null){$DBReplicatedSnapshotDateUTC = Convert-RSCUNIXTime $DBReplicatedSnapshotDateUNIX}ELSE{$DBSnDBReplicatedSnapshotDateUTCapshotDateUTC = $null}
IF($DBArchiveSnapshotDateUNIX -ne $null){$DBArchiveSnapshotDateUTC = Convert-RSCUNIXTime $DBArchiveSnapshotDateUNIX}ELSE{$DBArchiveSnapshotDateUTC = $null}
IF($DBOldestSnapshotDateUNIX -ne $null){$DBOldestSnapshotDateUTC = Convert-RSCUNIXTime $DBOldestSnapshotDateUNIX}ELSE{$DBOldestSnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($DBSnapshotDateUTC -ne $null){$DBSnapshotTimespan = New-TimeSpan -Start $DBSnapshotDateUTC -End $UTCDateTime;$DBSnapshotHoursSince = $DBSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$DBSnapshotHoursSince = [Math]::Round($DBSnapshotHoursSince,1)}ELSE{$DBSnapshotHoursSince = $null}
IF($DBReplicatedSnapshotDateUTC -ne $null){$DBReplicatedSnapshotTimespan = New-TimeSpan -Start $DBReplicatedSnapshotDateUTC -End $UTCDateTime;$DBReplicatedSnapshotHoursSince = $DBReplicatedSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$DBReplicatedSnapshotHoursSince = [Math]::Round($DBReplicatedSnapshotHoursSince,1)}ELSE{$DBReplicatedSnapshotHoursSince = $null}
IF($DBArchiveSnapshotDateUTC -ne $null){$DBArchiveSnapshotTimespan = New-TimeSpan -Start $DBArchiveSnapshotDateUTC -End $UTCDateTime;$DBArchiveSnapshotHoursSince = $DBArchiveSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$DBArchiveSnapshotHoursSince = [Math]::Round($DBArchiveSnapshotHoursSince,1)}ELSE{$DBArchiveSnapshotHoursSince = $null}
IF($DBOldestSnapshotDateUTC -ne $null){$DBOldestSnapshotTimespan = New-TimeSpan -Start $DBOldestSnapshotDateUTC -End $UTCDateTime;$DBOldestSnapshotDaysSince = $DBOldestSnapshotTimespan | Select-Object -ExpandProperty TotalDays;$DBOldestSnapshotDaysSince = [Math]::Round($DBOldestSnapshotDaysSince,1)}ELSE{$DBOldestSnapshotDaysSince = $null}
# Reporting data
$DBReportInfo = $RSCDB.reportWorkload
$DBWaitingForFirstFull = $DBReportInfo.awaitingFirstFull
$DBProvisionedBytes = $DBReportInfo.localProtectedData
$DBProtectedBytes = $DBReportInfo.localProtectedData
$DBLocalUsedBytes = $DBReportInfo.localStorage
$DBReplicaUsedBytes = $DBReportInfo.replicaStorage
$DBArchiveUsedBytes = $DBReportInfo.archiveStorage
$DBLocalSnapshots = $DBReportInfo.localSnapshots
$DBReplicaSnapshots = $DBReportInfo.replicaSnapshots
$DBArchiveSnapshots = $DBReportInfo.archiveSnapshots
# Converting storage units
IF($DBProvisionedBytes -ne $null){$DBProvisionedGB = $DBProvisionedBytes / 1000 / 1000 / 1000;$DBProvisionedGB = [Math]::Round($DBProvisionedGB,2)}ELSE{$DBProvisionedGB = $null}
IF($DBProtectedBytes -ne $null){$DBProtectedGB = $DBProtectedBytes / 1000 / 1000 / 1000;$DBProtectedGB = [Math]::Round($DBProtectedGB,2)}ELSE{$DBProtectedGB = $null}
IF($DBLocalUsedBytes -ne $null){$DBLocalUsedGB = $DBLocalUsedBytes / 1000 / 1000 / 1000;$DBLocalUsedGB = [Math]::Round($DBLocalUsedGB,2)}ELSE{$DBLocalUsedGB = $null}
IF($DBReplicaUsedBytes -ne $null){$DBReplicaUsedGB = $DBReplicaUsedBytes / 1000 / 1000 / 1000;$DBReplicaUsedGB = [Math]::Round($DBReplicaUsedGB,2)}ELSE{$DBReplicaUsedGB = $null}
IF($DBArchiveUsedBytes -ne $null){$DBArchiveUsedGB = $DBArchiveUsedBytes / 1000 / 1000 / 1000;$DBArchiveUsedGB = [Math]::Round($DBArchiveUsedGB,2)}ELSE{$DBArchiveUsedGB = $null}
# Calculating dedupe for storage jockeys
IF(($DBProtectedBytes -gt 1) -and ($DBLocalSnapshots -gt 1)){$DBDedupeRatio = $DBProtectedBytes * $DBLocalSnapshots / $DBLocalUsedBytes;$DBDedupeRatio = [Math]::Round($DBDedupeRatio,2)}ELSE{$DBDedupeRatio = $null}
# Creating URL
$DBURL = Get-RSCObjectURL -ObjectType "Db2Database" -ObjectID $DBID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# DB info
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBName
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "DBCDMID" -Value $DBCDMID
$Object | Add-Member -MemberType NoteProperty -Name "DBType" -Value $DBType
$Object | Add-Member -MemberType NoteProperty -Name "Replicas" -Value $DBReplicas
# Location information
$Object | Add-Member -MemberType NoteProperty -Name "Instance" -Value $DBInstance
$Object | Add-Member -MemberType NoteProperty -Name "InstanceID" -Value $DBInstanceID
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $DBHostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $DBHostID
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $DBSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $DBSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $DBSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $DBSLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $DBIsRelic
# Snapshot dates
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTC" -Value $DBSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTCAgeHours" -Value $DBSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshotUTC" -Value $DBReplicatedSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshotUTCAgeHours" -Value $DBReplicatedSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshotUTC" -Value $DBArchiveSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshotUTCAgeHours" -Value $DBArchiveSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTC" -Value $DBOldestSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTCAgeDays" -Value $DBOldestSnapshotDaysSince
# DB note info
$Object | Add-Member -MemberType NoteProperty -Name "LatestRSCNote" -Value $DBNote
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteCreator" -Value $DBNoteCreator
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteDateUTC" -Value $DBNoteCreatedUTC
# Storage usage
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedGB" -Value $DBProvisionedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedGB" -Value $DBProtectedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalUsedGB" -Value $DBLocalUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaUsedGB" -Value $DBReplicaUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveUsedGB" -Value $DBArchiveUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "DedupeRatio" -Value $DBDedupeRatio
# Rubrik cluster info
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $DBRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $DBRubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $DBURL
# Adding
$RSCDBs.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCDBs
# End of function
}