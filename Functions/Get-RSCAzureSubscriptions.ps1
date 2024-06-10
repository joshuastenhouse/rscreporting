################################################
# Function - Get-RSCAzureSubscriptions - Getting Azure Subscriptions connected to RSC
################################################
Function Get-RSCAzureSubscriptions {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function a list of all Azure subscriptions/accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAzureSubscriptions
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
# Getting Azure Mssql DBs, can't find it on the Azure sub API
$RSCAzureSQLDBs = Get-RSCAzureSQLDatabases
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
# Processing
################################################
# Creating array
$AzureSubscriptions = [System.Collections.ArrayList]@()
# Time for refresh since
$UTCDateTime = [System.DateTime]::UtcNow
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
# Getting Azure SQL DBs
$AzureSubSQLDBCount = $RSCAzureSQLDBs | Where-Object {$_.SubscriptionID -eq $AzureSubID} | Measure-Object | Select-Object -ExpandProperty Count 
# Checking if enabled for SQL & VM
$AzureFeatureNames = $AzureSubEnabledFeatures.featureName
IF($AzureFeatureNames -match "SQL"){$AzureSubIsSQLEnabled = $TRUE}ELSE{$AzureSubIsSQLEnabled = $FALSE}
IF($AzureFeatureNames -match "VM"){$AzureSubIsVMEnabled = $TRUE}ELSE{$AzureSubIsVMEnabled = $FALSE}
# Converting to UTC
Try
{IF($AzureSubLastRefreshedUNIX -ne $null){$AzureSubLastRefreshedUTC = Convert-RSCUNIXTime $AzureSubLastRefreshedUNIX}ELSE{$AzureSubLastRefreshedUTC = $null}
}Catch{$AzureSubLastRefreshedUTC = $null}
# Getting URLs
IF($AzureSubIsVMEnabled -eq $TRUE){$AzureSubVMURL = Get-RSCObjectURL -ObjectType "AzureSubVirtualMachines" -ObjectID $AzureSubID}ELSE{$AzureSubVMURL = $null}
IF($AzureSubIsSQLEnabled -eq $TRUE){$AzureSubSQLURL = Get-RSCObjectURL -ObjectType "AzureSubSqlDatabases" -ObjectID $AzureSubID}ELSE{$AzureSubSQLURL = $null}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $AzureSubName
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $AzureSubID
$Object | Add-Member -MemberType NoteProperty -Name "VMProtectionEnabled" -Value $AzureSubIsVMEnabled
$Object | Add-Member -MemberType NoteProperty -Name "SQLProtectionEnabled" -Value $AzureSubIsSQLEnabled
$Object | Add-Member -MemberType NoteProperty -Name "SQLDBCount" -Value $AzureSubSQLDBCount
$Object | Add-Member -MemberType NoteProperty -Name "VMCount" -Value $AzureSubVMCount
$Object | Add-Member -MemberType NoteProperty -Name "DiskCount" -Value $AzureSubDiskCount
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $AzureSubSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $AzureSubSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $AzureSubTenantID
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshed" -Value $AzureSubLastRefreshedUTC
$Object | Add-Member -MemberType NoteProperty -Name "Tenant" -Value $AzureSubTenantName
$Object | Add-Member -MemberType NoteProperty -Name "TenantID" -Value $AzureSubTenantID
$Object | Add-Member -MemberType NoteProperty -Name "VMURL" -Value $AzureSubVMURL
$Object | Add-Member -MemberType NoteProperty -Name "SQLURL" -Value $AzureSubSQLURL
# Adding
$AzureSubscriptions.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
# Returning array
Return $AzureSubscriptions
# End of function
}