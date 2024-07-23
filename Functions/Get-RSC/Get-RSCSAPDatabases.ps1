################################################
# Function - Get-RSCSAPDatabases - Getting all SAP Databases connected to the RSC instance
################################################
Function Get-RSCSAPDatabases {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all SAP Databases.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSAPDatabases
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
# Getting SAP systems
$RSCSAPSystems = Get-RSCSAPSystems
################################################
# Getting All Objects 
################################################
# Creating array for objects
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "SapHanaDatabaseListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query SapHanaDatabaseListQuery(`$after: String, `$first: Int) {
  sapHanaDatabases(after: `$after, first: `$first) {
    edges {
      cursor
      node {
        cdmId
        id
        name
        isRelic
        slaPauseStatus
        ...EffectiveSlaColumnFragment
        info {
          logBackupIntervalSecs
          restoreConfiguredSrcDatabaseId
          __typename
        }
        logicalPath {
          fid
          name
          objectType
          __typename
        }
        replicatedObjectCount
        sapHanaSystem {
          id
          sid
          status
          hosts {
            hostType
            id: hostUuid
            hostName
            host {
              id
              __typename
            }
            __typename
          }
          __typename
        }
        effectiveSlaSourceObject {
          fid
          name
          objectType
          __typename
        }
        ...SlaAssignmentColumnFragment
        cluster {
          name
          id
          status
          version
          __typename
        }
        primaryClusterLocation {
          id
          name
          __typename
        }
        __typename
        dataPathSpec {
          name
        }
        dataPathType
        effectiveSlaDomain {
          id
          name
        }
        forceFull
        latestUserNote {
          objectId
          time
          userNote
          userName
        }
        logSnapshotConnection(first: 10, sortOrder: DESC) {
          nodes {
            date
          }
        }
        newestSnapshot {
          id
          date
        }
        newestArchivedSnapshot {
          id
          date
        }
        numWorkloadDescendants
        objectType
        oldestSnapshot {
          date
          id
        }
        onDemandSnapshotCount
        physicalPath {
          fid
          name
          objectType
        }
        newestReplicatedSnapshot {
          date
          id
        }
        protectionDate
        recoverableRangeConnection {
          edges {
            node {
              baseFullSnapshotId
              cdmId
              dbId
              clusterUuid
              endTime
              fid
              isArchived
              startTime
            }
          }
        }
        slaAssignment
        systemId
      }
      __typename
    }
    pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      __typename
    }
    __typename
  }
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
$RSCObjectList += $RSCObjectListResponse.data.sapHanaDatabases.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.sapHanaDatabases.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.sapHanaDatabases.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.sapHanaDatabases.edges.node
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
$DBSystemCDMID = $RSCDB.systemId
$DBForceFull = $RSCDB.forceFull
$DBIsRelic = $RSCDB.isRelic
$DBInfo = $RSCDB.info
$DBType = $RSCDB.objectType
# DB location
$DBLocation = $RSCSAPSystems | Where-Object {$_.SystemCDMID -eq $DBSystemCDMID}
$DBHostName = $DBLocation.System
$DBHostID = $DBLocation.SystemID
# Log backup info
$DBLogBackupFrequencySeconds = $DBInfo.logBackupIntervalSecs
$DBLogBackupFrequency = $DBLogBackupFrequencySeconds/60;$DBLogBackupFrequencyMinutes=[Math]::Round($DBLogBackupFrequencyMinutes)
$DBLogBackupFrequencyUnit = "MINUTES"
# Recovery range
$DBRecoverableRange = $RSCDB.recoverableRangeConnection.edges.node | Select-Object -Last 1
$DBRecoverableRangeStartUNIX = $DBRecoverableRange.startTime
$DBRecoverableRangeEndUNIX = $DBRecoverableRange.endTime
IF($DBRecoverableRangeStartUNIX -ne $null){$DBRecoverableRangeStartUTC = Convert-RSCUNIXTime $DBRecoverableRangeStartUNIX}ELSE{$DBRecoverableRangeStartUTC = $null}
IF($DBRecoverableRangeEndUNIX -ne $null){$DBRecoverableRangeEndUTC = Convert-RSCUNIXTime $DBRecoverableRangeEndUNIX}ELSE{$DBRecoverableRangeEndUTC = $null}
# Log snapshot
$DBLogSnapshots = $RSCDB.logSnapshotConnection.nodes
$DBLogSnapshotCount = $DBLogSnapshots | Measure-Object | Select-Object -ExpandProperty Count
$DBLastLogSnapshotUNIX = $DBLogSnapshots | Select-Object -ExpandProperty date -Last 1
IF($DBLastLogSnapshotUNIX -ne $null){$DBLastLogSnapshotUTC = Convert-RSCUNIXTime $DBLastLogSnapshotUNIX}ELSE{$DBLastLogSnapshotUTC = $null}
# Calculating minutes since last log backup
$UTCDateTime = [System.DateTime]::UtcNow
IF($DBLastLogSnapshotUTC -ne $null){$DBLastLogSnapshotTimepsan = New-TimeSpan -Start $DBLastLogSnapshotUTC -End $UTCDateTime;$DBLastLogSnapshotMinutesSince = $DBLastLogSnapshotTimepsan | Select-Object -ExpandProperty TotalMinutes;$DBLastLogSnapshotMinutesSince = [Math]::Round($DBLastLogSnapshotMinutesSince)}ELSE{$DBLastLogSnapshotMinutesSince = $null}
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
# Getting URL
$DBURL = Get-RSCObjectURL -ObjectType "SapHanaDatabase" -ObjectID $DBID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# DB info
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBName
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "DBCDMID" -Value $DBCDMID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $DBType
$Object | Add-Member -MemberType NoteProperty -Name "ForceFull" -Value $DBForceFull
# Log backups and recoverable ranges
$Object | Add-Member -MemberType NoteProperty -Name "LogBackups" -Value $DBLogSnapshotCount
$Object | Add-Member -MemberType NoteProperty -Name "LastLogBackupUTC" -Value $DBLastLogSnapshotUTC
$Object | Add-Member -MemberType NoteProperty -Name "MinutesSince" -Value $DBLastLogSnapshotMinutesSince
$Object | Add-Member -MemberType NoteProperty -Name "RecoverableRangeStart" -Value $DBRecoverableRangeStartUTC
$Object | Add-Member -MemberType NoteProperty -Name "RecoverableRangeEnd" -Value $DBRecoverableRangeEndUTC
# Location information
$Object | Add-Member -MemberType NoteProperty -Name "System" -Value $DBHostName
$Object | Add-Member -MemberType NoteProperty -Name "SystemID" -Value $DBHostID
$Object | Add-Member -MemberType NoteProperty -Name "SystemCDMID" -Value $DBSystemCDMID
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $DBSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $DBSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $DBSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $DBSLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $DBIsRelic
# Log backup info
$Object | Add-Member -MemberType NoteProperty -Name "LogFrequency" -Value $DBLogBackupFrequency
$Object | Add-Member -MemberType NoteProperty -Name "LogFrequencyUnit" -Value $DBLogBackupFrequencyUnit
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
# Rubrik cluster info
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $DBRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $DBRubrikClusterID
# URL
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