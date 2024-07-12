################################################
# Function - Get-RSCAHVVMs - Getting all AHV VMs connected to the RSC instance
################################################
Function Get-RSCAHVVMs {

<#
.SYNOPSIS
Returns a list of all Nutanix AHV VMs in RSC.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAHVVMs
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
# Getting All AHV VMs 
################################################
# Creating array for objects
$RSCVMList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "NutanixVms";

"variables" = @{
"first" = 1000
};

"query" = "query NutanixVms(`$first: Int, `$after: String) {
  nutanixVms(first: `$first, after: `$after) {
    edges {
      node {
        agentStatus {
          connectionStatus
          disconnectReason
        }
        cdmId
        currentHostId
        effectiveSlaDomain {
          id
          name
        }
        excludedDisks
        hypervisorType
        id
        isAgentRegistered
        isRelic
        latestUserNote {
          userNote
          userName
          time
          objectId
        }
        name
        newestArchivedSnapshot {
          id
          date
        }
        newestReplicatedSnapshot {
          id
          date
        }
        newestSnapshot {
          id
          date
        }
        nutanixSnapshotConsistencyMandate
        objectType
        oldestSnapshot {
          id
          date
        }
        onDemandSnapshotCount
        osType
        physicalPath {
          fid
          name
          objectType
        }
        postBackupScript {
          failureHandling
          scriptPath
          timeoutMs
        }
        postSnapScript {
          failureHandling
          scriptPath
          timeoutMs
        }
        preBackupScript {
          failureHandling
          timeoutMs
          scriptPath
        }
        primaryClusterLocation {
          clusterUuid
          id
          name
        }
        vmUuid
        vmDisks {
          deviceType
          label
          isSnapshottable
          sizeInBytes
          uuid
          vmDiskUuid
        }
        slaPauseStatus
        slaAssignment
        replicatedObjectCount
        snapshotConsistencyMandate
        snapshotDistribution {
          onDemandCount
          retrievedCount
          scheduledCount
          totalCount
        }
        reportSnappable {
          archivalSnapshotLag
          archiveStorage
          archiveSnapshots
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
          location
          logicalDataReduction
          missedSnapshots
          physicalBytes
          protectedOn
          protectionStatus
          provisionedBytes
          pullTime
          replicaSnapshots
          replicaStorage
          replicationSnapshotLag
          transferredBytes
          totalSnapshots
          usedBytes
        }
      }
    }
    pageInfo {
      endCursor
      hasNextPage
      startCursor
      hasPreviousPage
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCVMList += $RSCVMListResponse.data.nutanixVms.edges.node
# Getting all results from paginations
While ($RSCVMListResponse.data.nutanixVms.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCVMListResponse.data.nutanixVms.pageInfo.endCursor
$RSCVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCVMList += $RSCVMListResponse.data.nutanixVms.edges.node
}
################################################
# Processing VMs
################################################
# Creating array
$RSCVMs = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCVM in $RSCVMList)
{
# Setting variables
$VMID = $RSCVM.id
$VMName = $RSCVM.name
$VMCDMID = $RSCVM.cdmId
$VMUUID = $RSCVM.vmUuid
$VMIsRelic = $RSCVM.isRelic
$VMProtectionDateUNIX = $RSCVM.reportSnappable.protectedOn
$VMGuestOSType = $RSCVM.guestOsType
$VMConsistency = $RSCVM.nutanixSnapshotConsistencyMandate
$VMAgentRegistered = $RSCVM.isAgentRegistered
$VMAgentInfo = $RSCVM.agentStatus
$VMAgentStatus = $VMAgentInfo.connectionStatus
$VMAgentDisconnectReason = $VMAgentInfo.disconnectReason
# User note info
$VMNoteInfo = $RSCVM.latestUserNote
$VMNote = $VMNoteInfo.userNote
$VMNoteCreator = $VMNoteInfo.userName
$VMNoteCreatedUNIX = $VMNoteInfo.time
# Converting dates
IF($VMProtectionDateUNIX -ne $null){$VMProtectionDateUTC = Convert-RSCUNIXTime $VMProtectionDateUNIX}ELSE{$VMProtectionDateUTC = $null}
IF($VMNoteCreatedUNIX -ne $null){$VMNoteCreatedUTC = Convert-RSCUNIXTime $VMNoteCreatedUNIX}ELSE{$VMNoteCreatedUTC = $null}
# SLA info
$VMSLADomainInfo = $RSCVM.effectiveSlaDomain
$VMSLADomain = $VMSLADomainInfo.name
$VMSLADomainID = $VMSLADomainInfo.id
$VMSLAAssignment = $RSCVM.slaAssignment
$VMSLAPaused = $RSCVM.slaPauseStatus
# VM location
$VMPhysicalPaths = $RSCVM.physicalPath
$VMClusterInfo = $VMPhysicalPaths | Where-Object {$_.objectType -eq "NutanixCluster"}
$VMClusterName = $VMClusterInfo.name
$VMClusterID = $VMClusterInfo.fid
# VMDK info
$VMVirtualDisks = $RSCVM.vmDisks.edges.node
$VMVirtualDisksCount = $VMVirtualDisks | Measure-Object | Select-Object -ExpandProperty Count
$VMVirtualDisksExcluded = $RSCVM.excludedDisks
$VMVirtualDisksExcludedCount = $VMVirtualDisksExcluded | Measure-Object | Select-Object -ExpandProperty Count
# VM scripting
$VMPreBackupScriptInfo = $RSCVM.preBackupScript
$VMPostBackupScriptInfo = $RSCVM.postBackupScript
IF($VMPreBackupScriptInfo -eq ""){$VMPreBackupScriptEnabled = $FALSE}ELSE{$VMPreBackupScriptEnabled = $TRUE}
IF($VMPostBackupScriptInfo -eq ""){$VMPostBackupScriptEnabled = $FALSE}ELSE{$VMPostBackupScriptEnabled = $TRUE}
# VM snapshot distribution
$VMSnapshotTotals = $RSCVM.snapshotDistribution
$VMOnDemandSnapshots = $VMSnapshotTotals.onDemandCount
$VMSnapshots = $VMSnapshotTotals.scheduledCount
# VM snapshot info
$VMSnapshotDateUNIX = $RSCVM.newestSnapshot.date
$VMSnapshotDateID = $RSCVM.newestSnapshot.id
$VMReplicatedSnapshotDateUNIX = $RSCVM.newestReplicatedSnapshot.date
$VMReplicatedSnapshotDateID = $RSCVM.newestReplicatedSnapshot.id
$VMArchiveSnapshotDateUNIX = $RSCVM.newestArchivedSnapshot.date
$VMArchiveSnapshotDateID = $RSCVM.newestArchivedSnapshot.id
$VMOldestSnapshotDateUNIX = $RSCVM.oldestSnapshot.date
$VMOldestSnapshotDateID = $RSCVM.oldestSnapshot.id
# Converting snapshot dates
IF($VMSnapshotDateUNIX -ne $null){$VMSnapshotDateUTC = Convert-RSCUNIXTime $VMSnapshotDateUNIX}ELSE{$VMSnapshotDateUTC = $null}
IF($VMReplicatedSnapshotDateUNIX -ne $null){$VMReplicatedSnapshotDateUTC = Convert-RSCUNIXTime $VMReplicatedSnapshotDateUNIX}ELSE{$VMSnVMReplicatedSnapshotDateUTCapshotDateUTC = $null}
IF($VMArchiveSnapshotDateUNIX -ne $null){$VMArchiveSnapshotDateUTC = Convert-RSCUNIXTime $VMArchiveSnapshotDateUNIX}ELSE{$VMArchiveSnapshotDateUTC = $null}
IF($VMOldestSnapshotDateUNIX -ne $null){$VMOldestSnapshotDateUTC = Convert-RSCUNIXTime $VMOldestSnapshotDateUNIX}ELSE{$VMOldestSnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($VMSnapshotDateUTC -ne $null){$VMSnapshotTimespan = New-TimeSpan -Start $VMSnapshotDateUTC -End $UTCDateTime;$VMSnapshotHoursSince = $VMSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$VMSnapshotHoursSince = [Math]::Round($VMSnapshotHoursSince,1)}ELSE{$VMSnapshotHoursSince = $null}
IF($VMReplicatedSnapshotDateUTC -ne $null){$VMReplicatedSnapshotTimespan = New-TimeSpan -Start $VMReplicatedSnapshotDateUTC -End $UTCDateTime;$VMReplicatedSnapshotHoursSince = $VMReplicatedSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$VMReplicatedSnapshotHoursSince = [Math]::Round($VMReplicatedSnapshotHoursSince,1)}ELSE{$VMReplicatedSnapshotHoursSince = $null}
IF($VMArchiveSnapshotDateUTC -ne $null){$VMArchiveSnapshotTimespan = New-TimeSpan -Start $VMArchiveSnapshotDateUTC -End $UTCDateTime;$VMArchiveSnapshotHoursSince = $VMArchiveSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$VMArchiveSnapshotHoursSince = [Math]::Round($VMArchiveSnapshotHoursSince,1)}ELSE{$VMArchiveSnapshotHoursSince = $null}
IF($VMOldestSnapshotDateUTC -ne $null){$VMOldestSnapshotTimespan = New-TimeSpan -Start $VMOldestSnapshotDateUTC -End $UTCDateTime;$VMOldestSnapshotDaysSince = $VMOldestSnapshotTimespan | Select-Object -ExpandProperty TotalDays;$VMOldestSnapshotDaysSince = [Math]::Round($VMOldestSnapshotDaysSince,1)}ELSE{$VMOldestSnapshotDaysSince = $null}
# Reporting data
$VMReportInfo = $RSCVM.reportSnappable
$VMWaitingForFirstFull = $VMReportInfo.awaitingFirstFull
$VMProvisionedBytes = $VMReportInfo.localProtectedData
$VMProtectedBytes = $VMReportInfo.localProtectedData
$VMLocalUsedBytes = $VMReportInfo.localStorage
$VMReplicaUsedBytes = $VMReportInfo.replicaStorage
$VMArchiveUsedBytes = $VMReportInfo.archiveStorage
$VMLocalSnapshots = $VMReportInfo.localSnapshots
$VMReplicaSnapshots = $VMReportInfo.replicaSnapshots
$VMArchiveSnapshots = $VMReportInfo.archiveSnapshots
# Converting storage units
IF($VMProvisionedBytes -ne $null){$VMProvisionedGB = $VMProvisionedBytes / 1000 / 1000 / 1000;$VMProvisionedGB = [Math]::Round($VMProvisionedGB,2)}ELSE{$VMProvisionedGB = $null}
IF($VMProtectedBytes -ne $null){$VMProtectedGB = $VMProtectedBytes / 1000 / 1000 / 1000;$VMProtectedGB = [Math]::Round($VMProtectedGB,2)}ELSE{$VMProtectedGB = $null}
IF($VMLocalUsedBytes -ne $null){$VMLocalUsedGB = $VMLocalUsedBytes / 1000 / 1000 / 1000;$VMLocalUsedGB = [Math]::Round($VMLocalUsedGB,2)}ELSE{$VMLocalUsedGB = $null}
IF($VMReplicaUsedBytes -ne $null){$VMReplicaUsedGB = $VMReplicaUsedBytes / 1000 / 1000 / 1000;$VMReplicaUsedGB = [Math]::Round($VMReplicaUsedGB,2)}ELSE{$VMReplicaUsedGB = $null}
IF($VMArchiveUsedBytes -ne $null){$VMArchiveUsedGB = $VMArchiveUsedBytes / 1000 / 1000 / 1000;$VMArchiveUsedGB = [Math]::Round($VMArchiveUsedGB,2)}ELSE{$VMArchiveUsedGB = $null}
# Calculating dedupe for storage jockeys
IF(($VMProtectedBytes -gt 1) -and ($VMLocalSnapshots -gt 1)){$VMDedupeRatio = $VMProtectedBytes * $VMLocalSnapshots / $VMLocalUsedBytes;$VMDedupeRatio = [Math]::Round($VMDedupeRatio,2)}ELSE{$VMDedupeRatio = $null}
# Primary Rubrik cluster info
$VMRubrikCluster = $RSCVM.primaryClusterLocation.name
$VMRubrikClusterID = $RSCVM.primaryClusterLocation.id
# Creating object URL
$VMURL = Get-RSCObjectURL -ObjectType "NutanixVirtualMachine" -ObjectID $VMID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# VM info
$Object | Add-Member -MemberType NoteProperty -Name "VM" -Value $VMName
$Object | Add-Member -MemberType NoteProperty -Name "VMID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "VMCDMID" -Value $VMCDMID
$Object | Add-Member -MemberType NoteProperty -Name "VMUUID" -Value $VMUUID
$Object | Add-Member -MemberType NoteProperty -Name "AgentStatus" -Value $VMAgentStatus
$Object | Add-Member -MemberType NoteProperty -Name "AgentRegistered" -Value $VMAgentRegistered
# OSType - not working as of 04/19/23 - API returns nothing for every AHV VM
# $Object | Add-Member -MemberType NoteProperty -Name "OSType" -Value $VMGuestOSType
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $VMSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $VMSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $VMSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $VMSLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $VMProtectionDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $VMWaitingForFirstFull
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $VMIsRelic
# VM disks - not working as of 04/19/23 - API returns nothing for every AHV VM
# $Object | Add-Member -MemberType NoteProperty -Name "Disks" -Value $VMVirtualDisksCount
# $Object | Add-Member -MemberType NoteProperty -Name "DisksExcluded" -Value $VMVirtualDisksExcludedCount
# Storage usage
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedGB" -Value $VMProvisionedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedGB" -Value $VMProtectedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalUsedGB" -Value $VMLocalUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaUsedGB" -Value $VMReplicaUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveUsedGB" -Value $VMArchiveUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "DedupeRatio" -Value $VMDedupeRatio
# VM snapshots
$Object | Add-Member -MemberType NoteProperty -Name "OnDemandSnapshots" -Value $VMOnDemandSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LocalSnapshots" -Value $VMLocalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshots" -Value $VMReplicaSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshots" -Value $VMArchiveSnapshots
# Snapshot dates
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTC" -Value $VMSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTCAgeHours" -Value $VMSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshotUTC" -Value $VMReplicatedSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshotUTCAgeHours" -Value $VMReplicatedSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshotUTC" -Value $VMArchiveSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshotUTCAgeHours" -Value $VMArchiveSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTC" -Value $VMOldestSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTCAgeDays" -Value $VMOldestSnapshotDaysSince
# VM note info
$Object | Add-Member -MemberType NoteProperty -Name "LatestRSCNote" -Value $VMNote
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteCreator" -Value $VMNoteCreator
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteDateUTC" -Value $VMNoteCreatedUTC
# Misc info
$Object | Add-Member -MemberType NoteProperty -Name "Consistency" -Value $VMConsistency
$Object | Add-Member -MemberType NoteProperty -Name "PreBackupScript" -Value $VMPreBackupScriptEnabled
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScript" -Value $VMPostBackupScriptEnabled
# Rubrik cluster info
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $VMRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $VMRubrikClusterID
# VM Location information
$Object | Add-Member -MemberType NoteProperty -Name "VMCluster" -Value $VMClusterName
$Object | Add-Member -MemberType NoteProperty -Name "VMClusterID" -Value $VMClusterID
# Mgmt URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $VMURL
# Adding
$RSCVMs.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCVMs
# End of function
}