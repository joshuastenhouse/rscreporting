################################################
# Creating the Get-RSCObjectDetail function
################################################
Function Get-RSCObjectDetail {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that returns all the data for the objectID available on the snappableConnection API.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.
.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
A valid ObjectID in RSC, use Get-RSCObjects to obtain.
.PARAMETER MaxSnapshots
Uses 30 by default unless specified otherwise with this param.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectDetail -ObectID "32ffrferf-erferf-erferfe"
This example returns all the info available on the API for the ObjectID specified.

.NOTES
Author: Joshua Stenhouse
Date: 08/20/2024
#>
################################################
# Paramater Config
################################################
[CmdletBinding(DefaultParameterSetName = "List")]
Param(
      [Parameter(
          ParameterSetName = "ObjectID",
          Mandatory = $true, 
          ValueFromPipelineByPropertyName = $true
      )]
      [String]$ObjectID
  )

# Example: $ObjectSnapshots= Get-RSCObjectSnapshots -ObjectID "$ObjectID"

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Running Main Function
################################################
$RSCGraphQL = @{"operationName" = "snappableConnection";

"variables" = @{
    "filter" = @{
        "objectFid" = "$ObjectID"
}
};

"query" = "query snappableConnection(`$filter: SnappableFilterInput) {
  snappableConnection(filter: `$filter) {
    edges {
      node {
        id
        fid
        name
        slaDomain {
          id
          name
        }
        awaitingFirstFull
        cluster {
          id
          name
        }
        lastSnapshot
        localSnapshots
        localStorage
        location
        logicalBytes
        logicalDataReduction
        missedSnapshots
        localSlaSnapshots
        localProtectedData
        localOnDemandSnapshots
        localMeteredData
        localEffectiveStorage
        latestReplicationSnapshot
        latestArchivalSnapshot
        lastSnapshotLogicalBytes
        dataReduction
        complianceStatus
        archivalComplianceStatus
        archivalSnapshotLag
        archiveSnapshots
        archiveStorage
        objectState
        objectType
        physicalBytes
        protectedOn
        protectionStatus
        provisionedBytes
        pullTime
        replicaSnapshots
        replicaStorage
        replicationComplianceStatus
        replicationSnapshotLag
        sourceProtocol
        totalSnapshots
        transferredBytes
        usedBytes
        orgId
        workloadOrg {
          fullName
          id
          name
        }
      }
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
Try
{
$ObjectResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Headers $RSCSessionHeader -Body $($RSCGraphQL | ConvertTo-JSON -Depth 10)
$RSCObject = $ObjectResponse.data.snappableConnection.edges.node
}
Catch
{
# If error nulling as objectID not found
$RSCObject = $null
}
# Breaking if objectID not found
IF($RSCObject -eq $null)
{
Write-Error "ERROR: ObjectID not found, check and try again.."
Start-Sleep 2
Break
}
################################################
# Getting & Converting Object Data
################################################
# Creating array
$RSCObjects = [System.Collections.ArrayList]@()
# Setting variables
$ObjectCDMID = $RSCObject.id
$ObjectID = $RSCObject.fid
$ObjectName = $RSCObject.name
$ObjectComplianceStatus = $RSCObject.complianceStatus
$ObjectLocation = $RSCObject.location
$ObjectType = $RSCObject.objectType
$ObjectSLADomainInfo = $RSCObject.slaDomain
$ObjectSLADomain = $ObjectSLADomainInfo.name
$ObjectSLADomainID = $ObjectSLADomainInfo.id
$ObjectTotalSnapshots = $RSCObject.totalSnapshots
$ObjectLocalSnapshots = $RSCObject.localSnapshots
$ObjectLastSnapshot = $RSCObject.lastSnapshot
$ObjectReplicatedSnapshots = $RSCObject.replicaSnapshots
$ObjectArchivedSnapshots = $RSCObject.archiveSnapshots
$ObjectPendingFirstFull = $RSCObject.awaitingFirstFull
$ObjectProtectionStatus = $RSCObject.protectionStatus
$ObjectProtectedOn = $RSCObject.protectedOn
$ObjectLastUpdated = $RSCObject.pulltime
$ObjectClusterInfo = $RSCObject.cluster
$ObjectClusterID = $ObjectClusterInfo.id
$ObjectClusterName = $ObjectClusterInfo.name
$ObjectLastReplicatedSnapshot = $RSCObject.latestReplicationSnapshot
$ObjectLastArhiveSnapshot = $RSCObject.latestArchivalSnapshot
# Getting current time
$UTCDateTime = [System.DateTime]::UtcNow
# Converting UNIX times if not null
IF($ObjectProtectedOn -ne $null){$ObjectProtectedOn = Convert-RSCUNIXTime $ObjectProtectedOn}
IF($ObjectLastSnapshot -ne $null){$ObjectLastSnapshot = Convert-RSCUNIXTime $ObjectLastSnapshot}
IF($ObjectLastUpdated -ne $null){$ObjectLastUpdated = Convert-RSCUNIXTime $ObjectLastUpdated}
IF($ObjectLastReplicatedSnapshot -ne $null){$ObjectLastReplicatedSnapshot = Convert-RSCUNIXTime $ObjectLastReplicatedSnapshot}
IF($ObjectLastArhiveSnapshot -ne $null){$ObjectLastArhiveSnapshot = Convert-RSCUNIXTime $ObjectLastArhiveSnapshot}
# If last snapshot not null, calculating hours since
IF($ObjectLastSnapshot -ne $null)
{
$ObjectSnapshotGap = New-Timespan -Start $ObjectLastSnapshot -End $UTCDateTime
$ObjectSnapshotGapHours = $ObjectSnapshotGap.TotalHours
$ObjectSnapshotGapHours = [Math]::Round($ObjectSnapshotGapHours, 1)
}
ELSE
{
$ObjectSnapshotGapHours = $null	
}
# Overriding Polaris in cluster name
IF($ObjectClusterName -eq "Polaris"){$ObjectClusterName = "RSC-Native"}
# Overriding location to RSC if null
IF($ObjectLocation -eq ""){
# No account info in location for cloud native EC2/AWS/GCP etc, so for now just saying the cloud
IF($ObjectType -match "Azure"){$ObjectLocation = "Azure"}
IF($ObjectType -match "Ec2Instance"){$ObjectLocation = "AWS"}
IF($ObjectType -match "Gcp"){$ObjectLocation = "GCP"}
}
# Getting object URL
$ObjectURL = Get-RSCObjectURL -ObjectType $ObjectType -ObjectID $ObjectID
# Getting SLA domain & replication info
$RSCSLADomainInfo = $RSCSLADomains | Where-Object {$_.SLADomainID -eq $ObjectSLADomainID}
IF($RSCSLADomainInfo.Replication -eq $True){$ObjectISReplicated = $TRUE}ELSE{$ObjectISReplicated = $FALSE}
$ObjectReplicationTargetClusterID = $RSCSLADomainInfo.ReplicationTargetClusterID
# If replicated, determining if source or target
IF($ObjectISReplicated -eq $TRUE)
{
# Main rule, matching cluster
IF($ObjectClusterID -eq $ObjectReplicationTargetClusterID){$ObjectReplicaType = "Target"}ELSE{$ObjectReplicaType = "Source"}
}
ELSE
{
$ObjectReplicaType = "N/A"
}
# Deciding if object should be reported on for snapshots/compliance
IF(($ObjectProtectionStatus -eq "Protected") -and ($ObjectReplicaType -ne "Target")){$ObjectReportOnCompliance = $TRUE}ELSE{$ObjectReportOnCompliance = $FALSE}
# Deciding if relic 
IF($ObjectComplianceStatus -eq "NOT_APPLICABLE"){$ObjectIsRelic = $TRUE}ELSE{$ObjectIsRelic = $FALSE}
# Overridng $ObjectReportOnCompliance if relic
IF($ObjectIsRelic -eq $TRUE){$ObjectReportOnCompliance = $FALSE}
# Overriding if compliance is empty, as this means it's a replica target
IF($ObjectComplianceStatus -eq "EMPTY"){$ObjectReportOnCompliance = $FALSE}
# Data reduction stats
$DataReduction = $RSCObject.dataReduction
$LogicalDataReduction = $RSCObject.logicalDataReduction
# Getting storage stats
$physicalBytes = $RSCObject.physicalBytes
$transferredBytes = $RSCObject.transferredBytes
$logicalBytes = $RSCObject.logicalBytes
$replicaStorage = $RSCObject.replicaStorage
$archiveStorage = $RSCObject.archiveStorage
$lastSnapshotLogicalBytes = $RSCObject.lastSnapshotLogicalBytes
$localStorage = $RSCObject.localStorage
$localMeteredData = $RSCObject.localMeteredData
$usedBytes = $RSCObject.usedBytes
$provisionedBytes = $RSCObject.provisionedBytes
$localProtectedData = $RSCObject.localProtectedData
$localEffectiveStorage = $RSCObject.localEffectiveStorage
# Converting storage units
IF($physicalBytes -ne $null){$PhysicalGB = $physicalBytes / 1000 / 1000 / 1000}ELSE{$PhysicalGB = $null}
IF($transferredBytes -ne $null){$TransferredGB = $transferredBytes / 1000 / 1000 / 1000}ELSE{$TransferredGB = $null}
IF($logicalBytes -ne $null){$LogicalGB = $logicalBytes / 1000 / 1000 / 1000}ELSE{$LogicalGB = $null}
IF($replicaStorage -ne $null){$ReplicaStorageGB = $replicaStorage / 1000 / 1000 / 1000}ELSE{$ReplicaStorageGB = $null}
IF($archiveStorage -ne $null){$ArchiveStorageGB = $archiveStorage / 1000 / 1000 / 1000}ELSE{$ArchiveStorageGB = $null}
IF($lastSnapshotLogicalBytes -ne $null){$LastSnapshotLogicalGB = $lastSnapshotLogicalBytes / 1000 / 1000 / 1000}ELSE{$LastSnapshotLogicalGB = $null}
IF($localStorage -ne $null){$LocalStorageGB = $localStorage / 1000 / 1000 / 1000}ELSE{$LocalStorageGB = $null}
IF($localMeteredData -ne $null){$LocalMeteredDataGB = $localMeteredData / 1000 / 1000 / 1000}ELSE{$LocalMeteredDataGB = $null}
IF($usedBytes -ne $null){$UsedGB = $usedBytes / 1000 / 1000 / 1000}ELSE{$UsedGB = $null}
IF($provisionedBytes -ne $null){$ProvisionedGB = $provisionedBytes / 1000 / 1000 / 1000}ELSE{$ProvisionedGB = $null}
IF($localProtectedData -ne $null){$LocalProtectedGB = $localProtectedData / 1000 / 1000 / 1000}ELSE{$LocalProtectedGB = $null}
IF($localEffectiveStorage -ne $null){$LocalEffectiveStorageGB = $localEffectiveStorage / 1000 / 1000 / 1000}ELSE{$LocalEffectiveStorageGB = $null}
# Getting totals
$TotalUsedBytes = $localStorage + $archiveStorage + $replicaStorage
IF($TotalUsedBytes -ne $null){$TotalUsedGB = $TotalUsedBytes / 1000 / 1000 / 1000;$TotalUsedGB = [Math]::Round($TotalUsedGB,2)}ELSE{$TotalUsedGB = $null}
# Rounding
IF($TotalUsedGB -ne $null){$TotalUsedGB = [Math]::Round($TotalUsedGB,2)}
IF($PhysicalGB -ne $null){$PhysicalGB = [Math]::Round($PhysicalGB,2)}
IF($TransferredGB -ne $null){$TransferredGB = [Math]::Round($TransferredGB,2)}
IF($LogicalGB -ne $null){$LogicalGB = [Math]::Round($LogicalGB,2)}
IF($ReplicaStorageGB -ne $null){$ReplicaStorageGB = [Math]::Round($ReplicaStorageGB,2)}
IF($ArchiveStorageGB -ne $null){$ArchiveStorageGB = [Math]::Round($ArchiveStorageGB,2)}
IF($LastSnapshotLogicalGB -ne $null){$LastSnapshotLogicalGB = [Math]::Round($LastSnapshotLogicalGB,2)}
IF($LocalStorageGB -ne $null){$LocalStorageGB = [Math]::Round($LocalStorageGB,2)}
IF($LocalMeteredDataGB -ne $null){$LocalMeteredDataGB = [Math]::Round($LocalMeteredDataGB,2)}
IF($UsedGB -ne $null){$UsedGB = [Math]::Round($UsedGB,2)}
IF($ProvisionedGB -ne $null){$ProvisionedGB = [Math]::Round($ProvisionedGB,2)}
IF($LocalProtectedGB -ne $null){$LocalProtectedGB = [Math]::Round($LocalProtectedGB,2)}
IF($LocalProtectedGB -ne $null){$LocalProtectedGB = [Math]::Round($LocalProtectedGB,2)}
IF($LocalEffectiveStorageGB -ne $null){$LocalEffectiveStorageGB = [Math]::Round($LocalEffectiveStorageGB,2)}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ObjectClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $ObjectClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ObjectLocation
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ObjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "ProtectionStatus" -Value $ObjectProtectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "ComplianceStatus" -Value $ObjectComplianceStatus
$Object | Add-Member -MemberType NoteProperty -Name "ReportOnCompliance" -Value $ObjectReportOnCompliance
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $ObjectProtectedOn
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $ObjectIsRelic
# Snapshot info
$Object | Add-Member -MemberType NoteProperty -Name "TotalSnapshots" -Value $ObjectTotalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LocalSnapshots" -Value $ObjectLocalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $ObjectLastSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $ObjectSnapshotGapHours
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $ObjectPendingFirstFull
# Replication info
$Object | Add-Member -MemberType NoteProperty -Name "Replicated" -Value $ObjectISReplicated
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaType" -Value $ObjectReplicaType
$Object | Add-Member -MemberType NoteProperty -Name "LastReplicatedSnapshot" -Value $ObjectLastReplicatedSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnaphots" -Value $ObjectReplicatedSnapshots
# Archive info
$Object | Add-Member -MemberType NoteProperty -Name "LastArchivedSnapshot" -Value $ObjectLastArhiveSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshots" -Value $ObjectArchivedSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LastUpdated" -Value $ObjectLastUpdated
# Data reduction
$Object | Add-Member -MemberType NoteProperty -Name "DataReduction" -Value $DataReduction
$Object | Add-Member -MemberType NoteProperty -Name "LogicalDataReduction" -Value $LogicalDataReduction
# Storage stats in GB
$Object | Add-Member -MemberType NoteProperty -Name "TotalUsedGB" -Value $TotalUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedGB" -Value $PhysicalGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalStorageGB" -Value $LocalStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "TransferredGB" -Value $TransferredGB
$Object | Add-Member -MemberType NoteProperty -Name "LogicalGB" -Value $LogicalGB
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaStorageGB" -Value $ReplicaStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveStorageGB" -Value $ArchiveStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshotLogicalGB" -Value $LastSnapshotLogicalGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalMeteredDataGB" -Value $LocalMeteredDataGB
$Object | Add-Member -MemberType NoteProperty -Name "UsedGB" -Value $UsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedGB" -Value $ProvisionedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalProtectedGB" -Value $LocalProtectedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalEffectiveStorageGB" -Value $LocalEffectiveStorageGB
# Storage stats in bytes
$Object | Add-Member -MemberType NoteProperty -Name "TotalUsedBytes" -Value $TotalUsedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedBytes" -Value $physicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalStorageBytes" -Value $localStorage
$Object | Add-Member -MemberType NoteProperty -Name "TransferredBytes" -Value $transferredBytes
$Object | Add-Member -MemberType NoteProperty -Name "LogicalBytes" -Value $logicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaStorageBytes" -Value $replicaStorage
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveStorageBytes" -Value $archiveStorage
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshotLogicalBytes" -Value $lastSnapshotLogicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalMeteredDataBytes" -Value $localMeteredData
$Object | Add-Member -MemberType NoteProperty -Name "UsedBytes" -Value $usedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedBytes" -Value $provisionedBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalProtectedBytes" -Value $localProtectedData
$Object | Add-Member -MemberType NoteProperty -Name "LocalEffectiveStorageBytes" -Value $localEffectiveStorage
# Misc
$Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $ObjectCDMID
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCObjects.Add($Object) | Out-Null

# Sample object IDs for testing
# $ObjectID = "a6dc29cb-dd15-540a-94c8-96977a943648"
# $ObjectID = "a6dc29cb-dd15-540a-94c8-96977a9436480-bb"

# Returning Result
Return $RSCObjects
}