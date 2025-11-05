################################################
# Function - Get-RSCObjects - Getting all objects visible to the RSC instance
################################################
Function Get-RSCObjects {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of every protectable object in RSC. Useful for obtaining ObjectIDs.

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
        [Parameter(ParameterSetName="User")][switch]$Logging,
        [Parameter(ParameterSetName="User")][switch]$DisableLogging,
        [Parameter(ParameterSetName="User")][switch]$IncludeOldestSnapshot,
        [Parameter(ParameterSetName="User")][switch]$SampleObjects,
        [Parameter(Mandatory=$false)]$ObjectQueryLimit
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting RSC SLA Domains
Write-Host "QueryingSLADomains.."
$RSCSLADomains = Get-RSCSLADomains
$RSCSLADomainCount = $RSCSLADomains | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "SLADomainsFound: $RSCSLADomainCount"
# Warning if switch used
IF($IncludeOldestSnapshot){Write-Host "WARNING: This may take a long time as it queries every protected object for it's last snapshot.."}
################################################
# Getting All Objects 
################################################
# Setting first value if null
IF($ObjectQueryLimit -eq $null){$ObjectQueryLimit = 1000}
# Logging if set
IF($ObjectType -ne $null){Write-Host "QueryingObjects: $ObjectType"}
# Creating array for objects
$RSCObjectsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "snappableConnection";

"variables" = @{
"first" = $ObjectQueryLimit
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
$ObjectCounter = $ObjectCount + $ObjectQueryLimit
# Getting all results from paginations, unless sampling
IF($SampleObjects){}ELSE{
While ($RSCObjectsResponse.data.snappableConnection.pageInfo.hasNextPage) 
{
# Logging
IF($DisableLogging){}ELSE{Write-Host "GettingObjects: $ObjectCount-$ObjectCounter"}
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectsResponse.data.snappableConnection.pageInfo.endCursor
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
# Incrementing
$ObjectCount = $ObjectCount + $ObjectQueryLimit
$ObjectCounter = $ObjectCounter + $ObjectQueryLimit
}
}
################################################
# Processing All Objects 
################################################
# Creating array
$RSCObjects = [System.Collections.ArrayList]@()
# Counting
$RSCObjectsCount = $RSCObjectsList | Measure-Object | Select-Object -ExpandProperty Count
$RSCObjectsCounter = 0
# Getting current time for last snapshot age
$UTCDateTime = [System.DateTime]::UtcNow
# Processing
ForEach ($RSCObject in $RSCObjectsList)
{
# Logging
$RSCObjectsCounter ++
IF($DisableLogging){}ELSE{Write-Host "ProcessingObject: $RSCObjectsCounter/$RSCObjectsCount"}
# Setting variables
$ObjectCDMID = $RSCObject.id
$ObjectID = $RSCObject.fid
$ObjectName = $RSCObject.name
$ObjectLocation = $RSCObject.location
$ObjectType = $RSCObject.objectType
$ObjectSLADomainInfo = $RSCObject.slaDomain
$ObjectSLADomain = $ObjectSLADomainInfo.name
$ObjectSLADomainID = $ObjectSLADomainInfo.id
$ObjectTotalSnapshots = $RSCObject.totalSnapshots
$ObjectMissedSnapshots = $RSCObject.missedSnapshots
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
# Compliance statuses
$ObjectComplianceStatus = $RSCObject.complianceStatus
$ObjectArchiveComplianceStatus = $RSCObject.archivalComplianceStatus
$ObjectReplicationComplianceStatus = $RSCObject.replicationComplianceStatus
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
# Getting additional SLA domain info
$ObjectSLADailyFrequency = $RSCSLADomainInfo.DailyFrequency
$ObjectSLADailyRetention = $RSCSLADomainInfo.DailyRetention
# If replicated, determining if source or target
IF($ObjectISReplicated -eq $TRUE)
{
# Main rule, matching cluster
IF($ObjectClusterID -eq $ObjectReplicationTargetClusterID){$ObjectReplicaType = "Target"}ELSE{$ObjectReplicaType = "Source"}
}
ELSE
{
# Not replicated
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
# Adding get oldest backup if set and object should be reported on for compliance
IF(($IncludeOldestSnapshot) -and ($ObjectProtectionStatus -eq "Protected")){$ObjectOldestSnapshot = Get-RSCObjectOldestSnapshot -ObjectID $ObjectID | Select-Object -ExpandProperty DateUTC}ELSE{$ObjectOldestSnapshot = $null}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ObjectClusterName
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ObjectLocation
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "DailyFrequency" -Value $ObjectSLADailyFrequency
$Object | Add-Member -MemberType NoteProperty -Name "DailyRetention" -Value $ObjectSLADailyRetention
$Object | Add-Member -MemberType NoteProperty -Name "ProtectionStatus" -Value $ObjectProtectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "ComplianceStatus" -Value $ObjectComplianceStatus
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveComplianceStatus" -Value $ObjectArchiveComplianceStatus
$Object | Add-Member -MemberType NoteProperty -Name "ReplicationComplianceStatus" -Value $ObjectReplicationComplianceStatus
$Object | Add-Member -MemberType NoteProperty -Name "ReportOnCompliance" -Value $ObjectReportOnCompliance
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $ObjectProtectedOn
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $ObjectIsRelic
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $ObjectPendingFirstFull
# Snapshot info
$Object | Add-Member -MemberType NoteProperty -Name "TotalSnapshots" -Value $ObjectTotalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "MissedSnapshots" -Value $ObjectMissedSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LocalSnapshots" -Value $ObjectLocalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $ObjectLastSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $ObjectSnapshotGapHours
# Including oldest snapshot if switch selected
IF($IncludeOldestSnapshot){$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshot" -Value $ObjectOldestSnapshot}
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

# Setting global variable for use in other functions so they don't have to collect it again, unless it was a sample
IF($SampleObjects){}ELSE{$Global:RSCGlobalObjects = $RSCObjects}

# Returning array
Return $RSCObjects
# End of function
}
