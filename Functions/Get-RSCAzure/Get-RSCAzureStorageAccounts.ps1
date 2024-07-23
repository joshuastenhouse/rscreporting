################################################
# Function - Get-RSCAzureStorageAccounts - Getting All Azure Storage Accounts connected to RSC
################################################
Function Get-RSCAzureStorageAccounts {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all Storage accounts in all Azure subscriptions/accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAzureStorageAccounts
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 07/09/2024
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Querying RSC GraphQL API
################################################
# Creating array for objects
$RSCList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AzureBlobStorageAccountListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query AzureBlobStorageAccountListQuery(`$first: Int, `$sortBy: HierarchySortByField, `$sortOrder: SortOrder, `$filter: [Filter!], `$after: String) {
  azureNativeRoot {
    objectTypeDescendantConnection(objectTypeFilter: AZURE_STORAGE_ACCOUNT, first: `$first, sortBy: `$sortBy, sortOrder: `$sortOrder, filter: `$filter, after: `$after) {
      edges {
        cursor
        node {
          id
          name
          isRelic
          ...AzureBlobStorageAccountContainersColumnFragment
          ...AzureBlobStorageAccountSubscriptionColumnFragment
          region
          slaAssignment
          ...EffectiveSlaColumnFragment
          ... on AzureStorageAccount {
            usedCapacityBytes
            accessTier
            accountKind
            isHierarchicalNamespaceEnabled
            __typename
            isRelic
            name
            nativeName
            numContainers
            objectType
            region
            resourceGroup {
              id
              name
            }
            slaAssignment
            slaPauseStatus
            tags {
              key
              value
            }
            newestSnapshot {
              id
              date
            }
            cloudNativeId
            effectiveSlaDomain {
              id
              name
              ... on GlobalSlaReply {
                isRetentionLockedSla
              }
            }
            snapshotDistribution {
              onDemandCount
              retrievedCount
              scheduledCount
              totalCount
            }
            numWorkloadDescendants
            securityMetadata {
              highSensitiveHits
              lowSensitiveHits
              mediumSensitiveHits
              sensitivityStatus
            }
          }
          __typename
        }
        __typename
      }
      pageInfo {
        endCursor
        hasNextPage
        hasPreviousPage
        __typename
      }
      __typename
    }
    __typename
  }
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
    retentionLockMode
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
    retentionLockMode
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

fragment AzureBlobStorageAccountContainersColumnFragment on AzureStorageAccount {
  numContainers
  __typename
}

fragment AzureBlobStorageAccountSubscriptionColumnFragment on AzureStorageAccount {
  resourceGroup {
    name
    subscription {
      id
      name
      status: azureSubscriptionStatus
      nativeId: azureSubscriptionNativeId
      __typename
    }
    __typename
  }
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.azureNativeRoot.objectTypeDescendantConnection.edges.node
# Getting all results from activeDirectoryDomains
While ($RSCResponse.data.azureNativeRoot.objectTypeDescendantConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.azureNativeRoot.objectTypeDescendantConnection.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.azureNativeRoot.objectTypeDescendantConnection.edges.node
}
################################################
# Processing Objects
################################################
# Creating array
$RSCAzureStorageAccounts = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Storage in $RSCList)
{
# Setting variables
$Name = $Storage.id
$ID = $Storage.name
$Region = $Storage.region
$NativeID = $Storage.nativeName
$AccessTier = $Storage.accessTier
$Type = $Storage.accountKind
$Containers = $Storage.numContainers
$UsedBytes = $Storage.usedCapacityBytes
$Snapshots = $Storage.snapshotDistribution.totalCount
$SLADomain = $Storage.effectiveSlaDomain.name
$SLADomainID = $Storage.effectiveSlaDomain.id
$PauseStatus = $Storage.slaPauseStatus
$SLAAssignment = $Storage.slaAssignment
$IsRelic = $Storage.isRelic
$Tags = $Storage.tags
$TagCount = $Tags | Measure-Object | Select-Object -ExpandProperty Count
$Account = $Storage.resourceGroup.subscription.name
$AccountID = $Storage.resourceGroup.subscription.id
$AccountStatus = $Storage.resourceGroup.subscription.status
# Converting storage units
IF($UsedBytes -ne $null){$UsedGB = $UsedBytes / 1000 / 1000 / 1000;$UsedGB = [Math]::Round($UsedGB,2)}ELSE{$UsedGB = $null}
# Snapshot info
$SnapshotDateUNIX = $Storage.newestSnapshot.date
$SnapshotDateID = $Storage.newestSnapshot.id
IF($SnapshotDateUNIX -ne $null){$SnapshotDateUTC = Convert-RSCUNIXTime $SnapshotDateUNIX}ELSE{$SnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($SnapshotDateUTC -ne $null){$SnapshotTimespan = New-TimeSpan -Start $SnapshotDateUTC -End $UTCDateTime;$SnapshotHoursSince = $SnapshotTimespan | Select-Object -ExpandProperty TotalHours;$SnapshotHoursSince = [Math]::Round($SnapshotHoursSince,1)}ELSE{$SnapshotHoursSince = $null}
# Getting URL
$URL = Get-RSCObjectURL -ObjectType "AzureStorageAccount" -ObjectID $ID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "StorageAccount" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "StorageAccountID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $Region
$Object | Add-Member -MemberType NoteProperty -Name "AccessTier" -Value $AccessTier
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $Type
$Object | Add-Member -MemberType NoteProperty -Name "Containers" -Value $Containers
$Object | Add-Member -MemberType NoteProperty -Name "UsedBytes" -Value $UsedBytes
$Object | Add-Member -MemberType NoteProperty -Name "UsedGB" -Value $UsedGB
$Object | Add-Member -MemberType NoteProperty -Name "Snapshots" -Value $Snapshots
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTC" -Value $SnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTCAgeHours" -Value $SnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "TagsAssigned" -Value $TagCount
$Object | Add-Member -MemberType NoteProperty -Name "Tags" -Value $Tags
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "PauseStatus" -Value $PauseStatus
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $SLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $IsRelic
$Object | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $Account
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $AccountID
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionStatus" -Value $AccountStatus
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $URL
# Adding
$RSCAzureStorageAccounts.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCAzureStorageAccounts
# End of function
}