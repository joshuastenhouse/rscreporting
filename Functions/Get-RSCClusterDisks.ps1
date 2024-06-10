################################################
# Function - Get-RSCClusterDisks - Getting CDM Cluster Disks in each node attached to RSC
################################################
Function Get-RSCClusterDisks {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of every disk on every Rubrik cluster.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCClusterDisks
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
# Getting RSC Cluster Disks
################################################
# Creating array
$RSCClusterList = @()
# Creating query
$RSCGraphQL = @{"operationName" = "clusterConnection";

"variables" = @{
"first" = 1000
};

"query" = "query clusterConnection {
  clusterConnection {
    edges {
      node {
        connectivityLastUpdated
        defaultAddress
        encryptionEnabled
        estimatedRunway
        id
        isHealthy
        lastConnectionTime
        name
        passesConnectivityCheck
        productType
        registrationTime
        snapshotCount
        status
        type
        version
        clusterNodeConnection {
            nodes {
            brikId
            needsInspection
            id
            status
            ipAddress
            }
            count
        }
        clusterDiskConnection {
          count
          nodes {
            capacityBytes
            clusterId
            diskType
            id
            isEncrypted
            nodeId
            path
            status
            unallocatedBytes
            usableBytes
          }
        }
        state {
          connectedState
          clusterRemovalUpdatedAt
          clusterRemovalState
          clusterRemovalCreatedAt
        }
        metric {
            totalCapacity
            availableCapacity
            ingestedSnapshotStorage
            lastUpdateTime
            liveMountCapacity
            miscellaneousCapacity
            physicalSnapshotStorage
            snapshotCapacity
            usedCapacity
        }
        geoLocation {
            address
            latitude
            longitude
        }
        cdmUpgradeInfo {
          version
          versionStatus
          previousVersion
        }
        replicationSources {
          id
          sourceClusterAddress
          sourceClusterName
          sourceClusterUuid
          totalStorage
        }
        replicationTargets {
          id
          targetClusterAddress
          targetClusterName
          targetClusterUuid
          totalStorage
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
$RSCClusterListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCClusterList += $RSCClusterListResponse.data.clusterConnection.edges.node
# Getting all results from paginations
While ($RSCClusterListResponse.data.clusterConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCClusterListResponse.data.clusterConnection.pageInfo.endCursor
$RSCClusterListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCClusterList += $RSCClusterListResponse.data.clusterConnection.edges.node
}
############################
# Starting For Each Cluster
############################
$RSCClusterDisks = [System.Collections.ArrayList]@()
ForEach ($RSCCluster in $RSCClusterList)
{
# Setting variables
$Cluster = $RSCCluster.name
$ClusterID = $RSCCluster.id
$ClusterVersion = $RSCCluster.version
$ClusterStatus = $RSCCluster.passesConnectivityCheck
$ClusterIsHealthy = $RSCCluster.isHealthy
$ClusterType = $RSCCluster.type
$ClusterProduct = $RSCCluster.productType
$ClusterEncrypted = $RSCCluster.encryptionEnabled
$ClusterSnapshots = $RSCCluster.snapshotCount
$ClusterRunwayDays = $RSCCluster.estimatedRunway
$ClusterNodes = $RSCCluster.clusterNodeConnection.nodes
$ClusterDisks = $RSCCluster.clusterDiskConnection.nodes
$ClusterLocation = $RSCCluster.geoLocation
# Getting cluster location
IF ($ClusterLocation -ne $null)
{
$ClusterAddress = $ClusterLocation.address
$ClusterLatitude = $ClusterLocation.latitude
$ClusterLongitude = $ClusterLocation.longitude
}
# Adding each disk
ForEach ($ClusterDisk in $ClusterDisks)
{
# Setting variables
$ClusterDiskFullNodeID = $ClusterDisk.nodeId
$ClusterDiskStatus = $ClusterDisk.status
$ClusterDiskType = $ClusterDisk.diskType
$ClusterDiskID = $ClusterDisk.id
$ClusterDiskEncryption = $ClusterDisk.isEncrypted
# Getting shorthand node ID
$ClusterDiskNodeID = $ClusterDiskFullNodeID.Replace("cluster:::","")
# Creating URL for disks
$ClusterDiskURL = $RSCURL + "/clusters/" + $ClusterID + "/nodes/" + $ClusterDiskNodeID
# https://rubrik-gaia.my.rubrik.com/clusters/e711ef1b-83cb-4679-9ef7-44c4de751102/nodes/RVMHM21AS002647
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $Cluster
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $ClusterID
$Object | Add-Member -MemberType NoteProperty -Name "NodeID" -Value $ClusterDiskNodeID
$Object | Add-Member -MemberType NoteProperty -Name "FullNodeID" -Value $ClusterDiskFullNodeID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ClusterDiskType
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $ClusterDiskStatus
$Object | Add-Member -MemberType NoteProperty -Name "ID" -Value $ClusterDiskID
$Object | Add-Member -MemberType NoteProperty -Name "Encrypted" -Value $ClusterDiskEncryption
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ClusterDiskURL
$RSCClusterDisks.Add($Object) | Out-Null
}
# End of for each cluster below
}
# End of for each cluster above

Return $RSCClusterDisks
# End of function
}
