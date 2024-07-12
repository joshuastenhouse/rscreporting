################################################
# Function - Get-RSCSLAManagedVolumes - Getting All SLA Managed Volumes connected to RSC
################################################
Function Get-RSCSLAManagedVolumes {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returns a list of all SLA Managed Volumes, do not use for regular Managed Volumes (instead use Get-RSCManagedVolumes).

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSLAManagedVolumes
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
################################################
# Creating Array
################################################
$RSCObjects = [System.Collections.ArrayList]@()
################################################
# Getting All SLA Managed Volumes
################################################
# Creating array for objects
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "SlaManagedVolumes";

"variables" = @{
"first" = 1000
};

"query" = "query SlaManagedVolumes(`$first: Int, `$after: String) {
  slaManagedVolumes(first: `$first, after: `$after) {
    edges {
      node {
        name
        id
        cdmId
        managedVolumeType
        protocol
        mountState
        isRelic
        provisionedSize
        physicalUsedSize
        onDemandSnapshotCount
        primaryClusterLocation {
          clusterUuid
          id
          name
        }
        protectionDate
        replicatedObjectCount
        clientConfig {
          backupScript {
            scriptCommand
            timeout
          }
          channelHostMountPaths
          failedPostBackupScript {
            scriptCommand
            timeout
          }
          hostId
          preBackupScript {
            scriptCommand
            timeout
          }
          shouldCancelBackupOnPreBackupScriptFailure
          successfulPostBackupScript {
            scriptCommand
            timeout
          }
          username
        }
        clientNamePatterns
        host {
          cdmId
          id
          name
        }
        hostDetail {
          id
          name
          status
        }
        latestUserNote {
          objectId
          time
          userName
          userNote
        }
        effectiveSlaDomain {
          id
          name
        }
        mainMount {
          channels {
            channelStats {
              usedSize
              totalSize
            }
            exportDate
            floatingIpAddress
            id
            mountPath
            mountSpec {
              imageSizeOpt
              mountDir
              node {
                brikId
                clusterId
                id
              }
            }
          }
          numChannels
          objectType
        }
        newestArchivedSnapshot {
          id
          date
        }
        newestReplicatedSnapshot {
          date
          id
        }
        newestSnapshot {
          id
          date
        }
        numChannels
        objectType
        oldestSnapshot {
          id
          date
        }
        reportWorkload {
          archiveSnapshots
          archivalSnapshotLag
          archiveStorage
          awaitingFirstFull
          dataReduction
          lastSnapshotLogicalBytes
          localEffectiveStorage
          localMeteredData
          localOnDemandSnapshots
          localProtectedData
          localSlaSnapshots
          localSnapshots
          localStorage
          logicalBytes
          logicalDataReduction
          missedSnapshots
          physicalBytes
          protectedOn
          protectionStatus
          provisionedBytes
          replicaSnapshots
          replicaStorage
          replicationSnapshotLag
          totalSnapshots
          transferredBytes
          usedBytes
        }
        slaAssignment
        slaPauseStatus
        smbShare {
          activeDirectoryGroups
          domainName
          validIps
          validUsers
        }
        state
        subnet
      }
    }
    count
    pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      startCursor
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectListReponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListReponse.data.slaManagedVolumes.edges.node
# Getting all results from paginations
While ($GCPProjectListResponse.data.slaManagedVolumes.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListReponse.data.slaManagedVolumes.pageInfo.endCursor
$RSCObjectListReponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListReponse.data.slaManagedVolumes.edges.node
}
################################################
# Processing Objects
################################################
# For Each Object Getting Data
ForEach ($RSCObject in $RSCObjectList)
{
# Setting variables
$MVName = $RSCObject.name
$MVID = $RSCObject.id
$MVCDMID = $RSCObject.cdmId
$MVType = $RSCObject.managedVolumeType
$MVProtocol = $RSCObject.protocol
IF($MVProtocol -eq "MANAGED_VOLUME_SHARE_TYPE_SMB"){$MVProtocol = "SMB"}
IF($MVProtocol -eq "MANAGED_VOLUME_SHARE_TYPE_NFS"){$MVProtocol = "NFS"}
$MVMountState = $RSCObject.mountstate
$MVState = $RSCObject.state
$MVChannels = $RSCObject.numChannels
$MVIsRelic = $RSCObject.isRelic
$MVProtectionDateUNIX = $RSCObject.protectionDate
# Converting protection date
IF($MVProtectionDateUNIX -ne $null){$MVProtectionDateUTC = Convert-RSCUNIXTime $MVProtectionDateUNIX}ELSE{$MVProtectionDateUTC = $null}
# Host info
$MVHost = $RSCObject.host.name
$MVHostID = $RSCObject.host.id
$MVHostCDMID = $RSCObject.host.cdmId
# SLA info
$MVSLADomain = $RSCObject.effectiveSlaDomain.name
$MVSLADomainID = $RSCObject.effectiveSlaDomain.id
$MVSLAAssignment = $RSCObject.slaAssignment
$MVSLAPauseStatus = $RSCObject.slaPauseStatus
$MVAwaitingFirstFull = $RSCObject.reportWorkload.awaitingFirstFull
# Client config
$MVClientConfig = $RSCObject.clientConfig
$MVBackupScript = $MVClientConfig.backupScript.scriptCommand
$MVBackupScriptTimeout = $MVClientConfig.backupScript.timeout
$MVBackupUsername = $MVClientConfig.username
$MVBackupPreScript = $MVClientConfig.preBackupScript
$MVBackupShouldCancelOnPreScriptFailure = $MVClientConfig.shouldCancelBackupOnPreBackupScriptFailure
$MVBackupPostScriptSuccess = $MVClientConfig.successfulPostBackupScript.scriptCommand
$MVBackupPostScriptSuccessTimeout = $MVClientConfig.successfulPostBackupScript.timeout
$MVBackupPostScriptFailure = $MVClientConfig.failedPostBackupScript.scriptCommand
$MVBackupPostScriptFailureTimeout = $MVClientConfig.failedPostBackupScript.timeout
$MVBackupScriptMountPaths = $MVClientConfig.channelHostMountPaths
$MVBackupScriptMountPathsCount = $MVBackupScriptMountPaths | Measure-Object | Select-Object -ExpandProperty Count
# MV stats
$MVProvisionedSizeBytes = $RSCObject.provisionedSize
$MVUsedSizeBytes = $RSCObject.physicalUsedSize
IF($MVProvisionedSizeBytes -ne $null){$MVProvisionedSizeGB = $MVProvisionedSizeBytes / 1000 / 1000 / 1000;$MVProvisionedSizeGB = [Math]::Round($MVProvisionedSizeGB,2)}ELSE{$MVProvisionedSizeGB = $null}
IF($MVUsedSizeBytes -ne $null){$MVUsedSizeGB = $MVUsedSizeBytes / 1000 / 1000 / 1000;$MVUsedSizeGB = [Math]::Round($MVUsedSizeGB,2)}ELSE{$MVUsedSizeGB = $null}
# MV snapshot distribution
$MVOnDemandSnapshots = $RSCObject.onDemandSnapshotCount
$MVTotalLocalSnapshots = $RSCObject.reportWorkload.localSnapshots
$MVTotalArchiveSnapshots = $RSCObject.reportWorkload.archiveSnapshots
$MVTotalReplicaSnapshots = $RSCObject.reportWorkload.replicaSnapshots
# MV snapshot info
$MVSnapshotDateUNIX = $RSCObject.newestSnapshot.date
$MVSnapshotDateID = $RSCObject.newestSnapshot.id
$MVReplicatedSnapshotDateUNIX = $RSCObject.newestReplicatedSnapshot.date
$MVReplicatedSnapshotDateID = $RSCObject.newestReplicatedSnapshot.id
$MVArchiveSnapshotDateUNIX = $RSCObject.newestArchivedSnapshot.date
$MVArchiveSnapshotDateID = $RSCObject.newestArchivedSnapshot.id
$MVOldestSnapshotDateUNIX = $RSCObject.oldestSnapshot.date
$MVOldestSnapshotDateID = $RSCObject.oldestSnapshot.id
# Converting snapshot dates
IF($MVSnapshotDateUNIX -ne $null){$MVSnapshotDateUTC = Convert-RSCUNIXTime $MVSnapshotDateUNIX}ELSE{$MVSnapshotDateUTC = $null}
IF($MVReplicatedSnapshotDateUNIX -ne $null){$MVReplicatedSnapshotDateUTC = Convert-RSCUNIXTime $MVReplicatedSnapshotDateUNIX}ELSE{$MVSnMVReplicatedSnapshotDateUTCapshotDateUTC = $null}
IF($MVArchiveSnapshotDateUNIX -ne $null){$MVArchiveSnapshotDateUTC = Convert-RSCUNIXTime $MVArchiveSnapshotDateUNIX}ELSE{$MVArchiveSnapshotDateUTC = $null}
IF($MVOldestSnapshotDateUNIX -ne $null){$MVOldestSnapshotDateUTC = Convert-RSCUNIXTime $MVOldestSnapshotDateUNIX}ELSE{$MVOldestSnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($MVSnapshotDateUTC -ne $null){$MVSnapshotTimespan = New-TimeSpan -Start $MVSnapshotDateUTC -End $UTCDateTime;$MVSnapshotHoursSince = $MVSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$MVSnapshotHoursSince = [Math]::Round($MVSnapshotHoursSince,1)}ELSE{$MVSnapshotHoursSince = $null}
IF($MVReplicatedSnapshotDateUTC -ne $null){$MVReplicatedSnapshotTimespan = New-TimeSpan -Start $MVReplicatedSnapshotDateUTC -End $UTCDateTime;$MVReplicatedSnapshotHoursSince = $MVReplicatedSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$MVReplicatedSnapshotHoursSince = [Math]::Round($MVReplicatedSnapshotHoursSince,1)}ELSE{$MVReplicatedSnapshotHoursSince = $null}
IF($MVArchiveSnapshotDateUTC -ne $null){$MVArchiveSnapshotTimespan = New-TimeSpan -Start $MVArchiveSnapshotDateUTC -End $UTCDateTime;$MVArchiveSnapshotHoursSince = $MVArchiveSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$MVArchiveSnapshotHoursSince = [Math]::Round($MVArchiveSnapshotHoursSince,1)}ELSE{$MVArchiveSnapshotHoursSince = $null}
IF($MVOldestSnapshotDateUTC -ne $null){$MVOldestSnapshotTimespan = New-TimeSpan -Start $MVOldestSnapshotDateUTC -End $UTCDateTime;$MVOldestSnapshotDaysSince = $MVOldestSnapshotTimespan | Select-Object -ExpandProperty TotalDays;$MVOldestSnapshotDaysSince = [Math]::Round($MVOldestSnapshotDaysSince,1)}ELSE{$MVOldestSnapshotDaysSince = $null}
# User note info
$MVNoteInfo = $RSCObject.latestUserNote
$MVNote = $MVNoteInfo.userNote
$MVNoteCreator = $MVNoteInfo.userName
$MVNoteCreatedUNIX = $MVNoteInfo.time
IF($MVNoteCreatedUNIX -ne $null){$MVNoteCreatedUTC = Convert-RSCUNIXTime $MVNoteCreatedUNIX}ELSE{$MVNoteCreatedUTC = $null}
# Rubrik cluster info
$MVRubrikCluster = $RSCObject.primaryClusterLocation.name
$MVRubrikClusterID = $RSCObject.primaryClusterLocation.id
# Getting URL
$ObjectURL = Get-RSCObjectURL -ObjectType "SlaManagedVolume" -ObjectID $MVID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ManagedVolume" -Value $MVName
$Object | Add-Member -MemberType NoteProperty -Name "ManagedVolumeID" -Value $MVID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $MVType
$Object | Add-Member -MemberType NoteProperty -Name "Protocol" -Value $MVProtocol
$Object | Add-Member -MemberType NoteProperty -Name "State" -Value $MVState
$Object | Add-Member -MemberType NoteProperty -Name "MountState" -Value $MVMountState
$Object | Add-Member -MemberType NoteProperty -Name "Channels" -Value $MVChannels
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $MVSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $MVSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $MVSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $MVIsRelic
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedGB" -Value $MVProvisionedSizeGB
$Object | Add-Member -MemberType NoteProperty -Name "UsedGB" -Value $MVUsedSizeGB
# Host config
$Object | Add-Member -MemberType NoteProperty -Name "BackupHost" -Value $MVHost
$Object | Add-Member -MemberType NoteProperty -Name "BackupHostID" -Value $MVHostID
$Object | Add-Member -MemberType NoteProperty -Name "BackupHostCDMID" -Value $MVHostCDMID
$Object | Add-Member -MemberType NoteProperty -Name "BackupScript" -Value $MVBackupScript
$Object | Add-Member -MemberType NoteProperty -Name "ScriptTimeout" -Value $MVBackupScriptTimeout
$Object | Add-Member -MemberType NoteProperty -Name "ScriptUsername" -Value $MVBackupUsername
$Object | Add-Member -MemberType NoteProperty -Name "MountPathsCount" -Value $MVBackupScriptMountPathsCount
$Object | Add-Member -MemberType NoteProperty -Name "MountPaths" -Value $MVBackupScriptMountPaths
$Object | Add-Member -MemberType NoteProperty -Name "PreBackupScript" -Value $MVBackupPreScript
$Object | Add-Member -MemberType NoteProperty -Name "PreBackupScriptCancelOnFailure" -Value $MVBackupShouldCancelOnPreScriptFailure
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScriptonSuccess" -Value $MVBackupPostScriptSuccess
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScriptonSuccessTimeout" -Value $MVBackupPostScriptSuccessTimeout
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScriptonFailure" -Value $MVBackupPostScriptFailure
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScriptonFailureTimeout" -Value $MVBackupPostScriptFailureTime
# Snapshot dates
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $MVProtectionDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LocalSnapshots" -Value $MVTotalLocalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveSnapshots" -Value $MVTotalArchiveSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshots" -Value $MVTotalReplicaSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "OnDemandSnapshots" -Value $MVOnDemandSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTC" -Value $MVSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTCAgeHours" -Value $MVSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshotUTC" -Value $MVReplicatedSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshotUTCAgeHours" -Value $MVReplicatedSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshotUTC" -Value $MVArchiveSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshotUTCAgeHours" -Value $MVArchiveSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTC" -Value $MVOldestSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTCAgeDays" -Value $MVOldestSnapshotDaysSince
# MV note info
$Object | Add-Member -MemberType NoteProperty -Name "LatestRSCNote" -Value $MVNote
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteCreator" -Value $MVNoteCreator
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteDateUTC" -Value $MVNoteCreatedUTC
# MV Rubrik cluster & IDs
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $MVID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $MVCDMID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $MVRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $MVRubrikClusterID
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCObjects.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCObjects
# End of function
}