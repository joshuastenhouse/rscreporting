################################################
# Function - Get-RSCAWSTagAssignments - Getting All RSCAWSTagAssignments connected to RSC
################################################
Function Get-RSCAWSTagAssignments {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all EC2 and RDS tags assigned in all AWS accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAWSTagAssignments
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 10/29/2025
#>

################################################
# Paramater Config
################################################
	Param
    (
        [Parameter(Mandatory=$false)]$TagFilter
    )
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
# Getting All AWS RDS instances
################################################
# Creating array for objects
$CloudDBList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "RDSInstancesListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query RDSInstancesListQuery(`$first: Int, `$after: String, `$sortBy: AwsNativeRdsInstanceSortFields, `$sortOrder: SortOrder, `$filters: AwsNativeRdsInstanceFilters, `$isMultitenancyEnabled: Boolean = false) {
  awsNativeRdsInstances(first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder, rdsInstanceFilters: `$filters) {
    edges {
      cursor
      node {
        id
        vpcName
        region
        vpcId
        isRelic
        dbEngine
        dbInstanceName
        dbiResourceId
        allocatedStorageInGibi
        dbInstanceClass
        tags {
         key
         value
         }
        readReplicaSourceName
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
        effectiveSlaSourceObject {
          fid
          name
          objectType
          __typename
        }
        ...AwsSlaAssignmentColumnFragment
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
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$CloudDBListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$CloudDBList += $CloudDBListResponse.data.awsNativeRdsInstances.edges.node
# Getting all results from paginations
While ($CloudDBListResponse.data.awsNativeRdsInstances.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $CloudDBListResponse.data.awsNativeRdsInstances.pageInfo.endCursor
$CloudDBListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$CloudDBList += $CloudDBListResponse.data.awsNativeRdsInstances.edges.node
}
################################################
# Processing AWS RDS
################################################
# For Each Object Getting Data
ForEach ($CloudDB in $CloudDBList)
{
# Setting variables
$DBID = $CloudDB.id
$DBInfo = $CloudDB.effectiveSlaSourceObject
$DBName = $DBInfo.name
$DBEngine = $CloudDB.dbEngine
$DBInstance = $CloudDB.dbInstanceName
$DBResourceID = $CloudDB.DbiResourceId
$DBAllocatedStorageGB = $CloudDB.allocatedStorageInGibi
$DBClass = $CloudDB.dbInstanceClass
$DBRegion = $CloudDB.region
$DBVPCID = $CloudDB.vpcId
$DBIsRelic = $CloudDB.isRelic
$DBAccountInfo = $CloudDB.awsNativeAccount
$DBAccountID = $DBAccountInfo.id
$DBAccountName = $DBAccountInfo.name
$DBAccountStatus = $DBAccountInfo.status
$DBSLADomainInfo = $CloudDB.effectiveSlaDomain
$DBSLADomainID = $DBSLADomainInfo.id
$DBSLADomain = $DBSLADomainInfo.name
$DBSLAAssignment = $CloudDB.slaAssignment
$DBTags = $CloudDB.tags | Select-Object Key,value
# Filtering tags if variable supplied
IF($TagFilter -ne $null)
{
$DBTags = $DBTags | Where-Object {$_.value -match $TagFilter}
}
# Adding To Array for Each tag
ForEach($DBTag in $DBTags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWS"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $DBTag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $DBTag.key
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value "RDS"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $DBInstance
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $DBAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $DBAccountID
# Adding
$RSCTagAssignments.Add($Object) | Out-Null
# End of for each tag assignment below
}
# End of for each object below
}
# End of for each object above
################################################
# Getting All AWS EC2 instances
################################################
# Creating array for objects
$CloudVMList = @()
# Building GraphQL query
$CloudVMListGraphql = @{"operationName" = "EC2InstancesListQuery";

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
# Querying API
$CloudVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($CloudVMListGraphql | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$CloudVMList += $CloudVMListResponse.data.awsNativeEc2Instances.edges.node
# Getting all results from paginations
While ($CloudVMListResponse.data.awsNativeEc2Instances.pageInfo.hasNextPage) 
{
# Getting next set
$CloudVMListGraphql.variables.after = $CloudVMListResponse.data.awsNativeEc2Instances.pageInfo.endCursor
$CloudVMListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($CloudVMListGraphql | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
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
# Filtering tags if variable supplied
IF($TagFilter -ne $null)
{
$VMTags = $VMTags | Where-Object {$_.value -match $TagFilter}
}
# Adding To Array for Each tag
ForEach($VMTag in $VMTags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWS"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $VMTag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $VMTag.key
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value "EC2"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $VMName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $VMAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $VMAccountID
# Adding
$RSCTagAssignments.Add($Object) | Out-Null
# End of for each tag assignment below
}
# End of for each tag assignment above
#
# End of for each object below
}
# End of for each object above
################################################
# Processing AWS EBS Volumes 
################################################
# Creating array for objects
$CloudDiskList = @()
# Building GraphQL query
$CloudDiskListGraphql = @{"operationName" = "AWSEbsVolumesListQuery";

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
# Querying API
$CloudDiskListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($CloudDiskListGraphql | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$CloudDiskList += $CloudDiskListResponse.data.awsNativeEbsVolumes.edges.node
# Getting all results from paginations
While ($CloudDiskListResponse.data.awsNativeEbsVolumes.pageInfo.hasNextPage) 
{
# Getting next set
$CloudDiskListGraphql.variables.after = $CloudDiskListResponse.data.awsNativeEbsVolumes.pageInfo.endCursor
$CloudDiskListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($CloudDiskListGraphql | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
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
# Filtering tags if variable supplied
IF($TagFilter -ne $null)
{
$VolumeTags = $VolumeTags | Where-Object {$_.value -match $TagFilter}
}
# Adding To Array for Each tag
ForEach($VolumeTag in $VolumeTags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWS"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $VolumeTag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $VolumeTag.key
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value "EBS"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $VolumeName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $VolumeID
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $VolumeAccountName
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $VolumeAccountID
$Object | Add-Member -MemberType NoteProperty -Name "AccountNativeID" -Value $VolumeAccountNativeID
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