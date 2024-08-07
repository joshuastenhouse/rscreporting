################################################
# Function - Get-RSCVMs - Getting all VMs visible to the RSC instance
################################################
Function Get-RSCVMs {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of every protectable VMs in RSC. Useful for obtaining ObjectIDs.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjects
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
        $ObjectType,
        [Parameter(ParameterSetName="User")][switch]$Logging
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting RSC SLA Domains
$RSCSLADomains = Get-RSCSLADomains
# Setting ObjectTypes that are VMs
$RSCObjectTypes = "AzureNativeVm","Ec2Instance","GcpNativeGCEInstance","HypervVirtualMachine","NutanixVirtualMachine","VmwareVirtualMachine"
# Creating array
$RSCObjects = [System.Collections.ArrayList]@()
################################################
# Getting All Objects 
################################################
ForEach($ObjectType in $RSCObjectTypes)
{ 
# Logging if set
IF($ObjectType -ne $null){Write-Host "QueryingObjects: $ObjectType"}
# Creating array for objects
$RSCObjectsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "snappableConnection";

"variables" = @{
"first" = 1000
"filter" = @{
        "objectType" = $ObjectType
        }
};

"query" = "query snappableConnection(`$after: String, `$filter: SnappableFilterInput) {
  snappableConnection(after: `$after, first: 1000, filter: `$filter) {
    edges {
      node {
        archivalComplianceStatus
        archivalSnapshotLag
        archiveSnapshots
        archiveStorage
        awaitingFirstFull
        complianceStatus
        dataReduction
        fid
        id
        lastSnapshot
        latestArchivalSnapshot
        latestReplicationSnapshot
        localOnDemandSnapshots
        location
        localSnapshots
        localStorage
        localEffectiveStorage
        logicalBytes
        logicalDataReduction
        missedSnapshots
        name
        usedBytes
        objectType
        physicalBytes
        protectedOn
        protectionStatus
        provisionedBytes
        pullTime
        replicaSnapshots
        replicaStorage
        replicationComplianceStatus
        slaDomain {
          id
          name
          version
        }
        replicationSnapshotLag
        totalSnapshots
        transferredBytes
        cluster {
          id
          name
        }
      }
    }
        pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      __typename
    }
  }
}
"
}
# Converting to JSON
$RSCJSON = $RSCGraphQL | ConvertTo-Json -Depth 32
# Converting back to PS object for editing of variables
$RSCJSONObject = $RSCJSON | ConvertFrom-Json
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCJSONObject | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
# Counters
$ObjectCount = 0
$ObjectCounter = $ObjectCount + 1000
# Getting all results from paginations
While ($RSCObjectsResponse.data.snappableConnection.pageInfo.hasNextPage) 
{
# Logging
IF($Logging){Write-Host "GettingObjects: $ObjectCount-$ObjectCounter"}
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectsResponse.data.snappableConnection.pageInfo.endCursor
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
# Incrementing
$ObjectCount = $ObjectCount + 1000
$ObjectCounter = $ObjectCounter + 1000
}
################################################
# Processing All Objects 
################################################
# Counting
$RSCObjectsCount = $RSCObjectsList | Measure-Object | Select-Object -ExpandProperty Count
# Processing Objects
$RSCObjectsCounter = 0
# Getting current time for last snapshot age
$UTCDateTime = [System.DateTime]::UtcNow
# For Each Object Getting Data
ForEach ($RSCObject in $RSCObjectsList)
{
$RSCObjectsCounter ++
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
# Converting UNIX times if not null
IF($ObjectProtectedOn -ne $null){$ObjectProtectedOn = Convert-RSCUNIXTime $ObjectProtectedOn}
IF($ObjectLastSnapshot -ne $null){$ObjectLastSnapshot = Convert-RSCUNIXTime $ObjectLastSnapshot}
IF($ObjectLastUpdated -ne $null){$ObjectLastUpdated = Convert-RSCUNIXTime $ObjectLastUpdated}
IF($ObjectLastReplicatedSnapshot -ne $null){$ObjectLastReplicatedSnapshot = Convert-RSCUNIXTime $ObjectLastReplicatedSnapshot}
IF($ObjectLastArhiveSnapshot -ne $null){$ObjectLastArhiveSnapshot = Convert-RSCUNIXTime $ObjectLastArhiveSnapshot}
# If last snapshot not null, calculating hours since
IF($ObjectLastSnapshot -ne $null){
$ObjectSnapshotGap = New-Timespan -Start $ObjectLastSnapshot -End $UTCDateTime
$ObjectSnapshotGapHours = $ObjectSnapshotGap.TotalHours
$ObjectSnapshotGapHours = [Math]::Round($ObjectSnapshotGapHours, 1)
}
ELSE
{
$ObjectSnapshotGapHours = $null	
}
# If protected on not null, calculating hours since
IF($ObjectProtectedOn -ne $null){
$ObjectProtectedOnGap = New-Timespan -Start $ObjectProtectedOn -End $UTCDateTime
$ObjectProtectedDays = $ObjectProtectedOnGap.TotalDays
$ObjectProtectedDays = [Math]::Round($ObjectProtectedDays,1)
}
ELSE
{
$ObjectProtectedDays = $null
}
# Overriding Polaris in cluster name
IF($ObjectClusterName -eq "Polaris"){$ObjectClusterName = "RSC-Native"}
# Overriding location to RSC if null
IF($ObjectLocation -eq ""){
# No account info in location for cloud native EC2/AWS/GCP etc, so for now just saying the cloud
IF($ObjectType -match "Azure"){$ObjectLocation = "Azure"}
IF($ObjectType -match "Aws"){$ObjectLocation = "AWS"}
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
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ObjectClusterName
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ObjectLocation
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "ProtectionStatus" -Value $ObjectProtectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "ComplianceStatus" -Value $ObjectComplianceStatus
$Object | Add-Member -MemberType NoteProperty -Name "ReportOnCompliance" -Value $ObjectReportOnCompliance
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $ObjectProtectedOn
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedDays" -Value $ObjectProtectedDays
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $ObjectIsRelic
# Snapshot info
$Object | Add-Member -MemberType NoteProperty -Name "TotalSnapshots" -Value $ObjectTotalSnapshots
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
# IDs
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $ObjectCDMID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ObjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $ObjectClusterID
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCObjects.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# End of for each object type below
}
# End of for each object type above

# Returning array
Return $RSCObjects
# End of function
}
