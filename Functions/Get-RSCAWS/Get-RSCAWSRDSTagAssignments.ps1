################################################
# Function - Get-RSCAWSRDSTagAssignments - Getting All RDSTagAssignments connected to RSC
################################################
Function Get-RSCAWSRDSTagAssignments {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all RDS tags assigned in all AWS accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAWSRDSTagAssignments
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
$RSCTagAssignments = [System.Collections.ArrayList]@()
################################################
# Getting All AWS RDS Databases
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
# Adding To Array for Each tag
ForEach($DBTag in $DBTags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWSRDS"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $DBTag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $DBTag.key
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBInstance
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $DBAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $DBAccountID
# Adding
$RSCTagAssignments.Add($Object) | Out-Null
# End of for each tag assignment below
}
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCTagAssignments
# End of function
}