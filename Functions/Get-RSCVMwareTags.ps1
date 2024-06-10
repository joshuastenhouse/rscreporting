################################################
# Function - Get-RSCVMwareTags - Getting all RSCVMwareTags connected to the RSC instance
################################################
Function Get-RSCVMwareTags {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all VMware tags in all vCenters.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCVMwareTags
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
# Getting All Tag Categories 
################################################
# Creating array
$RSCTags = [System.Collections.ArrayList]@()
# Creating array for objects
$RSCTagCategoryList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "vSphereVCenterConnection";

"variables" = @{
"first" = 1000
};

"query" = "query vSphereVCenterConnection(`$first: Int, `$after: String) {
  vSphereVCenterConnection {
    nodes {
      tagChildConnection(first: `$first, after: `$after) {
        nodes {
          ... on VsphereTagCategory {
            id
            name
            numWorkloadDescendants
            objectType
            vcenterId
            vsphereTagPath {
              fid
              name
              objectType
            }
            slaAssignment
            effectiveSlaDomain {
              id
              name
            }
          }
        }
      }
    }
  }
}
"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCTagListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCTagCategoryList += $RSCTagListResponse.data.vSphereVCenterConnection.nodes.tagChildConnection.nodes
# Getting all results from paginations
While($RSCTagListResponse.data.vSphereVCenterConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCTagListResponse.data.vSphereVCenterConnection.pageInfo.endCursor
$RSCTagListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCTagCategoryList += $RSCTagListResponse.data.vSphereVCenterConnection.nodes.tagChildConnection.nodes
}
################################################
# Getting All Tags For Each Tag Category
################################################
ForEach($RSCTagCategory in $RSCTagCategoryList)
{
# Setting variables
$TagCategoryID = $RSCTagCategory.id
$TagCategoryName = $RSCTagCategory.name
$TagCategoryVMs = $RSCTagCategory.numWorkloadDescendants
$TagCategoryvCenterInfo = $RSCTagCategory.vsphereTagPath
$TagCategoryvCenter = $TagCategoryvCenterInfo.name
$TagCategoryvCenterID = $TagCategoryvCenterInfo.fid
$TagCategorySLADomainInfo = $RSCTagCategory.effectiveSlaDomain
$TagCategorySLADomain = $TagCategorySLADomainInfo.name
$TagCategorySLADomainID = $TagCategorySLADomainInfo.id
$TagCategorySLAAssignment = $RSCTagCategory.slaAssignment
# Creating array for objects
$RSCTagList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "VSphereTagCategoryChildrenQuery";

"variables" = @{
"first" = 1000
"id" = "$TagCategoryID"
};

"query" = "query VSphereTagCategoryChildrenQuery(`$first: Int!, `$after: String, `$id: UUID!, `$sortBy: HierarchySortByField, `$sortOrder: SortOrder) {
  vSphereTagCategory(fid: `$id) {
    id
    tagChildConnection(first: `$first, sortBy: `$sortBy, sortOrder: `$sortOrder, after: `$after) {
      edges {
        cursor
        node {
          id
          ... on VsphereTag {
            isFilter
            condition
            __typename
          }
          ...VSphereNameColumnFragment
          authorizedOperations
          ...CdmClusterColumnFragment
          ...EffectiveSlaColumnFragment
          ...VSphereSlaAssignmentColumnFragment
          ...SnappableCountColumnFragment
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

fragment VSphereNameColumnFragment on HierarchyObject {
  id
  name
  ...HierarchyObjectTypeFragment
  __typename
}

fragment HierarchyObjectTypeFragment on HierarchyObject {
  objectType
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

fragment VSphereSlaAssignmentColumnFragment on HierarchyObject {
  effectiveSlaSourceObject {
    fid
    name
    objectType
    __typename
  }
  ...SlaAssignmentColumnFragment
  __typename
}

fragment SlaAssignmentColumnFragment on HierarchyObject {
  slaAssignment
  __typename
}

fragment SnappableCountColumnFragment on HierarchyObject {
  numWorkloadDescendants
  objectType
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCTagListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCTagList += $RSCTagListResponse.data.vSphereTagCategory.tagChildConnection.edges.node
# Counting tags
$TagCategoryTagCount = $RSCTagList | Measure-Object | Select-Object -ExpandProperty Count
# Processing each tag
ForEach($RSCTag in $RSCTagList)
{
# Assigning variables
$RSCTagID = $RSCTag.id
$RSCTagName = $RSCTag.name
$RSCTagVMs = $RSCTag.numWorkloadDescendants
$RSCTagSLADomainInfo = $RSCTag.effectiveSlaDomain
$RSCTagSLADomain = $RSCTagSLADomainInfo.name
$RSCTagSLADomainID = $RSCTagSLADomainInfo.id
$RSCTagSLAAssignment = $RSCTag.slaAssignment
# Getting URL
$TagURL = Get-RSCObjectURL -ObjectType "vCenterTagCategories" -ObjectID $TagCategoryvCenterID
# Adding Each Tag To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $TagCategoryvCenter
$Object | Add-Member -MemberType NoteProperty -Name "vCenterID" -Value $TagCategoryvCenterID
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $RSCTagName
$Object | Add-Member -MemberType NoteProperty -Name "TagID" -Value $RSCTagID
$Object | Add-Member -MemberType NoteProperty -Name "VMs" -Value $RSCTagVMs
$Object | Add-Member -MemberType NoteProperty -Name "TagCategory" -Value $TagCategoryName
$Object | Add-Member -MemberType NoteProperty -Name "TagCategoryID" -Value $TagCategoryID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $RSCTagSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $RSCTagSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $RSCTagSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $TagURL
# Adding
$RSCTags.Add($Object) | Out-Null
}
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCTags
# End of function
}