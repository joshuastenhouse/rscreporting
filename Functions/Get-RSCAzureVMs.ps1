################################################
# Function - Get-RSCAzureVMs - Getting All RSCAzureVMs connected to RSC
################################################
Function Get-RSCAzureVMs {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all VMs in all Azure subscriptions/accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAzureVMs
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
#
# Returning array
Return $RSCCloudVMs
# End of function
}