################################################
# Function - Get-RSCAWSEBSVolumes - Getting All RSCAWSEBSVolumes connected to RSC
################################################
Function Get-RSCAWSEBSVolumes {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all EBS volumes in all AWS accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAWSEBSVolumes
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
$RSCCloudVolumes = [System.Collections.ArrayList]@()
################################################
# Getting All AWS EBS Volumes
################################################
# Creating array for objects
$CloudDiskList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AWSEbsVolumesListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query AWSEbsVolumesListQuery(`$first: Int, `$after: String) {
  awsNativeEbsVolumes(first: `$first,after: `$after) {
    edges {
      cursor
      node {
        id
        volumeNativeId
        volumeName
        volumeType
        region
        sizeInGiBs
        isRelic
        isExocomputeConfigured
        isIndexingEnabled
        isMarketplace
        ...EffectiveSlaColumnFragment
        awsNativeAccount {
          id
          name
          status
          __typename
        }
        slaAssignment
        attachedEc2Instances {
          id
          instanceName
          instanceNativeId
          __typename
        }
        ...AwsSlaAssignmentColumnFragment
        __typename
        tags {
          key
          value
        }
        awsAccountRubrikId
        availabilityZone
        awsNativeAccountName
        cloudNativeId
        effectiveSlaDomain {
          id
          name
        }
        iops
        name
        newestSnapshot {
          date
          id
        }
        oldestSnapshot {
          id
          date
        }
        slaPauseStatus
        physicalPath {
          objectType
          name
          fid
        }
        attachmentSpecs {
          awsNativeEc2InstanceId
          isExcludedFromSnapshot
          devicePath
          isRootVolume
        }
        nativeName
        objectType
        onDemandSnapshotCount
      }
      __typename
    }
    __typename
    pageInfo {
      endCursor
      hasNextPage
      startCursor
      hasPreviousPage
    }
  }
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


"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$CloudDiskListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$CloudDiskList += $CloudDiskListResponse.data.awsNativeEbsVolumes.edges.node
# Getting all results from paginations
While ($CloudDiskListResponse.data.awsNativeEbsVolumes.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $CloudDiskListResponse.data.awsNativeEbsVolumes.pageInfo.endCursor
$CloudDiskListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$CloudDiskList += $CloudDiskListResponse.data.awsNativeEbsVolumes.edges.node
}
################################################
# Processing AWS EBS Volumes
################################################
# For Each Object Getting Data
ForEach ($CloudDisk in $CloudDiskList)
{
# Setting variables
$VolumeID = $CloudDisk.id
$VolumeName = $CloudDisk.name
$VolumeNativeID = $CloudDisk.volumeNativeID
$VolumeType = $CloudDisk.volumeType
$VolumeRegion = $CloudDisk.region
$VolumeSizeGB = $CloudDisk.sizeInGibs
$VolumeIsRelic = $CloudDisk.isRelic
$VolumeIsExocomputeConfigured = $CloudDisk.isExoComputeConfigured
$VolumeIsIndexingEnabled = $CloudDisk.isIndexingEnabled
$VolumeSLADomain = $CloudDisk.effectiveSlaDomain.name
$VolumeSLADomainID = $CloudDisk.effectiveSlaDomain.id
$VolumeSLAAssignment = $CloudDisk.slaAssignment
$VolumeAccountInfo = $CloudDisk.awsNativeAccount
$VolumeAccountID = $VolumeAccountInfo.id
$VolumeAccountName = $VolumeAccountInfo.name
$VolumeAccountNativeID = $VolumeAccountInfo.id
$VolumeAccountStatus = $VolumeAccountInfo.status
$VolumeTags = $CloudDisk.tags  | Select-Object Key,value
# Getting URL
$VolumeURL = Get-RSCObjectURL -ObjectType "AwsNativeEbsVolume" -ObjectID $VMID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWSEBS"
$Object | Add-Member -MemberType NoteProperty -Name "Volume" -Value $VolumeName
$Object | Add-Member -MemberType NoteProperty -Name "VolumeID" -Value $VolumeID
$Object | Add-Member -MemberType NoteProperty -Name "VolumeNativeID" -Value $VolumeNativeID
$Object | Add-Member -MemberType NoteProperty -Name "VolumeType" -Value $VolumeType
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $VolumeRegion
$Object | Add-Member -MemberType NoteProperty -Name "SizeGB" -Value $VolumeSizeGB
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $VolumeSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $VolumeSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $VolumeSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "Tags" -Value $VolumeTags
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $VolumeIsRelic
$Object | Add-Member -MemberType NoteProperty -Name "IsExocomputeConfigured" -Value $VolumeIsExocomputeConfigured
$Object | Add-Member -MemberType NoteProperty -Name "IsIndexingEnabled" -Value $VolumeIsIndexingEnabled
$Object | Add-Member -MemberType NoteProperty -Name "AccountType" -Value "AWSAccount"
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $VolumeAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $VolumeAccountID
$Object | Add-Member -MemberType NoteProperty -Name "AccountNativeID" -Value $VolumeAccountNativeID
$Object | Add-Member -MemberType NoteProperty -Name "AccountStatus" -Value $VolumeAccountStatus
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $VolumeURL
# Adding
$RSCCloudVolumes.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCCloudVolumes
# End of function
}