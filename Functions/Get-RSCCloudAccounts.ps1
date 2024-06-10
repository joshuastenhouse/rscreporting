################################################
# Function - Get-RSCCloudAccounts - Getting All Cloud Accounts connected to RSC
################################################
Function Get-RSCCloudAccounts {
	
<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for a list of all Cloud accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCCloudAccounts
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
# Creating array
$RSCCloudAccounts = [System.Collections.ArrayList]@()
# Time for refresh since
$UTCDateTime = [System.DateTime]::UtcNow
################################################
# Getting All RSCGCPProjects 
################################################
# Creating array for objects
$GCPProjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "GCPProjectsListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query GCPProjectsListQuery(`$first: Int!, `$after: String) {
  gcpNativeProjects(first: `$first, after: `$after) {
    edges {
      cursor
      node {
        id
        status
        name
        ...GcpProjectNumberColumnFragment
        ...GcpProjectIdColumnFragment
        slaAssignment
        lastRefreshedAt
        organizationName
        ...EffectiveSlaColumnFragment
        ...GcpVmcountColumnFragment
        diskCount
        authorizedOperations
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
fragment GcpProjectNumberColumnFragment on GcpNativeProject {
  projectNumber
  __typename
}
fragment GcpProjectIdColumnFragment on GcpNativeProject {
  nativeId
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
fragment GcpVmcountColumnFragment on GcpNativeProject {
  vmCount
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$GCPProjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$GCPProjectList += $GCPProjectListResponse.data.gcpNativeProjects.edges.node
# Getting all results from paginations
While ($GCPProjectListResponse.data.gcpNativeProjects.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $GCPProjectListResponse.data.gcpNativeProjects.pageInfo.endCursor
$GCPProjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$GCPProjectList += $GCPProjectListResponse.data.gcpNativeProjects.edges.node
}
################################################
# Processing RSCGCPProjects
################################################
# For Each Object Getting Data
ForEach ($GCPProject in $GCPProjectList)
{
# Setting variables
$GCPProjectName = $GCPProject.name
$GCPProjectID = $GCPProject.id
$GCPProjectNumber = $GCPProject.projectNumber
$GCPProjectNativeID = $GCPProject.nativeId
$GCPProjectVMCount = $GCPProject.vmCount
$GCPProjectDiskCount = $GCPProject.diskCount
$GCPProjectSLADomainInfo = $GCPProject.effectiveSlaDomain
$GCPProjectSLADomain = $GCPProjectSLADomainInfo.name
$GCPProjectSLADomainID = $GCPProjectSLADomainInfo.id
$GCPProjectStatus = $GCPProject.status
$GCPProjectLastRefreshedUNIX = $GCPProject.lastRefreshedAt
# Converting to UTC
Try
{
IF($GCPProjectLastRefreshedUNIX -ne $null){$GCPProjectLastRefreshedUTC = Convert-RSCUNIXTime $GCPProjectLastRefreshedUNIX}ELSE{$GCPProjectLastRefreshedUTC = $null}
}Catch{$GCPProjectLastRefreshedUTC = $null}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $GCPProjectName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $GCPProjectID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "GCPProject"
$Object | Add-Member -MemberType NoteProperty -Name "VMCount" -Value $GCPProjectVMCount
$Object | Add-Member -MemberType NoteProperty -Name "DiskCount" -Value $GCPProjectDiskCount
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $GCPProjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $GCPProjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $GCPProjectStatus
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshed" -Value $GCPProjectLastRefreshedUTC
# Adding
$RSCCloudAccounts.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
################################################
# Getting All RSCAzureSubscriptions 
################################################
# Creating array for objects
$AzureSubscriptionList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AzureSubscriptionListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query AzureSubscriptionListQuery(`$first: Int, `$after: String, `$sortBy: AzureNativeSubscriptionSortFields, `$sortOrder: SortOrder, `$filters: AzureNativeSubscriptionFilters, `$azureNativeProtectionFeature: AzureNativeProtectionFeature) {
  azureNativeSubscriptions(first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder, subscriptionFilters: `$filters, azureNativeProtectionFeature: `$azureNativeProtectionFeature) {
    edges {
      cursor
      node {
        ...AzureSubscriptionNameColumnFragment
        ...AzureSubscriptionTenantIdColumnFragment
        ...AzureSubscriptionNativeIdDetailsColumnFragment
        ...AzureSubscriptionStatusColumnFragment
        ...AzureSubscriptionVmsCountColumnFragment
        ...AzureSubscriptionLastRefreshedAtColumnFragment
        ...AzureSubscriptionDisksCountColumnFragment
        ...EffectiveSlaColumnFragment
        authorizedOperations
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
fragment AzureSubscriptionNameColumnFragment on AzureNativeSubscription {
  name
  enabledFeatures {
    status
    featureName
    __typename
  }
  __typename
}
fragment AzureSubscriptionVmsCountColumnFragment on AzureNativeSubscription {
  vmsCount
  __typename
}
fragment AzureSubscriptionNativeIdDetailsColumnFragment on AzureNativeSubscription {
  id
  nativeId: azureSubscriptionNativeId
  enabledFeatures {
    status
    lastRefreshedAt
    featureName
    __typename
  }
  __typename
}
fragment AzureSubscriptionLastRefreshedAtColumnFragment on AzureNativeSubscription {
  name
  id
  enabledFeatures {
    lastRefreshedAt
    status
    featureName
    __typename
  }
  __typename
}
fragment AzureSubscriptionTenantIdColumnFragment on AzureNativeSubscription {
  tenantId
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
fragment AzureSubscriptionDisksCountColumnFragment on AzureNativeSubscription {
  disksCount
  __typename
}
fragment AzureSubscriptionStatusColumnFragment on AzureNativeSubscription {
  enabledFeatures {
    status
    featureName
    __typename
  }
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$AzureSubscriptionResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$AzureSubscriptionList += $AzureSubscriptionResponse.data.azureNativeSubscriptions.edges.node
# Getting all results from paginations
While ($AzureSubscriptionResponse.data.azureNativeSubscriptions.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $AzureSubscriptionResponse.data.azureNativeSubscriptions.pageInfo.endCursor
$AzureSubscriptionResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$AzureSubscriptionList += $AzureSubscriptionResponse.data.azureNativeSubscriptions.edges.node
}
################################################
# Processing RSCAzureSubscriptions
################################################
# For Each Object Getting Data
ForEach ($AzureSub in $AzureSubscriptionList)
{
# Setting variables
$AzureSubName = $AzureSub.name
$AzureSubID = $AzureSub.id
$AzureSubTenantName = $AzureSub.tenantId
$AzureSubTenantID = $AzureSub.nativeID
$AzureSubVMCount = $AzureSub.vmsCount
$AzureSubDiskCount = $AzureSub.disksCount
$AzureSubSLADomainInfo = $AzureSub.effectiveSlaDomain
$AzureSubSLADomain = $AzureSubSLADomainInfo.name
$AzureSubSLADomainID = $AzureSubSLADomainInfo.id
$AzureSubEnabledFeatures = $AzureSub.enabledFeatures
$AzureSubStatus = $AzureSubEnabledFeatures.status
$AzureSubLastRefreshedUNIX = $AzureSubEnabledFeatures.lastRefreshedAt
# Converting to UTC
Try
{
IF($AzureSubLastRefreshedUNIX -ne $null){$AzureSubLastRefreshedUTC = Convert-RSCUNIXTime $AzureSubLastRefreshedUNIX}ELSE{$AzureSubLastRefreshedUTC = $null}
}Catch{$AzureSubLastRefreshedUTC = $null}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $AzureSubName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $AzureSubID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "AzureSubscription"
$Object | Add-Member -MemberType NoteProperty -Name "VMCount" -Value $AzureSubVMCount
$Object | Add-Member -MemberType NoteProperty -Name "DiskCount" -Value $AzureSubDiskCount
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $AzureSubSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $AzureSubSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $AzureSubTenantID
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshed" -Value $AzureSubLastRefreshedUTC
# Adding
$RSCCloudAccounts.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
################################################
# Getting All EC2 RSCAWSAccounts 
################################################
# Creating array for objects
$AWSAccountList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AWSAccountsListQuery";

"variables" = @{
"first" = 1000
"awsNativeProtectionFeature" = "EC2"
};

"query" = "query AWSAccountsListQuery(`$first: Int!, `$after: String, `$filters: AwsNativeAccountFilters, `$awsNativeProtectionFeature: AwsNativeProtectionFeature!) {
  awsNativeAccounts(first: `$first, after: `$after, accountFilters: `$filters, awsNativeProtectionFeature: `$awsNativeProtectionFeature) {
    edges {
      cursor
      node {
        id
        status
        name
        slaAssignment
        lastRefreshedAt
        ...Ec2InstanceCountColumnFragment
        ...EbsVolumeCountColumnFragment
        ...RdsInstanceCountColumnFragment
        ...EffectiveSlaColumnFragment
        authorizedOperations
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
fragment Ec2InstanceCountColumnFragment on AwsNativeAccount {
  ec2InstanceCount
  __typename
}
fragment EbsVolumeCountColumnFragment on AwsNativeAccount {
  ebsVolumeCount
  __typename
}
fragment RdsInstanceCountColumnFragment on AwsNativeAccount {
  rdsInstanceCount
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
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$AWSAccountListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$AWSAccountList += $AWSAccountListResponse.data.awsNativeAccounts.edges.node
# Getting all results from paginations
While ($AWSAccountListResponse.data.awsNativeAccounts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $AWSAccountListResponse.data.awsNativeAccounts.pageInfo.endCursor
$AWSAccountListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$AWSAccountList += $AzureSubscriptionResponse.data.awsNativeAccounts.edges.node
}
################################################
# Processing RSCAWSAccounts
################################################
# Creating array
$AWSAccounts = [System.Collections.ArrayList]@()
# Time for refresh since
$UTCDateTime = [System.DateTime]::UtcNow
# For Each Object Getting Data
ForEach ($AWSAccount in $AWSAccountList)
{
# Setting variables
$AWSAccountName = $AWSAccount.name
$AWSAccountID = $AWSAccount.id
$AWSAccountVMCount = $AWSAccount.ec2InstanceCount
$AWSAccountDiskCount = $AWSAccount.ebsVolumeCount
$AWSAccountRDSCount = $AWSAccount.rdsInstanceCount
$AWSAccountSLADomainInfo = $AWSAccount.effectiveSlaDomain
$AWSAccountSLADomain = $AWSAccountSLADomainInfo.name
$AWSAccountSLADomainID = $AWSAccountSLADomainInfo.id
$AWSAccountStatus = $AWSAccount.status
$AWSAccountLastRefreshedUNIX = $AWSAccount.lastRefreshedAt
# Converting to UTC
Try
{
IF($AWSAccountLastRefreshedUNIX -ne $null){$AWSAccountLastRefreshedUTC = Convert-RSCUNIXTime $AWSAccountLastRefreshedUNIX}ELSE{$AWSAccountLastRefreshedUTC = $null}
}Catch{$AWSAccountLastRefreshedUTC = $null}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $AWSAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $AWSAccountID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "AWSAccount"
$Object | Add-Member -MemberType NoteProperty -Name "VMCount" -Value $AWSAccountVMCount
$Object | Add-Member -MemberType NoteProperty -Name "DiskCount" -Value $AWSAccountDiskCount
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $AWSAccountSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $AWSAccountSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $AWSAccountStatus
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshed" -Value $AWSAccountLastRefreshedUTC
# Adding
$RSCCloudAccounts.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above



# Returning array
Return $RSCCloudAccounts
# End of function
}