################################################
# Function - Get-RSCHypervVMs - Getting all Hyperv VMs connected to the RSC instance
################################################
function Get-RSCHypervVM {

    <#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all Hyper-V VMs.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCHypervVMs
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
    [CmdletBinding()]
    [Alias('Get-RSCHypervVMs')]
    param()
    ################################################
    # Importing Module & Running Required Functions
    ################################################
    # Importing the module is it needs other modules
    Import-Module RSCReporting
    # Checking connectivity, exiting function with error if not connected
    Test-RSCConnection
    ################################################
    # Getting All Hyperv VMs 
    ################################################
    # Creating array for objects
    $RSCVMList = @()
    # Building GraphQL query
    $RSCGraphQL = @{"operationName" = "HypervVirtualMachines";

        "variables"                 = @{
            "first" = 1000
        };

        "query"                     = "query HypervVirtualMachines(`$first: Int, `$after: String) {
  hypervVirtualMachines(first: `$first, after: `$after) {
    edges {
      node {
        name
        id
        cdmId
        isRelic
        effectiveSlaDomain {
          id
          name
        }
        latestUserNote {
          objectId
          time
          userName
          userNote
        }
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
        objectType
        osType
        onDemandSnapshotCount
        oldestSnapshot {
          id
          date
        }
        physicalPath {
          fid
          name
          objectType
        }
        reportWorkload {
          archiveSnapshots
          archiveStorage
          dataReduction
          lastSnapshotLogicalBytes
          localProtectedData
          localSlaSnapshots
          localStorage
          logicalBytes
          logicalDataReduction
          physicalBytes
          protectedOn
          protectionStatus
          provisionedBytes
          replicaSnapshots
          replicaStorage
          replicationSnapshotLag
          archivalSnapshotLag
          totalSnapshots
          transferredBytes
          usedBytes
          missedSnapshots
          awaitingFirstFull
        }
        replicatedObjectCount
        protectionDate
        slaPauseStatus
        slaAssignment
        primaryClusterLocation {
          id
          clusterUuid
          name
        }
          snapshotDistribution {
          id
          onDemandCount
          retrievedCount
          scheduledCount
          totalCount
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
    $RSCVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
    # Setting variable
    $RSCVMList += $RSCVMListResponse.data.hypervVirtualMachines.edges.node
    # Getting all results from paginations
    while ($RSCVMListResponse.data.hypervVirtualMachines.pageInfo.hasNextPage) {
        # Getting next set
        $RSCGraphQL.variables.after = $RSCVMListResponse.data.hypervVirtualMachines.pageInfo.endCursor
        $RSCVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
        $RSCVMList += $RSCVMListResponse.data.hypervVirtualMachines.edges.node
    }
    ################################################
    # Processing VMs
    ################################################
    # Creating array
    $RSCVMs = [System.Collections.ArrayList]@()
    # For Each Object Getting Data
    foreach ($RSCVM in $RSCVMList) {
        # Setting variables
        $VMID = $RSCVM.id
        $VMName = $RSCVM.name
        $VMCDMID = $RSCVM.cdmId
        $VMIsRelic = $RSCVM.isRelic
        $VMProtectionDateUNIX = $RSCVM.protectionDate
        # Converting protection date
        if ($VMProtectionDateUNIX -ne $null) { $VMProtectionDateUTC = Convert-RSCUNIXTime $VMProtectionDateUNIX }else { $VMProtectionDateUTC = $null }
        # User note info
        $VMNoteInfo = $RSCVM.latestUserNote
        $VMNote = $VMNoteInfo.userNote
        $VMNoteCreator = $VMNoteInfo.userName
        $VMNoteCreatedUNIX = $VMNoteInfo.time
        if ($VMNoteCreatedUNIX -ne $null) { $VMNoteCreatedUTC = Convert-RSCUNIXTime $VMNoteCreatedUNIX }else { $VMNoteCreatedUTC = $null }
        # SLA info
        $VMSLADomainInfo = $RSCVM.effectiveSlaDomain
        $VMSLADomain = $VMSLADomainInfo.name
        $VMSLADomainID = $VMSLADomainInfo.id
        $VMSLAAssignment = $RSCVM.slaAssignment
        $VMSLAPaused = $RSCVM.slaPauseStatus
        # VM location
        $VMPhysicalPaths = $RSCVM.physicalPath
        $VMHostInfo = $VMPhysicalPaths | Where-Object { $_.objectType -eq "HypervServer" }
        $VMHostName = $VMHostInfo.name
        $VMHostID = $VMHostInfo.fid
        $VMClusterInfo = $VMPhysicalPaths | Where-Object { $_.objectType -eq "HypervCluster" }
        $VMClusterName = $VMClusterInfo.name
        $VMClusterID = $VMClusterInfo.fid
        $VMSCVMMInfo = $VMPhysicalPaths | Where-Object { $_.objectType -eq "HypervSCVMM" }
        $VMSCVMMName = $VMSCVMMInfo.name
        $VMSCVMMID = $VMSCVMMInfo.fid
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
        if ($VMSnapshotDateUNIX -ne $null) { $VMSnapshotDateUTC = Convert-RSCUNIXTime $VMSnapshotDateUNIX }else { $VMSnapshotDateUTC = $null }
        if ($VMReplicatedSnapshotDateUNIX -ne $null) { $VMReplicatedSnapshotDateUTC = Convert-RSCUNIXTime $VMReplicatedSnapshotDateUNIX }else { $VMSnVMReplicatedSnapshotDateUTCapshotDateUTC = $null }
        if ($VMArchiveSnapshotDateUNIX -ne $null) { $VMArchiveSnapshotDateUTC = Convert-RSCUNIXTime $VMArchiveSnapshotDateUNIX }else { $VMArchiveSnapshotDateUTC = $null }
        if ($VMOldestSnapshotDateUNIX -ne $null) { $VMOldestSnapshotDateUTC = Convert-RSCUNIXTime $VMOldestSnapshotDateUNIX }else { $VMOldestSnapshotDateUTC = $null }
        # Calculating hours since each snapshot
        $UTCDateTime = [System.DateTime]::UtcNow
        if ($VMSnapshotDateUTC -ne $null) { $VMSnapshotTimespan = New-TimeSpan -Start $VMSnapshotDateUTC -End $UTCDateTime; $VMSnapshotHoursSince = $VMSnapshotTimespan | Select-Object -ExpandProperty TotalHours; $VMSnapshotHoursSince = [Math]::Round($VMSnapshotHoursSince, 1) }else { $VMSnapshotHoursSince = $null }
        if ($VMReplicatedSnapshotDateUTC -ne $null) { $VMReplicatedSnapshotTimespan = New-TimeSpan -Start $VMReplicatedSnapshotDateUTC -End $UTCDateTime; $VMReplicatedSnapshotHoursSince = $VMReplicatedSnapshotTimespan | Select-Object -ExpandProperty TotalHours; $VMReplicatedSnapshotHoursSince = [Math]::Round($VMReplicatedSnapshotHoursSince, 1) }else { $VMReplicatedSnapshotHoursSince = $null }
        if ($VMArchiveSnapshotDateUTC -ne $null) { $VMArchiveSnapshotTimespan = New-TimeSpan -Start $VMArchiveSnapshotDateUTC -End $UTCDateTime; $VMArchiveSnapshotHoursSince = $VMArchiveSnapshotTimespan | Select-Object -ExpandProperty TotalHours; $VMArchiveSnapshotHoursSince = [Math]::Round($VMArchiveSnapshotHoursSince, 1) }else { $VMArchiveSnapshotHoursSince = $null }
        if ($VMOldestSnapshotDateUTC -ne $null) { $VMOldestSnapshotTimespan = New-TimeSpan -Start $VMOldestSnapshotDateUTC -End $UTCDateTime; $VMOldestSnapshotDaysSince = $VMOldestSnapshotTimespan | Select-Object -ExpandProperty TotalDays; $VMOldestSnapshotDaysSince = [Math]::Round($VMOldestSnapshotDaysSince, 1) }else { $VMOldestSnapshotDaysSince = $null }
        # Reporting data
        $VMReportInfo = $RSCVM.reportWorkload
        $VMWaitingForFirstFull = $VMReportInfo.awaitingFirstFull
        $VMProvisionedBytes = $VMReportInfo.provisionedBytes
        $VMProtectedBytes = $VMReportInfo.localProtectedData
        $VMLocalUsedBytes = $VMReportInfo.localStorage
        $VMReplicaUsedBytes = $VMReportInfo.replicaStorage
        $VMArchiveUsedBytes = $VMReportInfo.archiveStorage
        $VMLocalSnapshots = $VMReportInfo.localSlaSnapshots
        $VMReplicaSnapshots = $VMReportInfo.replicaSnapshots
        $VMArchiveSnapshots = $VMReportInfo.archiveSnapshots
        # Converting storage units
        if ($VMProvisionedBytes -ne $null) { $VMProvisionedGB = $VMProvisionedBytes / 1000 / 1000 / 1000; $VMProvisionedGB = [Math]::Round($VMProvisionedGB, 2) }else { $VMProvisionedGB = $null }
        if ($VMProtectedBytes -ne $null) { $VMProtectedGB = $VMProtectedBytes / 1000 / 1000 / 1000; $VMProtectedGB = [Math]::Round($VMProtectedGB, 2) }else { $VMProtectedGB = $null }
        if ($VMLocalUsedBytes -ne $null) { $VMLocalUsedGB = $VMLocalUsedBytes / 1000 / 1000 / 1000; $VMLocalUsedGB = [Math]::Round($VMLocalUsedGB, 2) }else { $VMLocalUsedGB = $null }
        if ($VMReplicaUsedBytes -ne $null) { $VMReplicaUsedGB = $VMReplicaUsedBytes / 1000 / 1000 / 1000; $VMReplicaUsedGB = [Math]::Round($VMReplicaUsedGB, 2) }else { $VMReplicaUsedGB = $null }
        if ($VMArchiveUsedBytes -ne $null) { $VMArchiveUsedGB = $VMArchiveUsedBytes / 1000 / 1000 / 1000; $VMArchiveUsedGB = [Math]::Round($VMArchiveUsedGB, 2) }else { $VMArchiveUsedGB = $null }
        # Calculating dedupe for storage jockeys
        if (($VMProtectedBytes -gt 1) -and ($VMLocalSnapshots -gt 1)) { $VMDedupeRatio = $VMProtectedBytes * $VMLocalSnapshots / $VMLocalUsedBytes; $VMDedupeRatio = [Math]::Round($VMDedupeRatio, 2) }else { $VMDedupeRatio = $null }
        # Primary Rubrik cluster info
        $VMRubrikCluster = $RSCVM.primaryClusterLocation.name
        $VMRubrikClusterID = $RSCVM.primaryClusterLocation.id
        # Creating object URL
        $VMURL = Get-RSCObjectURL -ObjectType "HypervVirtualMachine" -ObjectID $VMID
        # Adding To Array
        $Object = New-Object PSObject
        $Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
        # VM info
        $Object | Add-Member -MemberType NoteProperty -Name "VM" -Value $VMName
        $Object | Add-Member -MemberType NoteProperty -Name "VMID" -Value $VMID
        $Object | Add-Member -MemberType NoteProperty -Name "VMCDMID" -Value $VMCDMID
        # Protection
        $Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $VMSLADomain
        $Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $VMSLADomainID
        $Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $VMSLAAssignment
        $Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $VMSLAPaused
        $Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $VMProtectionDateUTC
        $Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $VMWaitingForFirstFull
        $Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $VMIsRelic
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
        # Rubrik cluster info
        $Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $VMID
        $Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $VMRubrikCluster
        $Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $VMRubrikClusterID
        # VM Location information
        $Object | Add-Member -MemberType NoteProperty -Name "VMHost" -Value $VMHostName
        $Object | Add-Member -MemberType NoteProperty -Name "VMHostID" -Value $VMHostID
        $Object | Add-Member -MemberType NoteProperty -Name "VMCluster" -Value $VMClusterName
        $Object | Add-Member -MemberType NoteProperty -Name "VMClusterID" -Value $VMClusterID
        $Object | Add-Member -MemberType NoteProperty -Name "SCVMM" -Value $VMSCVMMName
        $Object | Add-Member -MemberType NoteProperty -Name "SCVMMID" -Value $VMSCVMMID
        $Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $VMURL
        # Adding
        $RSCVMs.Add($Object) | Out-Null
        # End of for each object below
    }
    # End of for each object above

    # Returning array
    return $RSCVMs
    # End of function
}

