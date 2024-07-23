################################################
# Function - Get-RSCVMwareVMsDetail - Getting all VMware VMs connected to the RSC instance
################################################
Function Get-RSCVMwareVMsDetail {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all VMware VMs with more detail than returned by Get-RSCVmwareVMs

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCVMwareVMsDetail
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
# Getting All VMware VMs 
################################################
# Creating array for objects
$RSCVMList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "VSphereVMsListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query VSphereVMsListQuery(`$first: Int!, `$after: String, `$isMultitenancyEnabled: Boolean = false, `$sortBy: HierarchySortByField, `$sortOrder: SortOrder, `$isDuplicatedVmsIncluded: Boolean = true) {
  vSphereVmNewConnection(first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder) {
    edges {
      cursor
      node {
        id
        ...VSphereNameColumnFragment
        ...CdmClusterColumnFragment
        ...EffectiveSlaColumnFragment
        ...VSphereSlaAssignmentColumnFragment
        ...OrganizationsColumnFragment @include(if: `$isMultitenancyEnabled)
        isRelic
        guestCredentialAuthorizationStatus
        name
        protectionDate
        powerStatus
        replicatedObjectCount
        slaAssignment
        snapshotConsistencyMandate
        arrayIntegrationEnabled
        cdmId
        slaPauseStatus
        vmwareToolsInstalled
        objectType
        onDemandSnapshotCount
        guestOsName
        guestCredentialId
        guestOsType
        vmwareToolsInstalled
        vsphereTagPath {
          fid
          name
          objectType
        }
        primaryClusterLocation {
          id
          name
          __typename
        }
        logicalPath {
          fid
          name
          objectType
        }
        physicalPath {
          fid
          objectType
          name
        }
        snapshotDistribution {
          id
          onDemandCount
          retrievedCount
          scheduledCount
          totalCount
          __typename
        }
        reportWorkload {
          id
          awaitingFirstFull
          archiveStorage
          archiveSnapshots
          dataReduction
          complianceStatus
          physicalBytes
          provisionedBytes
          replicaSnapshots
          totalSnapshots
          usedBytes
          transferredBytes
          replicaStorage
          replicationComplianceStatus
          protectionStatus
          missedSnapshots
          logicalDataReduction
          logicalBytes
          localStorage
          localSnapshots
          localSlaSnapshots
          localProtectedData
          localEffectiveStorage
          archivalSnapshotLag
          archivalComplianceStatus
          replicationSnapshotLag
        }
        agentStatus {
          agentStatus
          disconnectReason
          __typename
        }
        duplicatedVms @include(if: `$isDuplicatedVmsIncluded) {
          fid
          cluster {
            id
            name
            version
            status
            __typename
          }
          slaAssignment
          effectiveSlaDomain {
            ... on GlobalSlaReply {
              id
              name
              isRetentionLockedSla
              description
              __typename
            }
            ... on ClusterSlaDomain {
              id
              fid
              name
              isRetentionLockedSla
              cluster {
                id
                name
                __typename
              }
              __typename
            }
            __typename
          }
          snapshotDistribution {
            id
            onDemandCount
            retrievedCount
            scheduledCount
            totalCount
            __typename
          }
          effectiveSlaSourceObject {
            fid
            objectType
            name
            __typename
          }
          __typename
        }
        __typename
        effectiveSlaDomain {
          id
          name
        }
        vsphereVirtualDisks {
          edges {
          node {
            datastore {
              id
              name
              isLocal
              capacity
              freeSpace
            }
            excludeFromSnapshots
            virtualMachineId
            size
            fileName
            fid
          }
            
          }
        }
        latestUserNote {
        userNote
        userName
        time
        objectId
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
        oldestSnapshot {
          id
          date
        }
        postBackupScript {
          failureHandling
          timeoutMs
          scriptPath
        }
        postSnapScript {
          failureHandling
          timeoutMs
          scriptPath
        }
        preBackupScript {
          failureHandling
          timeoutMs
          scriptPath
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

fragment VSphereNameColumnFragment on HierarchyObject {
  id
  name
  ...HierarchyObjectTypeFragment
  __typename
}

fragment HierarchyObjectTypeFragment on HierarchyObject {
  objectType
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

fragment VSphereSlaAssignmentColumnFragment on HierarchyObject {
  effectiveSlaSourceObject {
    fid
    name
    objectType
    __typename
  }
  ...SlaAssignmentColumnFragment
  __typename
}

fragment SlaAssignmentColumnFragment on HierarchyObject {
  slaAssignment
  __typename
}

fragment OrganizationsColumnFragment on HierarchyObject {
  allOrgs {
    name
    __typename
  }
  __typename
}
"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Logging
Write-Host "WARNING: This can take a long time in a large environment, use Get-RSCVMwareVMs for a quicker response.
QueryingAPI: vSphereVmNewConnection"
# Querying API
$RSCVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCVMList += $RSCVMListResponse.data.vSphereVmNewConnection.edges.node
# Getting all results from paginations
While ($RSCVMListResponse.data.vSphereVmNewConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCVMListResponse.data.vSphereVmNewConnection.pageInfo.endCursor
$RSCVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCVMList += $RSCVMListResponse.data.vSphereVmNewConnection.edges.node
}
# Processing VMs
Write-Host "Processing VMs.."
################################################
# Processing VMs
################################################
# Creating arrays
$RSCVMs = [System.Collections.ArrayList]@()
$RSCTagAssignments = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCVM in $RSCVMList)
{
# Setting variables
$VMID = $RSCVM.id
$VMName = $RSCVM.name
$VMCDMID = $RSCVM.cdmId
$VMPowerStatus = $RSCVM.powerStatus
$VMIsRelic = $RSCVM.isRelic
$VMProtectionDateUNIX = $RSCVM.protectionDate
$VMToolsInstalled = $RSCVM.vmwareToolsInstalled
$VMGuestOSType = $RSCVM.guestOsType
$VMGuestOSName = $RSCVM.guestOsName
$VMConsistency = $RSCVM.snapshotConsistencyMandate
$VMGuestAuth = $RSCVM.guestCredentialAuthorizationStatus
$VMArrayIntegration = $RSCVM.arrayIntegrationEnabled
$VMAgentInfo = $RSCVM.agentStatus
$VMAgentStatus = $VMAgentInfo.agentStatus
$VMAgentDisconnectReason = $VMAgentInfo.disconnectReason
# Tag info
$VMTagList = $RSCVM.vsphereTagPath
# Filtering
$VMTagCategories = $VMTagList | Where-Object {$_.ObjectType -eq "vSphereTagCategory"}
$VMTagCategoryCount = $VMTagCategories | Measure-Object | Select-Object -ExpandProperty Count
$VMTags = $VMTagList | Where-Object {$_.ObjectType -eq "vSphereTag"}
$VMTagCount = $VMTags | Measure-Object | Select-Object -ExpandProperty Count
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
$VMLogicalPaths = $RSCVM.logicalPath
$VMHostInfo = $VMPhysicalPaths | Where-Object {$_.objectType -eq "VSphereHost"}
$VMHostName = $VMHostInfo.name
$VMHostID = $VMHostInfo.fid
$VMClusterInfo = $VMPhysicalPaths | Where-Object {$_.objectType -eq "VSphereComputeCluster"}
$VMClusterName = $VMClusterInfo.name
$VMClusterID = $VMClusterInfo.fid
$VMDatacenterInfo = $VMPhysicalPaths | Where-Object {$_.objectType -eq "VSphereDatacenter"}
$VMDatacenterName = $VMDatacenterInfo.name
$VMDatacenterID = $VMDatacenterInfo.fid
$VMvCenterInfo = $VMPhysicalPaths | Where-Object {$_.objectType -eq "VSphereVCenter"}
$VMvCenterName = $VMvCenterInfo.name
$VMvCenterID = $VMvCenterInfo.fid
$VMFolderInfo = $VMLogicalPaths | Where-Object {$_.objectType -eq "VSphereFolder"}
$VMFolderName = $VMHostInfo.name
$VMFolderID = $VMHostInfo.fid
# VMDK info
$VMVirtualDisks = $RSCVM.vsphereVirtualDisks.edges.node
$VMVirtualDisksCount = $VMVirtualDisks | Measure-Object | Select-Object -ExpandProperty Count
$VMVirtualDisksExcluded = $VMVirtualDisks | Where-Object {$_.excludeFromSnapshots -eq $True}
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
IF($RSCReportingModule -eq $TRUE)
{
IF($VMSnapshotDateUNIX -ne $null){$VMSnapshotDateUTC = Convert-RSCUNIXTime $VMSnapshotDateUNIX}ELSE{$VMSnapshotDateUTC = $null}
IF($VMReplicatedSnapshotDateUNIX -ne $null){$VMReplicatedSnapshotDateUTC = Convert-RSCUNIXTime $VMReplicatedSnapshotDateUNIX}ELSE{$VMSnVMReplicatedSnapshotDateUTCapshotDateUTC = $null}
IF($VMArchiveSnapshotDateUNIX -ne $null){$VMArchiveSnapshotDateUTC = Convert-RSCUNIXTime $VMArchiveSnapshotDateUNIX}ELSE{$VMArchiveSnapshotDateUTC = $null}
IF($VMOldestSnapshotDateUNIX -ne $null){$VMOldestSnapshotDateUTC = Convert-RSCUNIXTime $VMOldestSnapshotDateUNIX}ELSE{$VMOldestSnapshotDateUTC = $null}
}
ELSE
{
# RSC SDK auto converts
$VMSnapshotDateUTC = $VMSnapshotDateUNIX
$VMReplicatedSnapshotDateUTC = $VMReplicatedSnapshotDateUNIX
$VMArchiveSnapshotDateUTC = $VMArchiveSnapshotDateUNIX
$VMOldestSnapshotDateUTC = $VMOldestSnapshotDateUNIX
}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($VMSnapshotDateUTC -ne $null){$VMSnapshotTimespan = New-TimeSpan -Start $VMSnapshotDateUTC -End $UTCDateTime;$VMSnapshotHoursSince = $VMSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$VMSnapshotHoursSince = [Math]::Round($VMSnapshotHoursSince,1)}ELSE{$VMSnapshotHoursSince = $null}
IF($VMReplicatedSnapshotDateUTC -ne $null){$VMReplicatedSnapshotTimespan = New-TimeSpan -Start $VMReplicatedSnapshotDateUTC -End $UTCDateTime;$VMReplicatedSnapshotHoursSince = $VMReplicatedSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$VMReplicatedSnapshotHoursSince = [Math]::Round($VMReplicatedSnapshotHoursSince,1)}ELSE{$VMReplicatedSnapshotHoursSince = $null}
IF($VMArchiveSnapshotDateUTC -ne $null){$VMArchiveSnapshotTimespan = New-TimeSpan -Start $VMArchiveSnapshotDateUTC -End $UTCDateTime;$VMArchiveSnapshotHoursSince = $VMArchiveSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$VMArchiveSnapshotHoursSince = [Math]::Round($VMArchiveSnapshotHoursSince,1)}ELSE{$VMArchiveSnapshotHoursSince = $null}
IF($VMOldestSnapshotDateUTC -ne $null){$VMOldestSnapshotTimespan = New-TimeSpan -Start $VMOldestSnapshotDateUTC -End $UTCDateTime;$VMOldestSnapshotDaysSince = $VMOldestSnapshotTimespan | Select-Object -ExpandProperty TotalDays;$VMOldestSnapshotDaysSince = [Math]::Round($VMOldestSnapshotDaysSince,1)}ELSE{$VMOldestSnapshotDaysSince = $null}
# Reporting data
$VMReportInfo = $RSCVM.reportWorkload
$VMWaitingForFirstFull = $VMReportInfo.awaitingFirstFull
$VMProvisionedBytes = $VMReportInfo.provisionedBytes
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
$VMTotalUsedGB = $VMLocalUsedGB + $VMReplicaUsedGB + $VMArchiveUsedGB
# Calculating dedupe for storage jockeys
IF(($VMProtectedBytes -gt 1) -and ($VMLocalSnapshots -gt 1)){$VMDedupeRatio = $VMProtectedBytes * $VMLocalSnapshots / $VMLocalUsedBytes;$VMDedupeRatio = [Math]::Round($VMDedupeRatio,2)}ELSE{$VMDedupeRatio = $null}
# Primary Rubrik cluster info
$VMRubrikCluster = $RSCVM.primaryClusterLocation.name
$VMRubrikClusterID = $RSCVM.primaryClusterLocation.id
# Getting URL
$VMURL = Get-RSCObjectURL -ObjectType "VmwareVirtualMachine" -ObjectID $VMID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# VM info
$Object | Add-Member -MemberType NoteProperty -Name "VM" -Value $VMName
$Object | Add-Member -MemberType NoteProperty -Name "VMID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "VMCDMID" -Value $VMCDMID
$Object | Add-Member -MemberType NoteProperty -Name "Power" -Value $VMPowerStatus
$Object | Add-Member -MemberType NoteProperty -Name "VMTools" -Value $VMToolsInstalled
$Object | Add-Member -MemberType NoteProperty -Name "AgentStatus" -Value $VMAgentStatus
$Object | Add-Member -MemberType NoteProperty -Name "OSType" -Value $VMGuestOSType
$Object | Add-Member -MemberType NoteProperty -Name "OSName" -Value $VMGuestOSName
# Tags
$Object | Add-Member -MemberType NoteProperty -Name "VMTags" -Value $VMTagCount
$Object | Add-Member -MemberType NoteProperty -Name "VMTagCategories" -Value $VMTagCategoryCount
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $VMSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $VMSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $VMSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $VMSLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $VMProtectionDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $VMWaitingForFirstFull
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $VMIsRelic
# VM disks
$Object | Add-Member -MemberType NoteProperty -Name "Disks" -Value $VMVirtualDisksCount
$Object | Add-Member -MemberType NoteProperty -Name "DisksExcluded" -Value $VMVirtualDisksExcludedCount
# Storage usage
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedGB" -Value $VMProvisionedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedGB" -Value $VMProtectedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalUsedGB" -Value $VMLocalUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaUsedGB" -Value $VMReplicaUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveUsedGB" -Value $VMArchiveUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "TotalUsedGB" -Value $VMTotalUsedGB
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
$Object | Add-Member -MemberType NoteProperty -Name "GuestAuth" -Value $VMGuestAuth
$Object | Add-Member -MemberType NoteProperty -Name "ArrayIntegration" -Value $VMArrayIntegration
$Object | Add-Member -MemberType NoteProperty -Name "Consistency" -Value $VMConsistency
$Object | Add-Member -MemberType NoteProperty -Name "PreBackupScript" -Value $VMPreBackupScriptEnabled
$Object | Add-Member -MemberType NoteProperty -Name "PostBackupScript" -Value $VMPostBackupScriptEnabled
# Rubrik cluster info
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $VMRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $VMRubrikClusterID
# VM Location information
$Object | Add-Member -MemberType NoteProperty -Name "VMFolder" -Value $VMFolderName
$Object | Add-Member -MemberType NoteProperty -Name "VMFolderID" -Value $VMFolderID
$Object | Add-Member -MemberType NoteProperty -Name "VMHost" -Value $VMHostName
$Object | Add-Member -MemberType NoteProperty -Name "VMHostID" -Value $VMHostID
$Object | Add-Member -MemberType NoteProperty -Name "VMCluster" -Value $VMClusterName
$Object | Add-Member -MemberType NoteProperty -Name "VMClusterID" -Value $VMClusterID
$Object | Add-Member -MemberType NoteProperty -Name "VMDatacenter" -Value $VMDatacenterName
$Object | Add-Member -MemberType NoteProperty -Name "VMDatacenterID" -Value $VMDatacenterID
$Object | Add-Member -MemberType NoteProperty -Name "VMvCenter" -Value $VMvCenterName
$Object | Add-Member -MemberType NoteProperty -Name "VMvCenterID" -Value $VMvCenterID
# URL
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