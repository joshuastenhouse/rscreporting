################################################
# Function - Get-RSCMSSQLDatabases - Getting all Microsoft SQL Databases connected to the RSC instance
################################################
Function Get-RSCMSSQLDatabases {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all MSSQL databases.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCMSSQLDatabases
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
Param
    (
        [Parameter(ParameterSetName="User")][switch]$DisableLogging,
        [Parameter(Mandatory=$false)]$ObjectQueryLimit
    )
################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting SLA domains
$RSCSLADomains = Get-RSCSLADomains
# Setting first value if null
IF($ObjectQueryLimit -eq $null){$ObjectQueryLimit = 1000}
################################################
# Getting All RSCMSSQLDatabases 
################################################
# Creating array for objects
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "MssqlDatabaseListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query MssqlDatabaseListQuery(`$first: Int, `$after: String, `$sortBy: HierarchySortByField) {
  mssqlDatabases(first: `$first, after: `$after, sortBy: `$sortBy) {
    edges {
      node {
        cdmId
        id
        name
        dagId
        copyOnly
        hasPermissions
        hasLogConfigFromSla
        isInAvailabilityGroup
        isLogShippingSecondary
        isMount
        isOnline
        isRelic
        objectType
        postBackupScript
        preBackupScript
        recoveryModel
        slaPauseStatus
        unprotectableReasons
        logBackupRetentionInHours
        logBackupFrequencyInSeconds
        latestUserNote {
          time
          userName
          userNote
        }
        onDemandSnapshotCount
        physicalPath {
          fid
          objectType
          name
        }
        cdmNewestSnapshot {
          date
          id
        }
        cdmOldestSnapshot {
          id
          date
        }
        primaryClusterLocation {
          clusterUuid
          id
          name
        }
        effectiveSlaDomain {
          id
          name
        }
        newestReplicatedSnapshot {
          date
          id
        }
        newestArchivedSnapshot {
          date
          id
        }
        oldestSnapshot {
          id
          date
        }
        replicas {
          availabilityInfo {
            availabilityMode
            replicaId
            role
          }
          clusterUuid
          instance {
            id
            name
          }
          isArchived
          isStandBy
          recoveryModel
          snapshotNeeded
          state
        }
        replicatedObjectCount
        slaAssignment
      }
    }
    pageInfo {
      endCursor
      hasNextPage
      startCursor
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Logging
Write-Host "QueryingAPI: MssqlDatabaseListQuery"
# Querying API
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListResponse.data.mssqlDatabases.edges.node
# Counters
$ObjectCount = 0
$ObjectCounter = $ObjectCount + $ObjectQueryLimit
# Getting all results from paginations
While($RSCObjectListResponse.data.mssqlDatabases.pageInfo.hasNextPage) 
{
# Logging
IF($DisableLogging){}ELSE{Write-Host "GettingObjects: $ObjectCount-$ObjectCounter"}
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.mssqlDatabases.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.mssqlDatabases.edges.node
# Incrementing
$ObjectCount = $ObjectCount + $ObjectQueryLimit
$ObjectCounter = $ObjectCounter + $ObjectQueryLimit
}
# Processing VMs
Write-Host "Processing MSSQL DBs.."
################################################
# Processing DBs
################################################
# Creating array
$RSCDBs = [System.Collections.ArrayList]@()
# Counting
$RSCObjectsCount = $RSCObjectList | Measure-Object | Select-Object -ExpandProperty Count
$RSCObjectsCounter = 0
# For Each Object Getting Data
ForEach ($RSCDB in $RSCObjectList)
{
# Logging
$RSCObjectsCounter ++
IF($DisableLogging){}ELSE{Write-Host "ProcessingObject: $RSCObjectsCounter/$RSCObjectsCount"}
# Setting variables
$DBName = $RSCDB.name
$DBID = $RSCDB.id
$DBCDMID = $RSCDB.cdmId
$DBDAGID = $RSCDB.dagId
$DBHasPermissions = $RSCDB.hasPermissions
$DBIsOnline = $RSCDB.isOnline
$DBIsRelic = $RSCDB.isRelic
$DBUserNote = $RSCDB.latestUserNote
$DBInAvailabilityGroup = $RSCDB.isInAvailabilityGroup
$DBRecoveryModel = $RSCDB.recoveryModel
$DBIsLiveMount = $RSCDB.isMount
$DBHasLogConfigFromSLA = $RSCDB.hasLogConfigFromSla
$DBRubrikClusterInfo = $RSCDB.primaryClusterLocation
$DBRubrikCluster = $DBRubrikClusterInfo.name
$DBRubrikClusterID = $DBRubrikClusterInfo.id
$DBReplicas = $RSCDB.replicatedObjectCount
$DBCopyOnly = $RSCDB.copyOnly
$DBIsLogShippingSecondary = $RSCDB.isLogShippingSecondary
# User note info
$DBNoteInfo = $RSCDB.latestUserNote
$DbNote = $DBNoteInfo.userNote
$DBNoteCreator = $DBNoteInfo.userName
$DBNoteCreatedUNIX = $DBNoteInfo.time
IF($DBNoteCreatedUNIX -ne $null){$DBNoteCreatedUTC = Convert-RSCUNIXTime $DBNoteCreatedUNIX}ELSE{$DBNoteCreatedUTC = $null}
# DB location
$DBPhysicalPaths = $RSCDB.physicalPath
$DBInstanceInfo = $DBPhysicalPaths | Where-Object {$_.objectType -eq "MssqlInstance"} | Select-Object -First 1
$DBInstanceName = $DBInstanceInfo.name
$DBInstanceID = $DBInstanceInfo.fid
$DBDAGInfo = $DBPhysicalPaths | Where-Object {$_.objectType -eq "MssqlAvailabilityGroup"} | Select-Object -First 1
$DBDAGName = $DBDAGInfo.name
$DBHostInfo = $DBPhysicalPaths | Where-Object {$_.objectType -eq "PhysicalHost"} | Select-Object -First 1
$DBHostName = $DBHostInfo.name
$DBHostID = $DBHostInfo.fid
# Counts
$DBDAGCopies = $DBPhysicalPaths | Where-Object {$_.objectType -eq "PhysicalHost"} | Measure-Object | Select-Object -ExpandProperty Count
# SLA info
$DBSLADomainInfo = $RSCDB.effectiveSlaDomain
$DBSLADomain = $DBSLADomainInfo.name
$DBSLADomainID = $DBSLADomainInfo.id
$DBSLAAssignment = $RSCDB.slaAssignment
$DBSLAPaused = $RSCDB.slaPauseStatus
# DB snapshot info
$DBOnDemandSnapshots = $RSCDB.onDemandSnapshotCount
$DBSnapshotDateUNIX = $RSCDB.cdmnewestSnapshot.date
$DBSnapshotDateID = $RSCDB.cdmnewestSnapshot.id
$DBReplicatedSnapshotDateUNIX = $RSCDB.newestReplicatedSnapshot.date
$DBReplicatedSnapshotDateID = $RSCDB.newestReplicatedSnapshot.id
$DBArchiveSnapshotDateUNIX = $RSCDB.newestArchivedSnapshot.date
$DBArchiveSnapshotDateID = $RSCDB.newestArchivedSnapshot.id
$DBOldestSnapshotDateUNIX = $RSCDB.cdmoldestSnapshot.date
$DBOldestSnapshotDateID = $RSCDB.cdmoldestSnapshot.id
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
# Scripting
$DBPreBackupScriptInfo = $RSCDB.preBackupScript
$DBPostBackupScriptInfo = $RSCDB.postBackupScript
IF($DBPreBackupScriptInfo -eq ""){$DBPreBackupScriptEnabled = $FALSE}ELSE{$DBPreBackupScriptEnabled = $TRUE}
IF($DBPostBackupScriptInfo -eq ""){$DBPostBackupScriptEnabled = $FALSE}ELSE{$DBPostBackupScriptEnabled = $TRUE}
# Getting log backup info
IF($DBHasLogConfigFromSLA -eq $TRUE)
{
$DBSLADomainLogInfo = $RSCSLADomains | Where-Object {$_.SLADomainID -eq $DBSLADomainID} | Select-Object -First 1
$DBLogBackupFrequency = $DBSLADomainLogInfo.MSSQLLogFrequency
$DBLogBackupFrequencyUnit = $DBSLADomainLogInfo.MSSQLLogFrequencyUnit
$DBLogBackupRetention = $DBSLADomainLogInfo.MSSQLLogRetention
$DBLogBackupRetentionUnit = $DBSLADomainLogInfo.MSSQLLogRetentionUnit
}
ELSE
{
$DBLogBackupFrequency = $RSCDB.logBackupFrequencyInSeconds / 60;$DBLogBackupFrequency = [Math]::Round($DBLogBackupFrequency)
$DBLogBackupFrequencyUnit = "MINUTES"
IF($RSCDB.logBackupRetentionInHours -ge 24){$DBLogBackupRetention = $RSCDB.logBackupRetentionInHours / 24;$DBLogBackupRetention = [Math]::Round($DBLogBackupRetention);$DBLogBackupRetentionUnit = "DAYS"}
IF($RSCDB.logBackupRetentionInHours -lt 24){$DBLogBackupRetention = $RSCDB.logBackupRetentionInHours;$DBLogBackupRetention = [Math]::Round($DBLogBackupRetention);$DBLogBackupRetentionUnit = "HOURS"}
}
# If log config still null, must be a local SLA, querying API for log config
IF(($DBHasLogConfigFromSLA -eq $TRUE) -and ($DBRecoveryModel -eq "FULL") -and ($DBSLADomainLogInfo -eq $null))
{
$DBSLADomainLogConfig = Get-RSCSLADomainsLogSettings -SLADomainID $DBSLADomainID
$DBLogBackupFrequency = $DBSLADomainLogConfig.MSSQLLogFrequency
$DBLogBackupFrequencyUnit = $DBSLADomainLogConfig.MSSQLLogFrequencyUnit
$DBLogBackupRetention = $DBSLADomainLogConfig.MSSQLLogRetention
$DBLogBackupRetentionUnit = $DBSLADomainLogConfig.MSSQLLogRetentionUnit
}
# Getting URL
$DBURL = Get-RSCObjectURL -ObjectType "Mssql" -ObjectID $DBID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# DB info
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBName
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "DBCDMID" -Value $DBCDMID
$Object | Add-Member -MemberType NoteProperty -Name "Online" -Value $DBIsOnline
$Object | Add-Member -MemberType NoteProperty -Name "InDAG" -Value $DBInAvailabilityGroup
$Object | Add-Member -MemberType NoteProperty -Name "DAGID" -Value $DBDAGID
$Object | Add-Member -MemberType NoteProperty -Name "DBCopies" -Value $DBDAGCopies
$Object | Add-Member -MemberType NoteProperty -Name "HasPermissions" -Value $DBHasPermissions
$Object | Add-Member -MemberType NoteProperty -Name "IsLiveMount" -Value $DBIsLiveMount
$Object | Add-Member -MemberType NoteProperty -Name "CopyOnly" -Value $DBCopyOnly
$Object | Add-Member -MemberType NoteProperty -Name "IsLogShippingSecondary" -Value $DBIsLogShippingSecondary
# Location information
$Object | Add-Member -MemberType NoteProperty -Name "Instance" -Value $DBInstanceName
$Object | Add-Member -MemberType NoteProperty -Name "InstanceID" -Value $DBInstanceID
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $DBHostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $DBHostID
$Object | Add-Member -MemberType NoteProperty -Name "DAG" -Value $DBDAGName
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $DBSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $DBSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $DBSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $DBSLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $DBIsRelic
# Log backup info
$Object | Add-Member -MemberType NoteProperty -Name "RecoveryModel" -Value $DBRecoveryModel
$Object | Add-Member -MemberType NoteProperty -Name "LogConfigFromSLA" -Value $DBHasLogConfigFromSLA
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
# Misc info
$Object | Add-Member -MemberType NoteProperty -Name "PreBackupScript" -Value $DBPreBackupScriptEnabled
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScript" -Value $DBPostBackupScriptEnabled
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