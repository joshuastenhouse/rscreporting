################################################
# Function - Get-RSCArchiveTargets - Getting Archive Targets connected to RSC
################################################
Function Get-RSCArchiveTargets {

<#
.SYNOPSIS
Returns all Archive Targets configured within RSC.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCArchiveTargets
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
# Querying RSC GraphQL API
################################################
# Creating array for objects
$RSCList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "DcStorageLocationsListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query DcStorageLocationsListQuery(`$first: Int, `$after: String) {
  targets(first: `$first,after: `$after) {
    edges {
      cursor
      node {
        id
        name
        cluster {
          id
          name
          status
          __typename
        }
        targetMapping {
          id
          name
          __typename
        }
        targetType
        status
        locationScope
        consumedBytes
        failedTasks
        runningTasks
        locationConnectionStatus
        ... on RubrikManagedAwsTarget {
          awsRegion: region
          syncStatus
          immutabilitySettings {
            lockDurationDays
            __typename
          }
          __typename
        }
        ... on RubrikManagedAzureTarget {
          instanceType
          immutabilitySettings {
            lockDurationDays
            __typename
          }
          syncStatus
          __typename
        }
        ... on RubrikManagedGcpTarget {
          gcpRegion: region
          syncStatus
          __typename
        }
        ... on RubrikManagedNfsTarget {
          host
          syncStatus
          __typename
        }
        ... on RubrikManagedS3CompatibleTarget {
          endpoint
          syncStatus
          immutabilitySetting {
            bucketLockDurationDays
            __typename
          }
          __typename
        }
        ... on RubrikManagedRcsTarget {
          rcsRegion: region
          tier
          storageConsumptionValue
          immutabilityPeriodDays
          syncStatus
          privateEndpointConnection {
            privateEndpointId
            privateEndpointConnectionStatus
            __typename
          }
          clusterIpMapping {
            clusterUuid
            ips
            __typename
          }
          __typename
        }
        ... on RubrikManagedGlacierTarget {
          awsRegion: region
          syncStatus
          __typename
        }
        ... on CdmManagedAwsTarget {
          awsRegion: region
          immutabilitySettings {
            lockDurationDays
            __typename
          }
          immutabilitySettings {
            lockDurationDays
            __typename
          }
          __typename
        }
        ... on CdmManagedAzureTarget {
          instanceType
          immutabilitySettings {
            lockDurationDays
            __typename
          }
          immutabilitySettings {
            lockDurationDays
            __typename
          }
          __typename
        }
        ... on CdmManagedGcpTarget {
          gcpRegion: region
          __typename
        }
        ... on CdmManagedNfsTarget {
          host
          __typename
        }
        ... on CdmManagedS3CompatibleTarget {
          endpoint
          __typename
        }
        ... on CdmManagedGlacierTarget {
          awsRegion: region
          __typename
        }
        __typename
      }
      __typename
    }
    pageInfo {
      endCursor
      hasPreviousPage
      hasNextPage
      __typename
    }
    __typename
  }
}
"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCList += $RSCResponse.data.targets.edges.node
# Getting all results from paginations
While ($RSCResponse.data.targets.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.targets.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.targets.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCArchiveTargets = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($ListObject in $RSCList)
{
# Setting variables
$ID = $ListObject.id
$Name = $ListObject.name
$Type = $ListObject.targetType
$Status = $ListObject.status
$Tier = $ListObject.tier
$Clusters = $ListObject.cluster
$ClustersCount = $Clusters | Measure-Object | Select-Object -ExpandProperty Count
$ImmutableDays = $ListObject.immutabilityPeriodDays
$UsedBytes = $ListObject.consumedBytes
$SyncStatus = $ListObject.syncStatus
$LocationStatus = $ListObject.locationConnectionStatus
$Region = $ListObject.rcsRegion
# Converting bytes
IF($UsedBytes -ne $null){$UsedGB = $UsedBytes / 1000 / 1000 / 1000;$UsedGB = [Math]::Round($UsedGB,2)}ELSE{$UsedGB = $null}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $Type
$Object | Add-Member -MemberType NoteProperty -Name "Archive" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "Clusters" -Value $ClustersCount
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $Region
$Object | Add-Member -MemberType NoteProperty -Name "Tier" -Value $Tier
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $Status
$Object | Add-Member -MemberType NoteProperty -Name "SyncStatus" -Value $SyncStatus
$Object | Add-Member -MemberType NoteProperty -Name "LocationStatus" -Value $LocationStatus
$Object | Add-Member -MemberType NoteProperty -Name "UsedGB" -Value $UsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ImmutableDays" -Value $ImmutableDays
# Adding
$RSCArchiveTargets.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCArchiveTargets
# End of function
}