################################################
# Function - Get-RSCCloudVMs - Getting All Cloud VMs connected to RSC
################################################
Function Get-RSCCloudVMs {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for all cloud VMs in RSC (GCP, Azure and AWS).

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCCloudVMs
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
$RSCCloudVMs = [System.Collections.ArrayList]@()
################################################
# Getting All Google Instances 
################################################
# Creating array for objects
$CloudVMList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "GCPInstancesListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query GCPInstancesListQuery(`$first: Int, `$after: String, `$sortBy: GcpNativeGceInstanceSortFields, `$sortOrder: SortOrder, `$filters: GcpNativeGceInstanceFilters, `$isMultitenancyEnabled: Boolean = false) {
  gcpNativeGceInstances(first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder, gceInstanceFilters: `$filters) {
    edges {
      cursor
      node {
        id
        nativeId
        nativeName
        vpcName
        networkHostProjectNativeId
        region
        zone
        isRelic
        machineType
        ...EffectiveSlaColumnFragment
        ...OrganizationsColumnFragment @include(if: `$isMultitenancyEnabled)
        gcpNativeProject {
          id
          name
          nativeId
          status
          __typename
        }
        authorizedOperations
        ...GcpSlaAssignmentColumnFragment
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
fragment GcpSlaAssignmentColumnFragment on HierarchyObject {
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
$CloudVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$CloudVMList += $CloudVMListResponse.data.gcpNativeGceInstances.edges.node
# Getting all results from paginations
While ($GCPProjectListResponse.data.gcpNativeGceInstances.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $CloudVMListResponse.data.gcpNativeGceInstances.pageInfo.endCursor
$CloudVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$CloudVMList += $CloudVMListResponse.data.gcpNativeGceInstances.edges.node
}
################################################
# Processing Google Instances
################################################
# For Each Object Getting Data
ForEach ($CloudVM in $CloudVMList)
{
# Setting variables
$VMName = $CloudVM.nativeName
$VMID = $CloudVM.id
$VMNativeID = $CloudVM.nativeId
$VMType = $CloudVM.machineType
$VMNetwork = $CloudVM.vpcName
$VMRegion = $CloudVM.region
$VMZone = $CloudVM.zone
$VMIsRelic = $CloudVM.isRelic
$VMSLAInfo = $CloudVM.effectiveSlaDomain
$VMSLADomain = $VMSLAInfo.name
$VMSLADomainID = $VMSLAInfo.id
$VMSLAAssignment = $CloudVM.slaAssignment
$VMAccountInfo = $CloudVM.gcpNativeProject
$VMAccountID = $VMAccountInfo.id
$VMAccountName = $VMAccountInfo.name
$VMAccountNativeID = $VMAccountInfo.nativeId
$VMAccountStatus = $VMAccountInfo.status
# Getting URL
$VMURL = Get-RSCObjectURL -ObjectType "gcpNativeGceInstance" -ObjectID $VMID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "GCPInstance"
$Object | Add-Member -MemberType NoteProperty -Name "VM" -Value $VMName
$Object | Add-Member -MemberType NoteProperty -Name "VMID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "VMNativeID" -Value $VMNativeID
$Object | Add-Member -MemberType NoteProperty -Name "VMType" -Value $VMType
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $VMRegion
$Object | Add-Member -MemberType NoteProperty -Name "Zone" -Value $VMZone
$Object | Add-Member -MemberType NoteProperty -Name "Network" -Value $VMNetwork
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $VMSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $VMSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $VMSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $VMIsRelic
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $VMAccountID
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $VMAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountType" -Value "GCPProject"
$Object | Add-Member -MemberType NoteProperty -Name "AccountNativeID" -Value $VMAccountNativeID
$Object | Add-Member -MemberType NoteProperty -Name "AccountStatus" -Value $VMAccountStatus
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $VMURL
# Adding
$RSCCloudVMs.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
################################################
# Getting All Azure VMs
################################################
# Creating array for objects
$CloudVMList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AzureVMListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query AzureVMListQuery(`$first: Int, `$after: String, `$sortBy: AzureNativeVirtualMachineSortFields, `$sortOrder: SortOrder, `$filters: AzureNativeVirtualMachineFilters, `$descendantTypeFilters: [HierarchyObjectTypeEnum!], `$isMultitenancyEnabled: Boolean = false) {
  azureNativeVirtualMachines(first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder, virtualMachineFilters: `$filters, descendantTypeFilter: `$descendantTypeFilters) {
    edges {
      cursor
      node {
        id
        name
        resourceGroup {
          id
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
        region
        vnetName
        subnetName
        sizeType
        isRelic
        ...EffectiveSlaColumnFragment
        ...OrganizationsColumnFragment @include(if: `$isMultitenancyEnabled)
        slaAssignment
        authorizedOperations
        effectiveSlaSourceObject {
          fid
          name
          objectType
          __typename
        }
        isAppConsistencyEnabled
        vmAppConsistentSpecs {
          preSnapshotScriptPath
          preScriptTimeoutInSeconds
          postSnapshotScriptPath
          postScriptTimeoutInSeconds
          cancelBackupIfPreScriptFails
          rbaStatus
          __typename
        }
        isExocomputeConfigured
        isFileIndexingEnabled
        isAdeEnabled
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
$CloudVMList += $CloudVMListResponse.data.azureNativeVirtualMachines.edges.node
# Getting all results from paginations
While ($GCPProjectListResponse.data.azureNativeVirtualMachines.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $CloudVMListResponse.data.azureNativeVirtualMachines.pageInfo.endCursor
$CloudVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$CloudVMList += $CloudVMListResponse.data.azureNativeVirtualMachines.edges.node
}
################################################
# Processing Azure VMs
################################################
# For Each Object Getting Data
ForEach ($CloudVM in $CloudVMList)
{
# Setting variables
$VMName = $CloudVM.name
$VMID = $CloudVM.id
$VMNativeID = $CloudVM.id
$VMType = $CloudVM.sizeType
$VMNetwork = $CloudVM.vnetName
$VMRegion = $CloudVM.region
$VMZone = $null
$VMIsRelic = $CloudVM.isRelic
$VMSLAInfo = $CloudVM.effectiveSlaDomain
$VMSLADomain = $VMSLAInfo.name
$VMSLADomainID = $VMSLAInfo.id
$VMSLAAssignment = $CloudVM.slaAssignment
$VMAccountInfo = $CloudVM.resourceGroup
$VMAccountID = $VMAccountInfo.id
$VMAccountName = $VMAccountInfo.name
$VMAccountNativeID = $VMAccountInfo.id
$VMAccountStatus = $VMAccountInfo.subscription.status
# Getting URL
$VMURL = Get-RSCObjectURL -ObjectType "AzureNativeVm" -ObjectID $VMID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AzureVM"
$Object | Add-Member -MemberType NoteProperty -Name "VM" -Value $VMName
$Object | Add-Member -MemberType NoteProperty -Name "VMID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "VMNativeID" -Value $VMNativeID
$Object | Add-Member -MemberType NoteProperty -Name "VMType" -Value $VMType
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $VMRegion
$Object | Add-Member -MemberType NoteProperty -Name "Zone" -Value $VMZone
$Object | Add-Member -MemberType NoteProperty -Name "Network" -Value $VMNetwork
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $VMSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $VMSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $VMSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $VMIsRelic
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $VMAccountID
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $VMAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountType" -Value "AzureSubscription"
$Object | Add-Member -MemberType NoteProperty -Name "AccountNativeID" -Value $VMAccountNativeID
$Object | Add-Member -MemberType NoteProperty -Name "AccountStatus" -Value $VMAccountStatus
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $VMURL
# Adding
$RSCCloudVMs.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
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
While ($GCPProjectListResponse.data.awsNativeEc2Instances.pageInfo.hasNextPage) 
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
# Some EC2 instances have no instance name, if null, setting to VMnativeID
IF($VMName -eq $null){$VMName = $VMNativeID}
# Getting URL
$VMURL = Get-RSCObjectURL -ObjectType "awsNativeEc2Instance" -ObjectID $VMID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWSEC2"
$Object | Add-Member -MemberType NoteProperty -Name "VM" -Value $VMName
$Object | Add-Member -MemberType NoteProperty -Name "VMID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "VMNativeID" -Value $VMNativeID
$Object | Add-Member -MemberType NoteProperty -Name "VMType" -Value $VMType
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $VMRegion
$Object | Add-Member -MemberType NoteProperty -Name "Zone" -Value $VMZone
$Object | Add-Member -MemberType NoteProperty -Name "Network" -Value $VMNetwork
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $VMSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $VMSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $VMSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $VMIsRelic
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $VMAccountID
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $VMAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountType" -Value "AWSAccount"
$Object | Add-Member -MemberType NoteProperty -Name "AccountNativeID" -Value $VMAccountNativeID
$Object | Add-Member -MemberType NoteProperty -Name "AccountStatus" -Value $VMAccountStatus
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $VMURL
# Adding
$RSCCloudVMs.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCCloudVMs
# End of function
}