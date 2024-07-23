################################################
# Function - Get-RSCManagedVolumes - Getting All Managed Volumes connected to RSC
################################################
Function Get-RSCManagedVolumes {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all regular managed volumes (not SLA managed volumes, for those use Get-RSCSLAManagedVolumes).

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCManagedVolumes
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
$RSCGraphQL = @{"operationName" = "ManagedVolumes";

"variables" = @{
"first" = 1000
};

"query" = "query ManagedVolumes(`$first: Int, `$after: String) {
  managedVolumes(first: `$first, after: `$after) {
    edges {
      node {
        name
        id
        cdmId
        protocol
        protectionDate
        provisionedSize
        objectType
        numChannels
        mountState
        state
        subnet
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
            timeout
            scriptCommand
          }
          username
        }
        clientNamePatterns
        primaryClusterLocation {
          clusterUuid
          id
          name
        }
        applicationTag
        host {
          cdmId
          id
          name
          osType
          osName
        }
        isRelic
        hostDetail {
          id
          name
          status
        }
        mainMount {
          numChannels
          name
          id
        }
        managedVolumeType
        onDemandSnapshotCount
        smbShare {
          activeDirectoryGroups
          domainName
          validIps
          validUsers
        }
        effectiveSlaDomain {
          id
          name
        }
        slaAssignment
        slaPauseStatus
        reportWorkload {
          archivalSnapshotLag
          archiveSnapshots
          archiveStorage
          awaitingFirstFull
          dataReduction
          lastSnapshotLogicalBytes
          localEffectiveStorage
          localMeteredData
          localOnDemandSnapshots
          localStorage
          logicalBytes
          logicalDataReduction
          physicalBytes
          provisionedBytes
          protectionStatus
          replicaSnapshots
          replicaStorage
          totalSnapshots
          transferredBytes
          usedBytes
        }
        newestSnapshot {
          id
          date
        }
        oldestSnapshot {
          id
          date
        }
        physicalUsedSize
        replicatedObjectCount
        newestReplicatedSnapshot {
          id
          date
        }
        newestArchivedSnapshot {
          id
          date
        }
        latestUserNote {
          objectId
          time
          userName
          userNote
        }
      }
    }
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
$RSCObjectList += $RSCObjectListReponse.data.ManagedVolumes.edges.node
# Getting all results from paginations
While ($GCPProjectListResponse.data.ManagedVolumes.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListReponse.data.ManagedVolumes.pageInfo.endCursor
$RSCObjectListReponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListReponse.data.ManagedVolumes.edges.node
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
$MVApplicationTag = $RSCObject.applicationTag
IF($MVProtocol -eq "MANAGED_VOLUME_SHARE_TYPE_SMB"){$MVProtocol = "SMB"}
IF($MVProtocol -eq "MANAGED_VOLUME_SHARE_TYPE_NFS"){$MVProtocol = "NFS"}
$MVMountState = $RSCObject.mountstate
$MVState = $RSCObject.state
$MVChannels = $RSCObject.numChannels
$MVIsRelic = $RSCObject.isRelic
$MVProtectionDateUNIX = $RSCObject.protectionDate
$MVClientNamePatterns = $RSCObject.clientNamePatterns
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
$ObjectURL = Get-RSCObjectURL -ObjectType "ManagedVolume" -ObjectID $MVID
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
# MV config
$Object | Add-Member -MemberType NoteProperty -Name "ApplicationTag" -Value $MVApplicationTag
$Object | Add-Member -MemberType NoteProperty -Name "clientNamePatterns" -Value $MVClientNamePatterns
$Object | Add-Member -MemberType NoteProperty -Name "BackupScript" -Value $MVBackupScript
$Object | Add-Member -MemberType NoteProperty -Name "ScriptTimeout" -Value $MVBackupScriptTimeout
$Object | Add-Member -MemberType NoteProperty -Name "ScriptUsername" -Value $MVBackupUsername
$Object | Add-Member -MemberType NoteProperty -Name "PreBackupScript" -Value $MVBackupPreScript
$Object | Add-Member -MemberType NoteProperty -Name "PreBackupScriptCancelOnFailure" -Value $MVBackupShouldCancelOnPreScriptFailure
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScriptonSuccess" -Value $MVBackupPostScriptSuccess
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScriptonSuccessTimeout" -Value $MVBackupPostScriptSuccessTimeout
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScriptonFailure" -Value $MVBackupPostScriptFailure
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScriptonFailureTimeout" -Value $MVBackupPostScriptFailureTime
# Snapshot dates
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $MVProtectionDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "OnDemandSnapshots" -Value $MVOnDemandSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveSnapshots" -Value $MVTotalArchiveSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshots" -Value $MVTotalReplicaSnapshots
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