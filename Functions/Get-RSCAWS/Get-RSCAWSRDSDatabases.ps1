################################################
# Function - Get-RSCAWSRDSDatabases - Getting All RSCRDSDatabases connected to RSC
################################################
Function Get-RSCAWSRDSDatabases {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all RDS databases in all AWS accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAWSRDSDatabases
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
# Creating Array
################################################
$RSCCloudDBs = [System.Collections.ArrayList]@()
################################################
# Getting All AWS RDS instances
################################################
# Creating array for objects
$CloudDBList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "RDSInstancesListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query RDSInstancesListQuery(`$first: Int, `$after: String, `$sortBy: AwsNativeRdsInstanceSortFields, `$sortOrder: SortOrder, `$filters: AwsNativeRdsInstanceFilters, `$isMultitenancyEnabled: Boolean = false) {
  awsNativeRdsInstances(first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder, rdsInstanceFilters: `$filters) {
    edges {
      cursor
      node {
        id
        vpcName
        region
        vpcId
        isRelic
        dbEngine
        dbInstanceName
        dbiResourceId
        allocatedStorageInGibi
        dbInstanceClass
        tags {
         key
         value
         }
        readReplicaSourceName
        ...EffectiveSlaColumnFragment
        ...OrganizationsColumnFragment @include(if: `$isMultitenancyEnabled)
        awsNativeAccount {
          id
          name
          status
          __typename
        }
        slaAssignment
        authorizedOperations
        effectiveSlaSourceObject {
          fid
          name
          objectType
          __typename
        }
        ...AwsSlaAssignmentColumnFragment
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
}

fragment OrganizationsColumnFragment on HierarchyObject {
  allOrgs {
    name
    __typename
  }
  __typename
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
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$CloudDBListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$CloudDBList += $CloudDBListResponse.data.awsNativeRdsInstances.edges.node
# Getting all results from paginations
While ($CloudDBListResponse.data.awsNativeRdsInstances.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $CloudDBListResponse.data.awsNativeRdsInstances.pageInfo.endCursor
$CloudDBListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$CloudDBList += $CloudDBListResponse.data.awsNativeRdsInstances.edges.node
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
$DBEngine = $CloudDB.dbEngine
$DBInstance = $CloudDB.dbInstanceName
$DBResourceID = $CloudDB.DbiResourceId
$DBAllocatedStorageGB = $CloudDB.allocatedStorageInGibi
$DBClass = $CloudDB.dbInstanceClass
$DBRegion = $CloudDB.region
$DBVPCID = $CloudDB.vpcId
$DBIsRelic = $CloudDB.isRelic
$DBAccountInfo = $CloudDB.awsNativeAccount
$DBAccountID = $DBAccountInfo.id
$DBAccountName = $DBAccountInfo.name
$DBAccountStatus = $DBAccountInfo.status
$DBSLADomainInfo = $CloudDB.effectiveSlaDomain
$DBSLADomainID = $DBSLADomainInfo.id
$DBSLADomain = $DBSLADomainInfo.name
$DBSLAAssignment = $CloudDB.slaAssignment
$DBTags = $CloudDB.tags | Select-Object Key,value
# Getting last backup
# $DBLastBackupInfo = Get-RSCObjectLastBackup $DBID
$DBLastBackupUTC = $DBLastBackupInfo.DateUTC
$DBLastBackupStatus = $DBLastBackup.Status
$DBLastBackupStartUTC = $DBLastBackup.StartUTC
$DBLastBackupEndUTC = $DBLastBackup.EndUTC
$DBLastBackupDuration = $DBLastBackup.Duration
$DBLastBackupDurationSeconds = $DBLastBackup.DurationSeconds
$DBLastBackupMessage = $DBLastBackup.Message
# Getting URL
$DBURL = Get-RSCObjectURL -ObjectType "awsNativeRdsInstance" -ObjectID $DBID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWSRDS"
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBName
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "Instance" -Value $DBInstance
$Object | Add-Member -MemberType NoteProperty -Name "Class" -Value $DBClass
$Object | Add-Member -MemberType NoteProperty -Name "Engine" -Value $DBEngine
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $DBRegion
$Object | Add-Member -MemberType NoteProperty -Name "AllocatedStorageGB" -Value $DBAllocatedStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "VPCID" -Value $DBVPCID
$Object | Add-Member -MemberType NoteProperty -Name "ResourceID" -Value $DBResourceID
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
# Last backup
# $Object | Add-Member -MemberType NoteProperty -Name "LastBackupUTC" -Value $DBLastBackupUTC
# $Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $DBLastBackupStatus
# $Object | Add-Member -MemberType NoteProperty -Name "Message" -Value $DBLastBackupMessage
# $Object | Add-Member -MemberType NoteProperty -Name "StartUTC" -Value $DBLastBackupStartUTC
# $Object | Add-Member -MemberType NoteProperty -Name "EndUTC" -Value $DBLastBackupEndUTC
# $Object | Add-Member -MemberType NoteProperty -Name "Duration" -Value $DBLastBackupDuration
# $Object | Add-Member -MemberType NoteProperty -Name "DurationSeconds" -Value $DBLastBackupDurationSeconds
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