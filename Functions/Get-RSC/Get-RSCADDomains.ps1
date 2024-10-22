################################################
# Function - Get-RSCADDomains - Getting All Active Directory Domains Protected by RSC
################################################
Function Get-RSCADDomains {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all protected Active Directory Domains.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCADDomains
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 07/08/2024
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
$RSCGraphQL = @{"operationName" = "OnPremAdDomainListDeprecatedQuery";

"variables" = @{
"first" = 50
"sortBy" = "NAME"
"sortOrder" = "ASC"
"isMultitenancyEnabled" = $True
};

"query" = "query OnPremAdDomainListDeprecatedQuery(`$first: Int!, `$after: String, `$sortBy: HierarchySortByField, `$sortOrder: SortOrder, `$filter: [Filter!], `$isMultitenancyEnabled: Boolean!) {
  activeDirectoryDomains(filter: `$filter, first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder
  ) {
    count
    edges {
      cursor
      node {
        domainSid
        id
        name
        smbDomain {
          id
          status
          __typename
        }
        physicalChildConnection {
          count
          nodes {
            id
            name
            effectiveSlaDomain {
              id
              __typename
            }
            ... on ActiveDirectoryDomainController {
              isRelic
              snapshotConnection {
                count
                __typename
              }
              newestSnapshot {
                date
                __typename
              }
              rbsStatus {
                connectivity
                __typename
              }
              __typename
            }
            __typename
          }
          __typename
        }
        cluster {
          id
          name
          version
          __typename
        }
        ...CdmClusterColumnFragment
        ... on HierarchyObject {
          ...EffectiveSlaColumnFragment
          __typename
        }
        ...OrganizationsColumnFragment @include(if: `$isMultitenancyEnabled)
        slaPauseStatus
        __typename
      }
      __typename
    }
    pageInfo {
      startCursor
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

fragment CdmClusterColumnFragment on CdmHierarchyObject {
  replicatedObjectCount
  cluster {
    id
    name
    version
    status
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
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.activeDirectoryDomains.edges.node
# Getting all results from activeDirectoryDomains
While ($RSCResponse.data.activeDirectoryDomains.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.activeDirectoryDomains.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.activeDirectoryDomains.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCADDomains = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Domain in $RSCList)
{
# Setting variables
$DomainID = $Domain.id
$DomainName = $Domain.name
$SLADomain = $Domain.effectiveSlaDomain.name
$SLADomainID = $Domain.effectiveSlaDomain.id
$SLADomainRetentionLocked = $Domain.effectiveSlaDomain.isRetentionLockedSla
$SLADomainPauseStatus = $Domain.slaPauseStatus
$RubrikCluster = $Domain.cluster.name
$RubrikClusterID = $Domain.cluster.id
$RubrikClusterVersion = $Domain.cluster.version
$DomainControllers = $Domain.physicalChildConnection.count
# Getting object URL
$ObjectURL = Get-RSCObjectURL -ObjectType "ADDomain" -ObjectID $DomainID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ADDomain" -Value $DomainName
$Object | Add-Member -MemberType NoteProperty -Name "ADDomainID" -Value $DomainID
$Object | Add-Member -MemberType NoteProperty -Name "ADDomainControllers" -Value $DomainControllers
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "RetentionLocked" -Value $SLADomainRetentionLocked
$Object | Add-Member -MemberType NoteProperty -Name "PauseStatus" -Value $SLADomainPauseStatus
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterVersion" -Value $RubrikClusterVersion
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCADDomains.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCADDomains
# End of function
}