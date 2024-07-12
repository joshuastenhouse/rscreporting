################################################
# Function - Get-RSCAWSAccounts - Getting AWS Accounts connected to RSC
################################################
Function Get-RSCAWSAccounts {

<#
.SYNOPSIS
Returns all the AWS Accounts seen by RSC.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAWSAccounts
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
# Getting All RSCAWSAccounts 
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
# Processing
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
# Getting URLs
IF($AWSAccountVMCount -gt 0){$AWSAccountEC2URL = Get-RSCObjectURL -ObjectType "awsEC2account" -ObjectID $AWSAccountID}ELSE{$AWSAccountEC2URL = $null}
IF($AWSAccountRDSCount -gt 0){$AWSAccountRDSURL = Get-RSCObjectURL -ObjectType "awsRDSaccount" -ObjectID $AWSAccountID}ELSE{$AWSAccountRDSURL = $null}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $AWSAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $AWSAccountID
$Object | Add-Member -MemberType NoteProperty -Name "EC2Count" -Value $AWSAccountVMCount
$Object | Add-Member -MemberType NoteProperty -Name "EBSCount" -Value $AWSAccountDiskCount
$Object | Add-Member -MemberType NoteProperty -Name "RDSCount" -Value $AWSAccountRDSCount
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $AWSAccountSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $AWSAccountSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $AWSAccountStatus
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshed" -Value $AWSAccountLastRefreshedUTC
$Object | Add-Member -MemberType NoteProperty -Name "EC2URL" -Value $AWSAccountEC2URL
$Object | Add-Member -MemberType NoteProperty -Name "RDSURL" -Value $AWSAccountRDSURL
# Adding
$AWSAccounts.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
# Returning array
Return $AWSAccounts
# End of function
}