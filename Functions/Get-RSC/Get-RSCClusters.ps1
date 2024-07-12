################################################
# Function - Get-RSCClusters - Getting CDM Clusters attached to RSC
################################################
Function Get-RSCClusters {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning every Rubrik cluster and associated useful information.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCClusters
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
# Getting objects
$RSCObjects = Get-RSCObjects -Logging
################################################
# Getting All Clusters 
################################################
# Building GraphQL query
$RSCGraphQL = @{"query" = "query clusterConnection {
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
        licensedProducts
        timezone
        pauseStatus
        registeredMode
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
# RSCReporting SDK
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
$RSCClusters = [System.Collections.ArrayList]@()
ForEach ($RSCCluster in $RSCClusterList)
{
# Setting variables
$Cluster = $RSCCluster.name
$ClusterID = $RSCCluster.id
$ClusterVersion = $RSCCluster.version
$ClusterStatus = $RSCCluster.status
$ClusterType = $RSCCluster.type
$ClusterProduct = $RSCCluster.productType
$ClusterEncrypted = $RSCCluster.encryptionEnabled
$ClusterSnapshots = $RSCCluster.snapshotCount
$ClusterRunwayDays = $RSCCluster.estimatedRunway
$ClusterNodes = $RSCCluster.clusterNodeConnection.nodes
$ClusterDisks = $RSCCluster.clusterDiskConnection.nodes
$ClusterLocation = $RSCCluster.geoLocation
$ClusterArhivalLocations = $RSCCluster.archivalLocations
$ClusterReplicationTargets = $RSCCluster.replicationSources
$ClusterReplicationSources = $RSCCluster.replicationTargets
$ClusterLastConnectedUNIX = $RSCCluster.lastConnectionTime
$ClusterUpgradeInfo = $RSCCluster.cdmUpgradeInfo
$ClusterVersionStatus = $ClusterUpgradeInfo.versionStatus
# Added 05/08/23
$ClusterTimezone = $RSCCluster.timezone
$ClusterPauseStatus = $RSCCluster.pauseStatus
$ClusterRegisteredUNIX = $RSCCluster.registrationTime
IF($ClusterRegisteredUNIX -ne $null){$ClusterRegisteredUTC = Convert-RSCUNIXTime $ClusterRegisteredUNIX}ELSE{$ClusterRegisteredUTC = $null}
# Converting
IF($ClusterLastConnectedUNIX -ne $null){$ClusterLastConnectedUTC = Convert-RSCUNIXTime $ClusterLastConnectedUNIX}ELSE{$ClusterLastConnectedUTC = $null}
$UTCDateTime = [System.DateTime]::UtcNow
IF($ClusterLastConnectedUTC -ne $null){$ClusterLastConnectedTimespan = New-TimeSpan -Start $ClusterLastConnectedUTC -End $UTCDateTime;$ClusterLastConnectedHoursSince = $ClusterLastConnectedTimespan | Select-Object -ExpandProperty TotalHours;$ClusterLastConnectedHoursSince = [Math]::Round($ClusterLastConnectedHoursSince,1)}ELSE{$ClusterLastConnectedHoursSince = $null}
IF($ClusterLastConnectedUTC -ne $null){$ClusterLastConnectedMinutesSince = $ClusterLastConnectedTimespan | Select-Object -ExpandProperty TotalMinutes;$ClusterLastConnectedMinutesSince = [Math]::Round($ClusterLastConnectedMinutesSince)}ELSE{$ClusterLastConnectedMinutesSince = $null}
# Getting cluster location
IF ($ClusterLocation -ne $null)
{
$ClusterAddress = $ClusterLocation.address
$ClusterLatitude = $ClusterLocation.latitude
$ClusterLongitude = $ClusterLocation.longitude
}
############################
# Cluster Stats
############################
# Selecting storage Bytes
$ClusterStorage = $RSCCluster.metric
$ClusterTotalStorageBytes = $ClusterStorage.totalCapacity
$ClusterUsedStorageBytes = $ClusterStorage.usedCapacity
$ClusterFreeStorageBytes = $ClusterStorage.availableCapacity
# Adding additional storage counts
$ClusterSnapshotStorageBytes = $ClusterStorage.snapshotCapacity
$ClusterLiveMountStorageBytes = $ClusterStorage.liveMountCapacity
# Converting to GB
$ClusterLiveMountStorageGB = $ClusterLiveMountStorageBytes / 1000 / 1000 / 1000
$ClusterLiveMountStorageGB = [Math]::Round($ClusterLiveMountStorageGB,2)
$ClusterFreeStorageGB = $ClusterFreeStorageBytes / 1000 / 1000 / 1000
$ClusterFreeStorageGB = [Math]::Round($ClusterFreeStorageGB,2)
# Converting to TB
$ClusterTotalStorageTB = $ClusterTotalStorageBytes / 1000 / 1000 / 1000 / 1000
$ClusterUsedStorageTB = $ClusterUsedStorageBytes / 1000 / 1000 / 1000 / 1000
$ClusterFreeStorageTB = $ClusterFreeStorageBytes / 1000 / 1000 / 1000 / 1000
$ClusterSnapshotStorageTB = $ClusterSnapshotStorageBytes / 1000 / 1000 / 1000 / 1000
$ClusterLiveMountStorageTB = $ClusterLiveMountStorageBytes / 1000 / 1000 / 1000 / 1000
# Rounding to 2 decimal places
$ClusterTotalStorageTB = [Math]::Round($ClusterTotalStorageTB,2)
$ClusterUsedStorageTB = [Math]::Round($ClusterUsedStorageTB,2)
$ClusterFreeStorageTB = [Math]::Round($ClusterFreeStorageTB,2)
$ClusterSnapshotStorageTB = [Math]::Round($ClusterSnapshotStorageTB,2)
$ClusterLiveMountStorageTB = [Math]::Round($ClusterLiveMountStorageTB,2)
# Calculating percentage used space
$ClusterUsedPercentage = ($ClusterUsedStorageTB/$ClusterTotalStorageTB).tostring("P1")
$ClusterUsedPercentageInt = ($ClusterUsedStorageTB/$ClusterTotalStorageTB)*100
$ClusterUsedPercentageInt = [Math]::Round($ClusterUsedPercentageInt,2)
# Calculating percentage free space
$ClusterFreePercentage = ($ClusterFreeStorageTB/$ClusterTotalStorageTB).tostring("P1")
$ClusterFreePercentageInt = ($ClusterFreeStorageTB/$ClusterTotalStorageTB)*100
$ClusterFreePercentageInt = [Math]::Round($ClusterFreePercentageInt,2)
# Counts
$ClusterNodesCount = $ClusterNodes | Measure-Object | Select-Object -ExpandProperty Count
$ClusterDisksCount = $ClusterDisks | Measure-Object | Select-Object -ExpandProperty Count
$ClusterArchiveTargetCount = $ClusterArhivalLocations | Measure-Object | Select-Object -ExpandProperty Count
$ClusterReplicationTargetCount = $ClusterReplicationTargets | Measure-Object | Select-Object -ExpandProperty Count
$ClusterReplicationSourceCount = $ClusterReplicationSources | Measure-Object | Select-Object -ExpandProperty Count
# Counts by health
$ClusterHealthyNodesCount = $ClusterNodes | Where-Object {$_.status -eq "OK"} | Measure-Object | Select-Object -ExpandProperty Count
$ClusterBadNodesCount = $ClusterNodes | Where-Object {$_.status -ne "OK"} | Measure-Object | Select-Object -ExpandProperty Count
$ClusterHealthyDisksCount = $ClusterDisks | Where-Object {$_.status -eq "ACTIVE"} | Measure-Object | Select-Object -ExpandProperty Count
$ClusterBadDisksCount = $ClusterDisks | Where-Object {$_.status -ne "ACTIVE"} | Measure-Object | Select-Object -ExpandProperty Count
############################
# Cluster Protected Objects
############################
$RSCClusterObjects = $RSCObjects | Where-Object {$_.RubrikClusterID -eq $ClusterID}
# Getting protected object count
$RSCClusterProtectedObjects = $RSCClusterObjects | Where-Object {$_.ProtectionStatus -eq "Protected"} | Measure-Object | Select-Object -ExpandProperty Count
$RSCClusterUnProtectedObjects = $RSCClusterObjects | Where-Object {$_.ProtectionStatus -eq "NoSla"} | Measure-Object | Select-Object -ExpandProperty Count
$RSCClusterDoNotProtectedObjects = $RSCClusterObjects | Where-Object {$_.ProtectionStatus -eq "DoNotProtect"} | Measure-Object | Select-Object -ExpandProperty Count
# Creating URL
$ClusterClusterURL = $RSCURL + "/clusters/" + $ClusterID + "/overview"
############################
# Deciding Cluster Status More Intelligently than RSC!
############################
$ClusterStatus = "Healthy";$ClusterError = $null
# Rule 1 - Bad nodes
IF($ClusterBadNodesCount -gt 0){$ClusterStatus = "Degraded";$ClusterError = "Bad nodes"}
# Rule 2 - Bad dsisks
IF($ClusterBadDisksCount -gt 0){$ClusterStatus = "Degraded";$ClusterError = "Bad disks"}
# Rule 3 - Less than 5 PC space free
IF($ClusterFreePercentageInt -lt 10){$ClusterStatus = "Degraded";$ClusterError = "Low space"}
# Rule 4 - Not connected in 6 hours
IF($ClusterLastConnectedHoursSince -gt 6){$ClusterStatus = "Degraded";$ClusterError = "No connection";$ClusterConnectionStatus = "Disconnected"}ELSE{$ClusterConnectionStatus = "Connected"}
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $Cluster
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $ClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $ClusterStatus
$Object | Add-Member -MemberType NoteProperty -Name "Errors" -Value $ClusterError
$Object | Add-Member -MemberType NoteProperty -Name "Version" -Value $ClusterVersion
$Object | Add-Member -MemberType NoteProperty -Name "VersionStatus" -Value $ClusterVersionStatus
# Status etc
$Object | Add-Member -MemberType NoteProperty -Name "ConnectionStatus" -Value $ClusterConnectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "LastConnected" -Value $ClusterLastConnectedUTC
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $ClusterLastConnectedHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "MinutesSince" -Value $ClusterLastConnectedMinutesSince
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ClusterType
$Object | Add-Member -MemberType NoteProperty -Name "Product" -Value $ClusterProduct
$Object | Add-Member -MemberType NoteProperty -Name "Encrypted" -Value $ClusterEncrypted
$Object | Add-Member -MemberType NoteProperty -Name "Snapshots" -Value $ClusterSnapshots
# Objects
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedObjects" -Value $RSCClusterProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "UnProtectedObjects" -Value $RSCClusterUnProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtectObjects" -Value $RSCClusterDoNotProtectedObjects
# Location
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ClusterAddress
$Object | Add-Member -MemberType NoteProperty -Name "Latitude" -Value $ClusterLatitude
$Object | Add-Member -MemberType NoteProperty -Name "Longitude" -Value $ClusterLongitude
$Object | Add-Member -MemberType NoteProperty -Name "Timezone" -Value $ClusterTimezone
# Storage
$Object | Add-Member -MemberType NoteProperty -Name "TotalStorageTB" -Value $ClusterTotalStorageTB
$Object | Add-Member -MemberType NoteProperty -Name "UsedStorageTB" -Value $ClusterUsedStorageTB
$Object | Add-Member -MemberType NoteProperty -Name "FreeStorageTB" -Value $ClusterFreeStorageTB
$Object | Add-Member -MemberType NoteProperty -Name "Used" -Value $ClusterUsedPercentage
$Object | Add-Member -MemberType NoteProperty -Name "Free" -Value $ClusterFreePercentage
$Object | Add-Member -MemberType NoteProperty -Name "UsedINT" -Value $ClusterUsedPercentageINT
$Object | Add-Member -MemberType NoteProperty -Name "FreeINT" -Value $ClusterFreePercentageINT
$Object | Add-Member -MemberType NoteProperty -Name "RunwayDays" -Value $ClusterRunwayDays
# Cluster info
$Object | Add-Member -MemberType NoteProperty -Name "TotalNodes" -Value $ClusterNodesCount
$Object | Add-Member -MemberType NoteProperty -Name "BadNodes" -Value $ClusterBadNodesCount
$Object | Add-Member -MemberType NoteProperty -Name "HealthyNodes" -Value $ClusterHealthyNodesCount
$Object | Add-Member -MemberType NoteProperty -Name "TotalDisks" -Value $ClusterDisksCount
$Object | Add-Member -MemberType NoteProperty -Name "BadDisks" -Value $ClusterBadDisksCount
$Object | Add-Member -MemberType NoteProperty -Name "HealthyDisks" -Value $ClusterHealthyDisksCount
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveTargets" -Value $ClusterArchiveTargetCount
$Object | Add-Member -MemberType NoteProperty -Name "ReplicationTargets" -Value $ClusterReplicationTargetCount
$Object | Add-Member -MemberType NoteProperty -Name "ReplicationSources" -Value $ClusterReplicationSourceCount
# Misc
$Object | Add-Member -MemberType NoteProperty -Name "PauseStatus" -Value $ClusterPauseStatus
$Object | Add-Member -MemberType NoteProperty -Name "RegisteredUTC" -Value $ClusterRegisteredUTC
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ClusterClusterURL
# Adding
$RSCClusters.Add($Object) | Out-Null
# End of for each cluster below
}
# End of for each cluster above

# Returning array
Return $RSCClusters
# End of function
}
