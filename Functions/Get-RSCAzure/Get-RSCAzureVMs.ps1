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
Date: 07/09/2024
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
$RSCGraphQL = @{"operationName" = "AzureNativeVirtualMachines";

"variables" = @{
"first" = 1000
};

"query" = "query AzureNativeVirtualMachines(`$first: Int, `$after: String) {
  azureNativeVirtualMachines(first: `$first, after: `$after) {
    count
    edges {
      node {
        snapshotDistribution {
          totalCount
          scheduledCount
          onDemandCount
          retrievedCount
        }
        attachedManagedDisks {
          diskIopsReadWrite
          diskMbpsReadWrite
          diskNativeId
          diskSizeGib
          diskStorageTier
          id
          isExocomputeConfigured
          isAdeEnabled
          isFileIndexingEnabled
          isRelic
          logicalPath {
            fid
            name
            objectType
          }
          name
          nativeName
          tags {
            key
            value
          }
        }
        attachmentSpecs {
          isExcludedFromSnapshot
          isOsDisk
          lun
          managedDiskId
        }
        availabilitySetNativeId
        availabilityZone
        cloudNativeId
        effectiveSlaDomain {
          id
          name
          ... on GlobalSlaReply {
            isRetentionLockedSla
          }
        }
        id
        isAdeEnabled
        isAcceleratedNetworkingEnabled
        isAppConsistencyEnabled
        isExocomputeConfigured
        isFileIndexingEnabled
        isPreOrPostScriptEnabled
        isRelic
        name
        nativeName
        newestSnapshot {
          id
          date
        }
        objectType
        onDemandSnapshotCount
        osType
        privateIp
        region
        resourceGroup {
          id
          name
          subscription {
            id
            name
            slaPauseStatus
            azureSubscriptionStatus
          }
          slaPauseStatus
        }
        sizeType
        slaAssignment
        slaPauseStatus
        subnetName
        tags {
          key
          value
        }
        virtuaMachineNativeId
        vmAppConsistentSpecs {
          cancelBackupIfPreScriptFails
          postScriptTimeoutInSeconds
          postSnapshotScriptPath
          preScriptTimeoutInSeconds
          preSnapshotScriptPath
          rbaStatus
        }
        vmName
        vnetName
        securityMetadata {
          sensitivityStatus
          mediumSensitiveHits
          lowSensitiveHits
          highSensitiveHits
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
$VMNativeID = $CloudVM.cloudNativeId
$VMType = $CloudVM.sizeType
$VMNetwork = $CloudVM.vnetName
$VMRegion = $CloudVM.region
$VMIsRelic = $CloudVM.isRelic
$VMSLAInfo = $CloudVM.effectiveSlaDomain
$VMSLADomain = $VMSLAInfo.name
$VMSLADomainID = $VMSLAInfo.id
$VMSLAAssignment = $CloudVM.slaAssignment
$VMSLADomainPauseStatus = $CloudVM.slaPauseStatus
$VMAccountInfo = $CloudVM.resourceGroup
$VMAccountID = $VMAccountInfo.id
$VMAccountName = $VMAccountInfo.name
$VMAccountNativeID = $VMAccountInfo.id
$VMAccountStatus = $VMAccountInfo.subscription.azureSubscriptionStatus
# New fields 07/09/24
$VMTags = $CloudVM.tags
$VMTagsCount = $VMTags | Measure-Object | Select-Object -ExpandProperty Count
$VMDisks = $CloudVM.attachedManagedDisks
$VMDisksCount = $VMDisks | Measure-Object | Select-Object -ExpandProperty Count
$VMPrivateIP = $CloudVM.privateIp
$VMTotalSnapshots = $CloudVM.snapshotDistribution.totalCount
# Snapshot info
$VMSnapshotDateUNIX = $CloudVM.newestSnapshot.date
$VMSnapshotDateID = $CloudVM.newestSnapshot.id
IF($VMSnapshotDateUNIX -ne $null){$VMSnapshotDateUTC = Convert-RSCUNIXTime $VMSnapshotDateUNIX}ELSE{$VMSnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($VMSnapshotDateUTC -ne $null){$VMSnapshotTimespan = New-TimeSpan -Start $VMSnapshotDateUTC -End $UTCDateTime;$VMSnapshotHoursSince = $VMSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$VMSnapshotHoursSince = [Math]::Round($VMSnapshotHoursSince,1)}ELSE{$VMSnapshotHoursSince = $null}
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
$Object | Add-Member -MemberType NoteProperty -Name "PrivateIP" -Value $VMPrivateIP
$Object | Add-Member -MemberType NoteProperty -Name "Disks" -Value $VMDisksCount
$Object | Add-Member -MemberType NoteProperty -Name "TagsAssigned" -Value $VMTagsCount
$Object | Add-Member -MemberType NoteProperty -Name "Tags" -Value $VMTags
$Object | Add-Member -MemberType NoteProperty -Name "Snapshots" -Value $VMTotalSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTC" -Value $VMSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTCAgeHours" -Value $VMSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $VMSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $VMSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "PauseStatus" -Value $VMSLADomainPauseStatus
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $VMSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $VMIsRelic
$Object | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $VMAccountID
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $VMAccountName
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionType" -Value "AzureSubscription"
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionNativeID" -Value $VMAccountNativeID
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionStatus" -Value $VMAccountStatus
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