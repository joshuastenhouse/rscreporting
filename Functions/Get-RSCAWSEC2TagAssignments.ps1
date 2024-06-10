################################################
# Function - Get-RSCAWSEC2TagAssignments - Getting All RSCAWSEC2TagAssignments connected to RSC
################################################
Function Get-RSCAWSEC2TagAssignments {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all EC2 tags assigned in all AWS accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAWSEC2TagAssignments
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
# Getting All AWS EC2 instances
################################################
# Creating array for objects
$CloudVMList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "EC2InstancesListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query EC2InstancesListQuery(`$first: Int, `$after: String, `$sortBy: AwsNativeEc2InstanceSortFields, `$sortOrder: SortOrder, `$filters: AwsNativeEc2InstanceFilters, `$descendantTypeFilters: [HierarchyObjectTypeEnum!], `$isMultitenancyEnabled: Boolean = false) {
  awsNativeEc2Instances(first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder, ec2InstanceFilters: `$filters, descendantTypeFilter: `$descendantTypeFilters) {
    edges {
      cursor
      node {
        id
        instanceNativeId
        instanceName
        vpcName
        region
        vpcId
            tags {
      key
      value
      __typename
    }
        isRelic
        instanceType
        isExocomputeConfigured
        isIndexingEnabled
        isMarketplace
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
        ...AwsSlaAssignmentColumnFragment
        hostInfo {
          ...AppTypeFragment
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
}

fragment AppTypeFragment on PhysicalHost {
  id
  cluster {
    id
    name
    status
    __typename
  }
  connectionStatus {
    connectivity
    __typename
  }
  descendantConnection {
    edges {
      node {
        objectType
        effectiveSlaDomain {
          ...EffectiveSlaDomainFragment
          __typename
        }
        __typename
      }
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
$CloudVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$CloudVMList += $CloudVMListResponse.data.awsNativeEc2Instances.edges.node
# Getting all results from paginations
While ($CloudVMListResponse.data.awsNativeEc2Instances.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $CloudVMListResponse.data.awsNativeEc2Instances.pageInfo.endCursor
$CloudVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$CloudVMList += $CloudVMListResponse.data.awsNativeEc2Instances.edges.node
}
################################################
# Processing AWS EC2 Instances
################################################
# For Each Object Getting Data
ForEach ($CloudVM in $CloudVMList)
{
# Setting variables
$VMName = $CloudVM.instanceName
$VMID = $CloudVM.id
$VMNativeID = $CloudVM.instanceNativeId
$VMType = $CloudVM.instanceType
$VMNetwork = $CloudVM.vpcName
$VMRegion = $CloudVM.region
$VMZone = $null
$VMIsRelic = $CloudVM.isRelic
$VMSLAInfo = $CloudVM.effectiveSlaDomain
$VMSLADomain = $VMSLAInfo.name
$VMSLADomainID = $VMSLAInfo.id
$VMSLAAssignment = $CloudVM.slaAssignment
$VMAccountInfo = $CloudVM.awsNativeAccount
$VMAccountID = $VMAccountInfo.id
$VMAccountName = $VMAccountInfo.name
$VMAccountNativeID = $VMAccountInfo.id
$VMAccountStatus = $VMAccountInfo.status
$VMTags = $CloudVM.tags | Select-Object Key,value
# Adding To Array for Each tag
ForEach($VMTag in $VMTags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWSEC2"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $VMTag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $VMTag.key
$Object | Add-Member -MemberType NoteProperty -Name "VM" -Value $VMName
$Object | Add-Member -MemberType NoteProperty -Name "VMID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "VMNativeID" -Value $VMNativeID
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $VMAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $VMAccountID
$Object | Add-Member -MemberType NoteProperty -Name "AccountNativeID" -Value $VMAccountNativeID
# Adding
$RSCTagAssignments.Add($Object) | Out-Null
# End of for each tag assignment below
}
# End of for each tag assignment above
#
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCTagAssignments
# End of function
}