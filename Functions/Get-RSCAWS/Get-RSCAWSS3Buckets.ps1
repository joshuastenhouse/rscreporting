################################################
# Function - Get-RSCAWSS3Buckets - Getting All AWS S3 Buckets connected to RSC
################################################
Function Get-RSCAWSS3Buckets {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all S3 buckets visible to RSC

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAWSS3Buckets
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
$RSCGraphQL = @{"operationName" = "AwsInventoryTableQuery";

"variables" = @{
"first" = 1000
"objectTypeFilter" = "AWS_NATIVE_S3_BUCKET"
"includeSecurityMetadata" = $false
};


"query" = "query AwsInventoryTableQuery(`$objectTypeFilter: HierarchyObjectTypeEnum!, `$first: Int, `$after: String, `$sortBy: HierarchySortByField, `$sortOrder: SortOrder, `$includeSecurityMetadata: Boolean!) {
  awsNativeRoot {
    objectTypeDescendantConnection(objectTypeFilter: `$objectTypeFilter, first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder, includeSecurityMetadata: `$includeSecurityMetadata) {
      edges {
        cursor
        node {
          id
          name
          isRelic
          slaAssignment
          ...EffectiveSlaColumnFragment
          ...AwsSlaAssignmentColumnFragment
          ...SecurityMetadataColumnFragment @include(if: `$includeSecurityMetadata)
          ... on AwsNativeS3Bucket {
            creationTime
            isExocomputeConfigured
            awsNativeAccount {
              id
              name
              status
              __typename
            }
            region
            __typename
            name
            nativeName
            newestSnapshot {
              id
              date
            }
            isRelic
            isVersioningEnabled
            slaAssignment
            slaPauseStatus
            snapshotDistribution {
              totalCount
              scheduledCount
              retrievedCount
              onDemandCount
            }
            tags {
              key
              value
            }
            effectiveSlaDomain {
              id
              name
              ... on GlobalSlaReply {
                isRetentionLockedSla
              }
            }
            id
            earliestRestoreTime
            cloudNativeId
          }
          __typename
        }
        __typename
      }
      pageInfo {
        endCursor
        hasNextPage
        hasPreviousPage
        startCursor
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

fragment AwsSlaAssignmentColumnFragment on HierarchyObject {
  effectiveSlaSourceObject {
    fid
    name
    objectType
    __typename
  }
  slaAssignment
  __typename
}

fragment SecurityMetadataColumnFragment on HierarchyObject {
  securityMetadata {
    sensitivityStatus
    highSensitiveHits
    mediumSensitiveHits
    lowSensitiveHits
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
$RSCList += $RSCResponse.data.awsNativeRoot.objectTypeDescendantConnection.edges.node
# Getting all results from activeDirectoryDomains
While ($RSCResponse.data.awsNativeRoot.objectTypeDescendantConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.awsNativeRoot.objectTypeDescendantConnection.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.awsNativeRoot.objectTypeDescendantConnection.edges.node
}
################################################
# Processing Objects
################################################
# Creating array
$RSCAWSS3Buckets = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Storage in $RSCList)
{
# Setting variables
$Name = $Storage.id
$ID = $Storage.name
$Region = $Storage.region
$NativeID = $Storage.cloudNativeId
$AccessTier = $Storage.accessTier
$Snapshots = $Storage.snapshotDistribution.totalCount
$SLADomain = $Storage.effectiveSlaDomain.name
$SLADomainID = $Storage.effectiveSlaDomain.id
$PauseStatus = $Storage.slaPauseStatus
$SLAAssignment = $Storage.slaAssignment
$IsRelic = $Storage.isRelic
$Tags = $Storage.tags
$TagCount = $Tags | Measure-Object | Select-Object -ExpandProperty Count
$Account = $Storage.awsNativeAccount.name
$AccountID = $Storage.awsNativeAccount.id
$AccountStatus = $Storage.awsNativeAccount.status
# Snapshot info
$SnapshotDateUNIX = $Storage.newestSnapshot.date
$SnapshotDateID = $Storage.newestSnapshot.id
IF($SnapshotDateUNIX -ne $null){$SnapshotDateUTC = Convert-RSCUNIXTime $SnapshotDateUNIX}ELSE{$SnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($SnapshotDateUTC -ne $null){$SnapshotTimespan = New-TimeSpan -Start $SnapshotDateUTC -End $UTCDateTime;$SnapshotHoursSince = $SnapshotTimespan | Select-Object -ExpandProperty TotalHours;$SnapshotHoursSince = [Math]::Round($SnapshotHoursSince,1)}ELSE{$SnapshotHoursSince = $null}
# Getting URL
$URL = Get-RSCObjectURL -ObjectType "S3Bucket" -ObjectID $ID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "S3Bucket" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "S3BucketID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $Region
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
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $Account
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $AccountID
$Object | Add-Member -MemberType NoteProperty -Name "AccountStatus" -Value $AccountStatus
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $URL
# Adding
$RSCAWSS3Buckets.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCAWSS3Buckets
# End of function
}