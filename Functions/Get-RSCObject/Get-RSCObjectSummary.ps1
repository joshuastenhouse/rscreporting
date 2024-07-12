################################################
# Function - Get-RSCObjectSummary - Getting summary all objects visible to the RSC instance
################################################
Function Get-RSCObjectSummary {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a summary count of objects in RSC, I.E X VMware VMs. X MSSqlDatabases. 

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectSummary
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
# Getting All Objects 
################################################
# Creating array for objects
$RSCObjects = [System.Collections.ArrayList]@()
$RSCObjectsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "snappableConnection";

"variables" = @{
"first" = 1000
};

"query" = "query snappableConnection(`$after: String) {
  snappableConnection(after: `$after, first: 1000) {
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
        logicalBytes
        logicalDataReduction
        missedSnapshots
        name
        objectType
        physicalBytes
        protectedOn
        protectionStatus
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
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
# Getting all results from paginations
While ($RSCObjectsResponse.data.snappableConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectsResponse.data.snappableConnection.pageInfo.endCursor
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
}
################################################
# Processing All Objects 
################################################
# Counting
$RSCObjectsCount = $RSCObjectsList | Measure-Object | Select-Object -ExpandProperty Count
# Processing Objects
$RSCObjectsCounter = 0
# For Each Object Getting Data
ForEach ($RSCObject in $RSCObjectsList)
{
$RSCObjectsCounter ++
# Write-Host "ProcessingObject: $PolarisObjectsCounter/$PolarisObjectsCount"
# Setting variables
$ObjectID = $RSCObject.id
$ObjectFID = $RSCObject.fid
$ObjectName = $RSCObject.name
$ObjectLocation = $RSCObject.location
$ObjectType = $RSCObject.objectType
$ObjectSLADomainInfo = $RSCObject.slaDomain
$ObjectSLADomain = $ObjectSLADomainInfo.name
$ObjectSLADomainID = $ObjectSLADomainInfo.id
$ObjectTotalSnapshots = $RSCObject.totalSnapshots
$ObjectLastSnapshot = $RSCObject.lastSnapshot
$ObjectPendingFirstFull = $RSCObject.awaitingFirstFull
$ObjectProtectionStatus = $RSCObject.protectionStatus
$ObjectProtectedOn = $RSCObject.protectedOn
$ObjectLastUpdated = $RSCObject.pulltime
$ObjectClusterInfo = $RSCObject.cluster
$ObjectClusterID = $ObjectClusterInfo.id
$ObjectClusterName = $ObjectClusterInfo.name
# Overriding Polaris in cluster name
IF($ObjectClusterName -eq "Polaris"){$ObjectClusterName = "RSC-Native"}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $ObjectClusterName
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ObjectLocation
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "ProtectionStatus" -Value $ObjectProtectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $ObjectProtectedOn
# Snapshot info
$Object | Add-Member -MemberType NoteProperty -Name "TotalSnapshots" -Value $ObjectTotalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $ObjectLastSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $ObjectPendingFirstFull
$Object | Add-Member -MemberType NoteProperty -Name "LastUpdated" -Value $ObjectLastUpdated
# IDs
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $ObjectClusterID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectFID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ObjectSLADomainID
# Adding
$RSCObjects.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Selecting unique objects
$UniqueObjectTypes = $RSCObjects | Sort-Object Type | Select-Object -ExpandProperty Type -Unique
 # Creating array
$RSCObjectSummary = [System.Collections.ArrayList]@()
# For each type getting counts
ForEach($UniqueObjectType in $UniqueObjectTypes)
{
# Selecting objects
$UniqueObjects = $RSCObjects | Where-Object {$_.Type -eq $UniqueObjectType}
# Counting
$UniqueObjectsCount = $UniqueObjects | Measure-Object | Select-Object -ExpandProperty Count
$UniqueProtectedObjects = $UniqueObjects | Where-Object {$_.ProtectionStatus -eq "Protected"} | Measure-Object| Select-Object -ExpandProperty Count
$UniqueUnProtectedObjects = $UniqueObjects | Where-Object {$_.ProtectionStatus -eq "NoSla"} | Measure-Object | Select-Object -ExpandProperty Count
$UniqueDoNotProtectObjects = $UniqueObjects | Where-Object {$_.ProtectionStatus -eq "DoNotProtect"} | Measure-Object | Select-Object -ExpandProperty Count
$UniquePendingFirstFullObjects = $UniqueObjects | Where-Object {$_.PendingFirstFull -eq "True"} | Measure-Object | Select-Object -ExpandProperty Count
$UniqueRubrikClusters = $UniqueObjects | Select-Object -ExpandProperty ClusterID -Unique | Measure-Object | Select-Object -ExpandProperty Count
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $UniqueObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Total" -Value $UniqueObjectsCount
$Object | Add-Member -MemberType NoteProperty -Name "Protected" -Value $UniqueProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "Unprotected" -Value $UniqueUnProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtect" -Value $UniqueDoNotProtectObjects
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $UniquePendingFirstFullObjects
# Adding
$RSCObjectSummary.Add($Object) | Out-Null
}
# Summarizing all
$UniqueObjectsCount = $RSCObjects | Measure-Object | Select-Object -ExpandProperty Count
$UniqueProtectedObjects = $RSCObjects | Where-Object {$_.ProtectionStatus -eq "Protected"} | Measure-Object| Select-Object -ExpandProperty Count
$UniqueUnProtectedObjects = $RSCObjects | Where-Object {$_.ProtectionStatus -eq "NoSla"} | Measure-Object | Select-Object -ExpandProperty Count
$UniqueDoNotProtectObjects = $RSCObjects | Where-Object {$_.ProtectionStatus -ne "DoNotProtect"} | Measure-Object | Select-Object -ExpandProperty Count
$UniquePendingFirstFullObjects = $RSCObjects | Where-Object {$_.PendingFirstFull -eq "True"} | Measure-Object | Select-Object -ExpandProperty Count
$UniqueRubrikClusters = $RSCObjects | Select-Object -ExpandProperty ClusterID -Unique | Measure-Object | Select-Object -ExpandProperty Count
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "ALL"
$Object | Add-Member -MemberType NoteProperty -Name "Total" -Value $UniqueObjectsCount
$Object | Add-Member -MemberType NoteProperty -Name "Protected" -Value $UniqueProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "Unprotected" -Value $UniqueUnProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtect" -Value $UniqueDoNotProtectObjects
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $UniquePendingFirstFullObjects
# Adding
$RSCObjectSummary.Add($Object) | Out-Null


# Returning array
Return $RSCObjectSummary
# End of function
}
