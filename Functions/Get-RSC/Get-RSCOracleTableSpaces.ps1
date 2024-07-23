################################################
# Function - Get-RSCOracleTableSpaces - Getting all Microsoft SQL Databases connected to the RSC instance
################################################
Function Get-RSCOracleTableSpaces {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all Oracle Table Spaces.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCOracleTableSpaces
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
################################################
# Getting All RSCMSSQLDatabases 
################################################
# Creating array for objects
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "OracleDatabasesListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query OracleDatabasesListQuery(`$first: Int!, `$after: String, `$filter: [Filter!], `$isMultitenancyEnabled: Boolean = false) {
  oracleDatabases(after: `$after, first: `$first, filter: `$filter) {
    edges {
      cursor
      node {
        id
        dbUniqueName
        objectType
        dataGuardGroup {
          id
          dbUniqueName
          __typename
        }
        dataGuardType
        isRelic
        dbRole
        logBackupFrequency
        hostLogRetentionHours
        logRetentionHours
        numInstances
        objectType
        numChannels
        sectionSizeInGigabytes
        effectiveSlaDomain {
          objectSpecificConfigs {
            oracleConfig {
              frequency {
                duration
                unit
                __typename
              }
              __typename
            }
            __typename
          }
          ...EffectiveSlaDomainFragment
          ... on GlobalSlaReply {
            description
            __typename
          }
          __typename
        }
        ...HierarchyObjectNameColumnFragment
        ...HierarchyObjectLocationColumnFragment
        ...EffectiveSlaColumnFragment
        ...SlaAssignmentColumnFragment
        ...CdmClusterColumnFragment
        ...OrganizationsColumnFragment @include(if: `$isMultitenancyEnabled)
        ...CdmClusterLabelFragment
        ...DatabaseTablespacesColumnFragment
        __typename
        cdmId
        directoryPaths {
          archiveDests
        }
        isLiveMount
        instances {
          hostId
          instanceName
        }
        lastValidationResult {
          eventId
          timestampMs
          snapshotId
          isSuccess
        }
        latestUserNote {
          objectId
          userNote
          userName
          time
        }
        newestReplicatedSnapshot {
          id
          date
        }
        newestArchivedSnapshot {
          date
        }
        name
        newestSnapshot {
          date
          id
        }
        numTablespaces
        oldestSnapshot {
          date
          id
        }
        numLogSnapshots
        onDemandSnapshotCount
        pdbs {
          applicationRootContainerId
          id
          dbId
          openMode
          name
          isApplicationRoot
          isApplicationPdb
        }
        physicalPath {
          fid
          objectType
          name
        }
        primaryClusterLocation {
          name
          clusterUuid
          id
        }
        slaPauseStatus
        slaAssignment
        replicatedObjectCount
        tablespaces
        archiveLogMode
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

fragment OrganizationsColumnFragment on HierarchyObject {
  allOrgs {
    name
    __typename
  }
  __typename
}

fragment HierarchyObjectNameColumnFragment on HierarchyObject {
  name
  __typename
}

fragment HierarchyObjectLocationColumnFragment on HierarchyObject {
  logicalPath {
    name
    objectType
    __typename
  }
  physicalPath {
    name
    objectType
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

fragment CdmClusterLabelFragment on CdmHierarchyObject {
  cluster {
    id
    name
    version
    __typename
  }
  primaryClusterLocation {
    id
    __typename
  }
  __typename
}

fragment DatabaseTablespacesColumnFragment on OracleDatabase {
  numTablespaces
  __typename
}
"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListResponse.data.oracleDatabases.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.oracleDatabases.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.oracleDatabases.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.oracleDatabases.edges.node
}
################################################
# Processing DBs
################################################
# Creating array
$RSCDBs = [System.Collections.ArrayList]@()
$RSCPDBs = [System.Collections.ArrayList]@()
$RSCTableSpaces = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCDB in $RSCObjectList)
{
# Setting variables
$DBName = $RSCDB.name
$DBID = $RSCDB.id
$DBCDMID = $RSCDB.cdmId
$DBRole = $RSCDB.dbRole
$DBIsLiveMount = $RSCDB.isLiveMount
$DBArchiveLogMode = $RSCDB.archiveLogMode
$DBReplicas = $RSCDB.replicatedObjectCount
$DBIsRelic = $RSCDB.isRelic
$DBInstances = $RSCDB.numInstances
$DBChannels = $RSCDB.numChannels
# SLA info
$DBSLADomainInfo = $RSCDB.effectiveSlaDomain
$DBSLADomain = $DBSLADomainInfo.name
$DBSLADomainID = $DBSLADomainInfo.id
$DBSLAAssignment = $RSCDB.slaAssignment
$DBSLAPaused = $RSCDB.slaPauseStatus
# Log backup info
$DBLogBackupFrequency = $RSCDB.logBackupFrequency
$DBLogBackupFrequencyUnit = "MINUTES"
$DBLogRetentionFrequency = $RSCDB.logRetentionHours
$DBLogRetentionFrequencyUnit = "HOURS"
$DBHostLogRetentionFrequency = $RSCDB.hostLogRetentionHours
$DBHostLogRetentionFrequencyUnit = "HOURS"
# Overriding log backup with SLA settings, if present
$DBSLADomainLogBackupSettings = $RSCSLADomains | Where-Object {$_.SLADomainID -eq $DBSLADomainID} 
IF($DBSLADomainLogBackupSettings -ne $null)
{
$DBLogBackupFrequency = $DBSLADomainLogBackupSettings.MSSQLLogFrequency
$DBLogBackupFrequencyUnit = $DBSLADomainLogBackupSettings.MSSQLLogFrequencyUnit
$DBLogBackupRetention = $DBSLADomainLogBackupSettings.MSSQLLogRetention
$DBLogBackupRetentionUnit = $DBSLADomainLogBackupSettings.MSSQLLogRetentionUnit
}
# If not in SLA list, might be a cluster SLA, checking there too if still null
IF($DBSLADomainLogBackupSettings -eq $null)
{
$DBSLADomainLogBackupSettings = Get-RSCSLADomainsLogSettings -SLADomainID $DBSLADomainID
IF($DBSLADomainLogBackupSettings -ne $null)
{
$DBLogBackupFrequency = $DBSLADomainLogBackupSettings.OracleLogFrequency
$DBLogBackupFrequencyUnit = $DBSLADomainLogBackupSettings.OracleLogFrequencyUnit
$DBLogBackupRetention = $DBSLADomainLogBackupSettings.OracleLogRetention
$DBLogBackupRetentionUnit = $DBSLADomainLogBackupSettings.OracleLogRetentionUnit
}
}
# Rubrik cluster info
$DBRubrikClusterInfo = $RSCDB.primaryClusterLocation
$DBRubrikCluster = $DBRubrikClusterInfo.name
$DBRubrikClusterID = $DBRubrikClusterInfo.id
# Dataguard info
$DBDataGuardType = $RSCDB.dataGuardType
$DBDataGuardGroup = $RSCDB.dataGuardGroup
# User note info
$DBNoteInfo = $RSCDB.latestUserNote
$DbNote = $DBNoteInfo.userNote
$DBNoteCreator = $DBNoteInfo.userName
$DBNoteCreatedUNIX = $DBNoteInfo.time
IF($DBNoteCreatedUNIX -ne $null){$DBNoteCreatedUTC = Convert-RSCUNIXTime $DBNoteCreatedUNIX}ELSE{$DBNoteCreatedUTC = $null}
# DB location
$DBPhysicalPaths = $RSCDB.physicalPath
$DBHostInfo = $DBPhysicalPaths | Where-Object {$_.objectType -eq "OracleHost"} | Select-Object -First 1
$DBHostName = $DBHostInfo.name
$DBHostID = $DBHostInfo.fid
# PDBs
$DBPDBs = $RSCDB.pdbs
$DBPDBCount = $DBPDBs | Measure-Object | Select-Object -ExpandProperty Count
ForEach($DBPDB in $DBPDBs)
{
# Assigning variables
$PDBContainerID = $DBPDB.applicationRootContainerId
$PDBID = $DBPDB.id
$PDBDBID = $DBPDB.dbId
$PDBOpenMode = $DBPDB.openMode
$PDBName = $DBPDB.name
$PDBIsAppRoot = $DBPDB.isApplicationRoot
$PDBIsAppPdb = $DBPDB.isApplicationPdb
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "PDB" -Value $PDBName
$Object | Add-Member -MemberType NoteProperty -Name "PDBID" -Value $PDBID
$Object | Add-Member -MemberType NoteProperty -Name "PDBDBID" -Value $PDBDBID
$Object | Add-Member -MemberType NoteProperty -Name "ContainerID" -Value $PDBContainerID
$Object | Add-Member -MemberType NoteProperty -Name "OpenMode" -Value $PDBOpenMode
$Object | Add-Member -MemberType NoteProperty -Name "PDBIsAppRoot" -Value $PDBIsAppRoot
$Object | Add-Member -MemberType NoteProperty -Name "PDBIsAppPdb" -Value $PDBIsAppPdb
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBName
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "DBCDMID" -Value $DBCDMID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $DBSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $DBSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $DBSLAAssignment
$RSCPDBs.Add($Object) | Out-Null
}
# Getting URL
$DBURL = Get-RSCObjectURL -ObjectType "OracleDatabase" -ObjectID $DBID
# Tablespaces
$DBTableSpaces = $RSCDB.Tablespaces
$DBTableSpacesCount = $RSCDB.numTablespaces
ForEach($DBTableSpace in $DBTableSpaces)
{
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "TableSpace" -Value $DBTableSpace
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBName
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "DBCDMID" -Value $DBCDMID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $DBSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $DBSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $DBSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $DBURL
$RSCTableSpaces.Add($Object) | Out-Null
}
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
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# DB info
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBName
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "DBCDMID" -Value $DBCDMID
$Object | Add-Member -MemberType NoteProperty -Name "Role" -Value $DBRole
$Object | Add-Member -MemberType NoteProperty -Name "DataGuard" -Value $DBDataGuardType
$Object | Add-Member -MemberType NoteProperty -Name "DataGuardGroup" -Value $DBDataGuardGroup
$Object | Add-Member -MemberType NoteProperty -Name "IsLiveMount" -Value $DBIsLiveMount
$Object | Add-Member -MemberType NoteProperty -Name "Replicas" -Value $DBReplicas
$Object | Add-Member -MemberType NoteProperty -Name "Instances" -Value $DBInstances
$Object | Add-Member -MemberType NoteProperty -Name "Channels" -Value $DBChannels
$Object | Add-Member -MemberType NoteProperty -Name "PDBs" -Value $DBPDBCount
$Object | Add-Member -MemberType NoteProperty -Name "TableSpaces" -Value $DBTableSpacesCount
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $DBSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $DBSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $DBSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $DBSLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $DBIsRelic
# Log backup info
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveLogMode" -Value $DBArchiveLogMode
$Object | Add-Member -MemberType NoteProperty -Name "LogFrequency" -Value $DBLogBackupFrequency
$Object | Add-Member -MemberType NoteProperty -Name "LogFrequencyUnit" -Value $DBLogBackupFrequencyUnit
$Object | Add-Member -MemberType NoteProperty -Name "LogRetention" -Value $DBLogBackupRetention
$Object | Add-Member -MemberType NoteProperty -Name "LogRetentionUnit" -Value $DBLogBackupRetentionUnit
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
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $DBRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $DBRubrikClusterID
# Location information
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $DBHostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $DBHostID
# Adding
$RSCDBs.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCTableSpaces
# End of function
}