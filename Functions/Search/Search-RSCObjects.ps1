################################################
# Function - Search-RSCObjects - Search RSC Objects by name
################################################
Function Search-RSCObjects {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that searches for objects by name.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Search-RSCObjects
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/30/2025
#>
################################################
# Paramater Config
################################################
Param
    (
        [Parameter(Mandatory=$true)]$ObjectName
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting All Objects 
################################################
# Setting first value if null
IF($ObjectQueryLimit -eq $null){$ObjectQueryLimit = 1000}
# Creating array for objects
$RSCObjectsList = @()
# Building GraphQL query
$RSCGraphQL = @{

"variables" = @{
"first" = $ObjectQueryLimit
"filter" = @{
        "searchTerm" = $ObjectName
        }
};

"query" = "query nodes(`$filter: SnappableFilterInputWithSearch, `$first: Int) {
  searchSnappableConnection(filter: `$filter, first: `$first) {
      nodes {
        fid
        id
        name
        location
        objectType
        objectState
        lastSnapshot
        slaDomain {
          id
          name
        }
        protectionStatus
        protectedOn
        totalSnapshots
        replicaSnapshots
        archiveSnapshots
        latestArchivalSnapshot
        latestReplicationSnapshot
        complianceStatus
        archivalComplianceStatus
        replicationComplianceStatus
        cluster {
          id
          name
        }
      }
    }
}"
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
$RSCObjectsList += $RSCObjectsResponse.data.searchSnappableConnection.nodes
# Counters
$ObjectCount = 0
$ObjectCounter = $ObjectCount + $ObjectQueryLimit
# Getting all results from paginations
While ($RSCObjectsResponse.data.searchSnappableConnection.pageInfo.hasNextPage) 
{
# Logging
# Write-Host "GettingObjects: $ObjectCount-$ObjectCounter"
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectsResponse.data.searchSnappableConnection.pageInfo.endCursor
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectsList += $RSCObjectsResponse.data.searchSnappableConnection.nodes
# Incrementing
$ObjectCount = $ObjectCount + $ObjectQueryLimit
$ObjectCounter = $ObjectCounter + $ObjectQueryLimit
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
$ObjectLastSnapshot = $RSCObject.lastSnapshot
$ObjectProtectionStatus = $RSCObject.protectionStatus
$ObjectProtectedOn = $RSCObject.protectedOn
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
# Deciding if relic 
IF($ObjectComplianceStatus -eq "NOT_APPLICABLE"){$ObjectIsRelic = $TRUE}ELSE{$ObjectIsRelic = $FALSE}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $ObjectIsRelic
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ObjectLocation
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ObjectClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $ObjectClusterID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ObjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "ProtectionStatus" -Value $ObjectProtectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "ComplianceStatus" -Value $ObjectComplianceStatus
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveComplianceStatus" -Value $ObjectArchiveComplianceStatus
$Object | Add-Member -MemberType NoteProperty -Name "ReplicationComplianceStatus" -Value $ObjectReplicationComplianceStatus
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $ObjectProtectedOn
# Snapshot info
$Object | Add-Member -MemberType NoteProperty -Name "TotalSnapshots" -Value $ObjectTotalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshots" -Value $ObjectArchivedSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnaphots" -Value $ObjectReplicatedSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $ObjectLastSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $ObjectSnapshotGapHours
# Replication info
$Object | Add-Member -MemberType NoteProperty -Name "LastReplicatedSnapshot" -Value $ObjectLastReplicatedSnapshot
# Archive info
$Object | Add-Member -MemberType NoteProperty -Name "LastArchivedSnapshot" -Value $ObjectLastArhiveSnapshot
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCObjects.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCObjects
# End of function
}
