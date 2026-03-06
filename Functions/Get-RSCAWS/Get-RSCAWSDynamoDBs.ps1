################################################
# Function - Get-RSCAWSDynamoDBs - Getting All AWS Dynamo DBs connected to RSC
################################################
Function Get-RSCAWSDynamoDBs {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all Dynamo databases in all AWS accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAWSDynamoDBs
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 03/06/2026
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Creating Array
################################################
$RSCCloudDBs = [System.Collections.ArrayList]@()
################################################
# Getting All AWS RDS instances
################################################
# Creating array for objects
$CloudDBList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AwsInventoryTableQuery";

"variables" = @{
    "objectTypeFilter" = "AWS_NATIVE_DYNAMODB_TABLE"
    "sortBy" = "NAME"
    "sortOrder" = "DESC"
    "includeSecurityMetadata" = $true
    "includeRscNativeObjectPendingSla" = $true
    "first" = 500};

"query" = "query AwsInventoryTableQuery(`$objectTypeFilter: HierarchyObjectTypeEnum!, `$first: Int, `$sortBy: HierarchySortByField, `$sortOrder: SortOrder, `$includeSecurityMetadata: Boolean!, `$includeRscNativeObjectPendingSla: Boolean!) {
  awsNativeRoot {
    objectTypeDescendantConnection(
      objectTypeFilter: `$objectTypeFilter
      first: `$first
      sortBy: `$sortBy
      sortOrder: `$sortOrder
      includeSecurityMetadata: `$includeSecurityMetadata
    ) {
      edges {
        cursor
        node {
          id
          name
          tags {
         key
         value
         }
          isRelic
          region
          ...EffectiveSlaColumnFragment
          ...AwsSlaAssignmentColumnFragment
          ...SecurityMetadataColumnFragment @include(if: `$includeSecurityMetadata)
          ... on AwsNativeS3Bucket {
            authorizedOperations
            creationTime
            isExocomputeConfigured
            isProtectable
            numberOfObjects
            bucketSizeBytes
            isOnboarding
            awsNativeAccountDetails {
              id
              name
              status
              enabledFeatures {
                featureName
                lastRefreshedAt
                status
                __typename
              }
              __typename
            }
            __typename
          }
          ... on AwsNativeDynamoDbTable {
            authorizedOperations
            awsNativeAccountDetails {
              id
              name
              status
              enabledFeatures {
                featureName
                lastRefreshedAt
                status
                __typename
              }
              __typename
            }
            isRelic
            isProtectable
            isAwsContinuousBackupEnabled
            isExocomputeConfigured
            nonBackupRegionNames
            tableSizeBytes
            __typename
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
  ... on CloudDirectHierarchyObject {
    pendingSla {
      ...SLADomainFragment
      __typename
    }
    __typename
  }
  ... on PolarisHierarchyObject {
    rscNativeObjectPendingSla @include(if: `$includeRscNativeObjectPendingSla) {
      ...CompactSLADomainFragment
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
    haPolicy {
      id
      __typename
    }
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

fragment CompactSLADomainFragment on CompactSlaDomain {
  id
  name
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
    isLaminarEnabled
    sensitivityStatus
    highSensitiveHits
    mediumSensitiveHits
    lowSensitiveHits
    dataTypeResults {
      id
      name
      totalHits
      totalViolatedHits
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
$CloudDBListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$CloudDBList += $CloudDBListResponse.data.awsNativeRoot.objectTypeDescendantConnection.edges.node
# Getting all results from paginations
While ($CloudDBListResponse.data.awsNativeRoot.objectTypeDescendantConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $CloudDBListResponse.data.awsNativeRoot.objectTypeDescendantConnection.pageInfo.endCursor
$CloudDBListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$CloudDBList += $CloudDBListResponse.data.awsNativeRoot.objectTypeDescendantConnection.edges.node
}
################################################
# Processing AWS RDS
################################################
# For Each Object Getting Data
ForEach ($CloudDB in $CloudDBList)
{
# Setting variables
$DBID = $CloudDB.id
$DBInfo = $CloudDB.effectiveSlaSourceObject
$DBName = $DBInfo.name
$DBEngine = "DynamoDB"
$DBInstance = $CloudDB.dbInstanceName
$DBResourceID = $CloudDB.DbiResourceId
$DBAllocatedStorageGB = $CloudDB.allocatedStorageInGibi
$DBClass = $CloudDB.dbInstanceClass
$DBRegion = $CloudDB.region
$DBVPCID = $CloudDB.vpcId
$DBIsRelic = $CloudDB.isRelic
$DBAccountInfo = $CloudDB.awsNativeAccountDetails
$DBAccountID = $DBAccountInfo.id
$DBAccountName = $DBAccountInfo.name
$DBAccountStatus = $DBAccountInfo.status
$DBSLADomainInfo = $CloudDB.effectiveSlaDomain
$DBSLADomainID = $DBSLADomainInfo.id
$DBSLADomain = $DBSLADomainInfo.name
$DBSLAAssignment = $CloudDB.slaAssignment
$DBTags = $CloudDB.tags | Select-Object Key,value
# Dynamo speciffic fiels
$DBTableSizeBytes = $CloudDB.tableSizeBytes
$DBIsProtectable = $CloudDB.isProtectable
$DBAWSContinousBackupEnabled = $CloudDB.isAwsContinuousBackupEnabled
$DBExocomputeConfigured = $CloudDB.isExocomputeConfigured
# Converting to GB
IF($DBTableSizeBytes -ne $null){$DBTableSizeGB = $DBTableSizeBytes / 1000 / 1000 / 1000;$DBTableSizeGB = [Math]::Round($DBTableSizeGB,2)}ELSE{$DBTableSizeGB = $null}
# Getting URL
$DBURL = Get-RSCObjectURL -ObjectType "AWSDynamoDB" -ObjectID $DBID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWS"
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBName
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "Engine" -Value $DBEngine
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $DBRegion
$Object | Add-Member -MemberType NoteProperty -Name "TableSizeGB" -Value $DBTableSizeGB
$Object | Add-Member -MemberType NoteProperty -Name "TableSizeBytes" -Value $DBTableSizeBytes
$Object | Add-Member -MemberType NoteProperty -Name "Protectable" -Value $DBIsProtectable
$Object | Add-Member -MemberType NoteProperty -Name "ContinousBackupEnabled" -Value $DBAWSContinousBackupEnabled
$Object | Add-Member -MemberType NoteProperty -Name "ExoComputeConfigured" -Value $DBExocomputeConfigured
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $DBSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $DBSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $DBSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "Tags" -Value $DBTags
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $DBIsRelic
$Object | Add-Member -MemberType NoteProperty -Name "AccountType" -Value "AWSAccount"
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $DBAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $DBAccountID
$Object | Add-Member -MemberType NoteProperty -Name "AccountStatus" -Value $DBAccountStatus
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $DBID
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $DBURL
# Adding
$RSCCloudDBs.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCCloudDBs
# End of function
}