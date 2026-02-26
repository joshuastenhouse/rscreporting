################################################
# Function - Get-RSCAzureSubscriptions - Getting Azure Subscriptions connected to RSC
################################################
function Get-RSCAzureSubscription {

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
Date: 07/09/2024
#>
    [CmdletBinding()]
    [Alias('Get-RSCAzureSubscriptions')]
    param()
    ################################################
    # Importing Module & Running Required Functions
    ################################################
    # Importing the module is it needs other modules
    Import-Module RSCReporting
    # Checking connectivity, exiting function with error if not connected
    Test-RSCConnection
    ################################################
    # Getting All RSCAzureSubscriptions 
    ################################################
    # Creating array for objects
    $AzureSubscriptionList = @()
    # Building GraphQL query
    $RSCGraphQL = @{"operationName" = "AzureNativeSubscriptions";

        "variables"                 = @{
            "first" = 1000
        };

        "query"                     = "query AzureNativeSubscriptions(`$first: Int, `$after: String) {
  azureNativeSubscriptions(first: `$first, after: `$after) {
    count
    edges {
      node {
        name
        id
        lastRefreshedAt
        disksCount
        tenantId
        azureSubscriptionStatus
        azureSubscriptionNativeId
        azureStorageAccountCount
        azureSqlManagedInstanceDbCount
        azureSqlDatabaseDbCount
        azureNativeResourceGroups {
          edges {
            node {
              id
              name
              region
              numWorkloadDescendants
              tags {
                key
                value
              }
            }
          }
        }
        vmsCount
        regionSpecs {
          region
          isExocomputeConfigured
        }
        azureCloudType
        effectiveSlaDomain {
          id
          name
        }
        numWorkloadDescendants
        slaAssignment
        slaPauseStatus
        objectType
        enabledFeatures {
          featureName
          lastRefreshedAt
          status
        }
      }
    }
  }
}"
    }
    ################################################
    # API Call To RSC GraphQL URI
    ################################################
    # Querying API
    $AzureSubscriptionResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
    # Setting variable
    $AzureSubscriptionList += $AzureSubscriptionResponse.data.azureNativeSubscriptions.edges.node
    # Getting all results from paginations
    while ($AzureSubscriptionResponse.data.azureNativeSubscriptions.pageInfo.hasNextPage) {
        # Getting next set
        $RSCGraphQL.variables.after = $AzureSubscriptionResponse.data.azureNativeSubscriptions.pageInfo.endCursor
        $AzureSubscriptionResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
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
    foreach ($AzureSub in $AzureSubscriptionList) {
        # Setting variables
        $AzureSubName = $AzureSub.name
        $AzureSubID = $AzureSub.id
        $AzureSubTenantID = $AzureSub.tenantId
        $AzureSubVMCount = $AzureSub.vmsCount
        $AzureSubStorageAccountCount = $AzureSub.azureStorageAccountCount
        $AzureSubDiskCount = $AzureSub.disksCount
        $AzureSubSLADomainInfo = $AzureSub.effectiveSlaDomain
        $AzureSubSLADomain = $AzureSubSLADomainInfo.name
        $AzureSubSLADomainID = $AzureSubSLADomainInfo.id
        $AzureSubEnabledFeatures = $AzureSub.enabledFeatures
        $AzureSubStatus = $AzureSub.azureSubscriptionStatus
        $AzureSubLastRefreshedUNIX = $AzureSub.lastRefreshedAt
        $AzureSubSQLDBCount = $AzureSub.azureSqlDatabaseDbCount
        $AzureSubSQLManagedInstanceDBCount = $AzureSub.azureSqlManagedInstanceDbCount
        # Checking if enabled for SQL & VM
        $AzureFeatureNames = $AzureSubEnabledFeatures.featureName
        if ($AzureFeatureNames -match "SQL") { $AzureSubIsSQLEnabled = $TRUE }else { $AzureSubIsSQLEnabled = $FALSE }
        if ($AzureFeatureNames -match "VM") { $AzureSubIsVMEnabled = $TRUE }else { $AzureSubIsVMEnabled = $FALSE }
        if ($AzureFeatureNames -match "BLOB") { $AzureSubIsStorageEnabled = $TRUE }else { $AzureSubIsStorageEnabled = $FALSE }
        # Converting to UTC
        try {
            if ($AzureSubLastRefreshedUNIX -ne $null) { $AzureSubLastRefreshedUTC = Convert-RSCUNIXTime $AzureSubLastRefreshedUNIX }else { $AzureSubLastRefreshedUTC = $null }
        }
        catch { $AzureSubLastRefreshedUTC = $null }
        # Tags & Resource Groups
        $AzureResourceGroups = $AzureSub.azureNativeResourceGroups.edges.node
        $AzureResourceGroupsCount = $AzureResourceGroups | Measure-Object | Select-Object -ExpandProperty Count
        $AzureSubTags = $AzureResourceGroups.tags
        $AzureSubTagsCount = $VMTags | Measure-Object | Select-Object -ExpandProperty Count
        # Getting URLs
        if ($AzureSubIsVMEnabled -eq $TRUE) { $AzureSubVMURL = Get-RSCObjectURL -ObjectType "AzureSubVirtualMachines" -ObjectID $AzureSubID }else { $AzureSubVMURL = $null }
        if ($AzureSubIsSQLEnabled -eq $TRUE) { $AzureSubSQLURL = Get-RSCObjectURL -ObjectType "AzureSubSqlDatabases" -ObjectID $AzureSubID }else { $AzureSubSQLURL = $null }
        $AzureSubStorageURL = Get-RSCObjectURL -ObjectType "AzureSubStorageAccounts" -ObjectID $AzureSubID
        # Adding To Array
        $Object = New-Object PSObject
        $Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
        $Object | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $AzureSubName
        $Object | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $AzureSubID
        $Object | Add-Member -MemberType NoteProperty -Name "VMProtectionEnabled" -Value $AzureSubIsVMEnabled
        $Object | Add-Member -MemberType NoteProperty -Name "SQLProtectionEnabled" -Value $AzureSubIsSQLEnabled
        $Object | Add-Member -MemberType NoteProperty -Name "StorageProtectionEnabled" -Value $AzureSubIsStorageEnabled
        $Object | Add-Member -MemberType NoteProperty -Name "VMs" -Value $AzureSubVMCount
        $Object | Add-Member -MemberType NoteProperty -Name "VMDisks" -Value $AzureSubDiskCount
        $Object | Add-Member -MemberType NoteProperty -Name "StorageAccounts" -Value $AzureSubStorageAccountCount
        $Object | Add-Member -MemberType NoteProperty -Name "SQLDBs" -Value $AzureSubSQLDBCount
        $Object | Add-Member -MemberType NoteProperty -Name "SQLManagedInstanceDBs" -Value $AzureSubSQLManagedInstanceDBCount
        $Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $AzureSubSLADomain
        $Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $AzureSubSLADomainID
        $Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $AzureSubTenantID
        $Object | Add-Member -MemberType NoteProperty -Name "Tags" -Value $AzureSubTags
        $Object | Add-Member -MemberType NoteProperty -Name "LastRefreshed" -Value $AzureSubLastRefreshedUTC
        $Object | Add-Member -MemberType NoteProperty -Name "TenantID" -Value $AzureSubTenantID
        $Object | Add-Member -MemberType NoteProperty -Name "VMURL" -Value $AzureSubVMURL
        $Object | Add-Member -MemberType NoteProperty -Name "SQLURL" -Value $AzureSubSQLURL
        $Object | Add-Member -MemberType NoteProperty -Name "StorageURL" -Value $AzureSubStorageURL
        # Adding
        $AzureSubscriptions.Add($Object) | Out-Null
        # End of for each object below
    }
    # End of for each object above
    # Returning array
    return $AzureSubscriptions
    # End of function
}

