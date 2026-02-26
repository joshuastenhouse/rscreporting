################################################
# Function - Get-RSCObjectStorageUsage - Getting all RSC Object Storage Usage
################################################
function Get-RSCObjectStorageUsage {

    <#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of every object in RSC and it's current storage usage stats.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectStorageUsage
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

    ################################################
    # Paramater Config
    ################################################
    param
    (
        [Parameter(Mandatory = $false)]$RubrikClusterID
    )
    ################################################
    # Importing Module & Running Required Functions
    ################################################
    # Importing the module is it needs other modules
    Import-Module RSCReporting
    # Checking connectivity, exiting function with error if not connected
    Test-RSCConnection
    # Getting objects list if not already pulled as a global variable in this session
    # IF($RSCGlobalObjects -eq $null){$RSCObjects = Get-RSCObjects -Logging;$Global:RSCGlobalObjects = $RSCObjects}ELSE{$RSCObjects = $RSCGlobalObjects}
    ################################################
    # Getting RSC Objects
    ################################################
    # Creating array for events
    $ObjectStorageList = @()
    # Building GraphQL query
    $RSCGraphQL = @{"operationName" = "CapacityTableQuery";

        "variables"                 = @{
            "first" = 1000
        };

        "query"                     = "query CapacityTableQuery(`$first: Int!, `$after: String) {
  snappableConnection(first: `$first, after: `$after) {
    edges {
      cursor
      node {
        id
        fid
        name
        objectType
        cluster {
          id
          name
          __typename
        }
        slaDomain {
          id
          name
          ... on GlobalSlaReply {
            isRetentionLockedSla
            __typename
          }
          ... on ClusterSlaDomain {
            isRetentionLockedSla
            __typename
          }
          __typename
        }
        location
        physicalBytes
        transferredBytes
        logicalBytes
        replicaStorage
        archiveStorage
        dataReduction
        logicalDataReduction
        lastSnapshotLogicalBytes
        pullTime
        localStorage
        localMeteredData
        usedBytes
        provisionedBytes
        localProtectedData
        localEffectiveStorage
        orgName
        __typename
      }
      __typename
    }
    pageInfo {
      endCursor
      hasNextPage
      __typename
    }
    __typename
  }
}"
    }
    ################################################
    # Adding Variables to GraphQL Query
    ################################################
    # Converting to JSON
    $RSCJSON = $RSCGraphQL | ConvertTo-Json -Depth 32
    # Converting back to PS object for editing of variables
    $RSCJSONObject = $RSCJSON | ConvertFrom-Json
    # Adding variables specified
    if ($RubrikClusterID -ne $null) { $RSCJSONObject.variables.filters | Add-Member -MemberType NoteProperty "clusterId" -Value $RubrikClusterID }
    ################################################
    # API Call To RSC GraphQL URI
    ################################################
    # Querying API
    $ObjectStorageResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCJSONObject | ConvertTo-Json -Depth 32) -Headers $RSCSessionHeader
    $ObjectStorageList += $ObjectStorageResponse.data.snappableConnection.edges.node
    # Getting all results from paginations
    while ($ObjectStorageResponse.data.snappableConnection.pageInfo.hasNextPage) {
        # Getting next set
        $RSCJSONObject.variables | Add-Member -MemberType NoteProperty "after" -Value $ObjectStorageResponse.data.snappableConnection.pageInfo.endCursor -Force
        $ObjectStorageResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCJSONObject | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
        $ObjectStorageList += $ObjectStorageResponse.data.snappableConnection.edges.node
    }
    # Counting
    $ObjectStorageListCount = $ObjectStorageList | Measure-Object | Select-Object -ExpandProperty Count
    $ObjectStorageListCounter = 0
    ################################################
    # Processing Objects
    ################################################
    $RSCObjectStorageUsage = [System.Collections.ArrayList]@()
    # For Each Getting info
    foreach ($ObjectListed in $ObjectStorageList) {
        $ObjectStorageListCounter ++
        Write-Host "ProcessingObject: $ObjectStorageListCounter/$ObjectStorageListCount"
        # Setting variables
        $ObjectName = $ObjectListed.name
        $ObjectID = $ObjectListed.fid
        $ObjectCDMID = $ObjectListed.id
        $ObjectType = $ObjectListed.objectType
        $ObjectLocation = $ObjectListed.location
        $RubrikCluster = $ObjectListed.cluster.name
        $RubrikClusterID = $ObjectListed.cluster.id
        $SLADomain = $ObjectListed.slaDomain.name
        $SLADomainID = $ObjectListed.slaDomain.id
        $SLADomainIsRetentionLocked = $ObjectListed.slaDomain.isRetentionLockedSla
        $LastUpdatedUNIX = $ObjectListed.pullTime
        $OrgName = $ObjectListed.orgName
        # Getting data from object list
        # $ObjectListData = $RSCObjects | Where-Object {$_.ObjectID -eq $ObjectID}
        # $ProtectedOn = $ObjectListData.ProtectedOn
        # $LastSnapshot = $ObjectListData.LastSnapshot
        # $PendingFirstFull = $ObjectListData.PendingFirstFull
        # $TotalSnapshots = $ObjectListData.TotalSnapshots;IF($TotalSnapshots -eq $null){$TotalSnapshots = 0}
        # Getting URL
        $ObjectURL = $ObjectListData.URL
        # Fixing cluster name
        if ($RubrikCluster -eq "Polaris") { $RubrikCluster = "RSC-Native" }
        # Converting time
        if ($LastUpdatedUNIX -ne $null) { $LastUpdatedUTC = Convert-RSCUNIXTime $LastUpdatedUNIX }else { $LastUpdatedUTC = $null }
        # Data reduction stats
        $DataReduction = $ObjectListed.dataReduction
        $LogicalDataReduction = $ObjectListed.logicalDataReduction
        # Getting storage stats
        $physicalBytes = $ObjectListed.physicalBytes
        $transferredBytes = $ObjectListed.transferredBytes
        $logicalBytes = $ObjectListed.logicalBytes
        $replicaStorage = $ObjectListed.replicaStorage
        $archiveStorage = $ObjectListed.archiveStorage
        $lastSnapshotLogicalBytes = $ObjectListed.lastSnapshotLogicalBytes
        $localStorage = $ObjectListed.localStorage
        $localMeteredData = $ObjectListed.localMeteredData
        $usedBytes = $ObjectListed.usedBytes
        $provisionedBytes = $ObjectListed.provisionedBytes
        $localProtectedData = $ObjectListed.localProtectedData
        $localEffectiveStorage = $ObjectListed.localEffectiveStorage
        # Converting storage units
        if ($physicalBytes -ne $null) { $PhysicalGB = $physicalBytes / 1000 / 1000 / 1000 }else { $PhysicalGB = $null }
        if ($transferredBytes -ne $null) { $TransferredGB = $transferredBytes / 1000 / 1000 / 1000 }else { $TransferredGB = $null }
        if ($logicalBytes -ne $null) { $LogicalGB = $logicalBytes / 1000 / 1000 / 1000 }else { $LogicalGB = $null }
        if ($replicaStorage -ne $null) { $ReplicaStorageGB = $replicaStorage / 1000 / 1000 / 1000 }else { $ReplicaStorageGB = $null }
        if ($archiveStorage -ne $null) { $ArchiveStorageGB = $archiveStorage / 1000 / 1000 / 1000 }else { $ArchiveStorageGB = $null }
        if ($lastSnapshotLogicalBytes -ne $null) { $LastSnapshotLogicalGB = $lastSnapshotLogicalBytes / 1000 / 1000 / 1000 }else { $LastSnapshotLogicalGB = $null }
        if ($localStorage -ne $null) { $LocalStorageGB = $localStorage / 1000 / 1000 / 1000 }else { $LocalStorageGB = $null }
        if ($localMeteredData -ne $null) { $LocalMeteredDataGB = $localMeteredData / 1000 / 1000 / 1000 }else { $LocalMeteredDataGB = $null }
        if ($usedBytes -ne $null) { $UsedGB = $usedBytes / 1000 / 1000 / 1000 }else { $UsedGB = $null }
        if ($provisionedBytes -ne $null) { $ProvisionedGB = $provisionedBytes / 1000 / 1000 / 1000 }else { $ProvisionedGB = $null }
        if ($localProtectedData -ne $null) { $LocalProtectedGB = $localProtectedData / 1000 / 1000 / 1000 }else { $LocalProtectedGB = $null }
        if ($localEffectiveStorage -ne $null) { $LocalEffectiveStorageGB = $localEffectiveStorage / 1000 / 1000 / 1000 }else { $LocalEffectiveStorageGB = $null }
        # Getting totals
        $TotalUsedBytes = $localStorage + $archiveStorage + $replicaStorage
        if ($TotalUsedBytes -ne $null) { $TotalUsedGB = $TotalUsedBytes / 1000 / 1000 / 1000; $TotalUsedGB = [Math]::Round($TotalUsedGB, 2) }else { $TotalUsedGB = $null }
        # Rounding
        if ($TotalUsedGB -ne $null) { $TotalUsedGB = [Math]::Round($TotalUsedGB, 2) }
        if ($PhysicalGB -ne $null) { $PhysicalGB = [Math]::Round($PhysicalGB, 2) }
        if ($TransferredGB -ne $null) { $TransferredGB = [Math]::Round($TransferredGB, 2) }
        if ($LogicalGB -ne $null) { $LogicalGB = [Math]::Round($LogicalGB, 2) }
        if ($ReplicaStorageGB -ne $null) { $ReplicaStorageGB = [Math]::Round($ReplicaStorageGB, 2) }
        if ($ArchiveStorageGB -ne $null) { $ArchiveStorageGB = [Math]::Round($ArchiveStorageGB, 2) }
        if ($LastSnapshotLogicalGB -ne $null) { $LastSnapshotLogicalGB = [Math]::Round($LastSnapshotLogicalGB, 2) }
        if ($LocalStorageGB -ne $null) { $LocalStorageGB = [Math]::Round($LocalStorageGB, 2) }
        if ($LocalMeteredDataGB -ne $null) { $LocalMeteredDataGB = [Math]::Round($LocalMeteredDataGB, 2) }
        if ($UsedGB -ne $null) { $UsedGB = [Math]::Round($UsedGB, 2) }
        if ($ProvisionedGB -ne $null) { $ProvisionedGB = [Math]::Round($ProvisionedGB, 2) }
        if ($LocalProtectedGB -ne $null) { $LocalProtectedGB = [Math]::Round($LocalProtectedGB, 2) }
        if ($LocalProtectedGB -ne $null) { $LocalProtectedGB = [Math]::Round($LocalProtectedGB, 2) }
        if ($LocalEffectiveStorageGB -ne $null) { $LocalEffectiveStorageGB = [Math]::Round($LocalEffectiveStorageGB, 2) }
        ############################
        # Adding To Array
        ############################
        $Object = New-Object PSObject
        $Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
        $Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
        $Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
        $Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $ObjectCDMID
        $Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ObjectType
        $Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ObjectLocation
        $Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikCluster
        $Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
        $Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
        $Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
        $Object | Add-Member -MemberType NoteProperty -Name "Org" -Value $OrgName
        $Object | Add-Member -MemberType NoteProperty -Name "SLADomainRetentionLock" -Value $SLADomainIsRetentionLocked
        # Other useful info
        $Object | Add-Member -MemberType NoteProperty -Name "LastUpdatedUTC" -Value $LastUpdatedUTC
        # $Object | Add-Member -MemberType NoteProperty -Name "TotalSnapshots" -Value $TotalSnapshots
        # $Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $ProtectedOn
        # $Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $LastSnapshot
        # $Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $PendingFirstFull
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
        # URL
        $Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
        # Adding to array
        $RSCObjectStorageUsage.Add($Object) | Out-Null
        #
        # End of for each object below
    }
    # End of for each object above

    # Assigning to global array
    $Global:RSCObjectStorageUsage = $RSCObjectStorageUsage

    # Returning array
    return $RSCObjectStorageUsage
    # End of function
}

