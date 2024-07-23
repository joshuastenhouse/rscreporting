################################################
# Function - Write-RSCAWSTagAssignments - Inserting all RSC Audit events into SQL
################################################
Function Write-RSCAWSTagAssignments {

<#
.SYNOPSIS
Collects the AWS tag assignments writes them to an existing MS SQL databse of your choosing, if not specified the default table name RSCAWSTagAssignments will created (so you don't need to know the required structure).

.DESCRIPTION
Requires the Sqlserver PowerShell module to be installed, connects and writes RSC evevents into the MS SQL server and DB specified as the user running the script (ensure you have sufficient SQL permissions), creates the required table structure if required. Ensure the DB already exists but the table does not on first run (so it can create it). It uses permanent tables in tempdb for scale (as each Invoke-SQLCmd is a unique connection), this can be disabled with the DontUseTempDB switch.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SQLInstance
The SQL server and instance name (if required) to connect to your MS SQL server. Ensure the user running the script has permission to connect, recommended to check using MS SQL Mgmt Studio first.
.PARAMETER SQLDB
The SQL database in which to create the required table to write the events. This must already exist, it will not create the database for you.
.PARAMETER SQLTable
Not required, it will create a table called RSCAWSTagAssignments for you, but you can customize the name (not the structure). Has to not already exist on 1st run unless you already used the correct structure. 
.PARAMETER DontUseTempDB
Switch to disable use of TempDB for scale. Use if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.
.PARAMETER DropExistingRows
Switch to drop existing rows each time before inserting, it will automatically remove any duplicates for you, so only use this if you don't want to see historical tag assignments (IsRelic).

.OUTPUTS
None, all the events are written into the MS SQL DB specified.

.EXAMPLE
Write-RSCAWSTagAssignments -SQLInstance "localhost" -SQLDB "RSCReprting"
This example collects all events from the default last 24 hours and writes them into a table named RSCEventsAudit that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEventsAudit -SQLInstance "localhost" -SQLDB "RSCReprting" -SQLTable "MyTableName" -DontUseTempDB
As above, but doesn't use regular tables in TempDB if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
	Param
    (
        [Parameter(Mandatory=$true)]$SQLInstance,[Parameter(Mandatory=$true)]$SQLDB,$SQLTable,
        [switch]$DropExistingRows,
        [switch]$DontUseTempDB
    )

################################################
# Importing Module & Running Required Functions
################################################
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
# Checking SQL module
Test-RSCSQLModule
################################################
# Importing SQL Server Module
################################################
# Getting the name of the SQL Server module to use (either SqlServer or SQLPS)
$PSModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name
$SQLModuleName = $PSModules | Where-Object {(($_ -eq "SQLPS") -or ($_ -eq "SqlServer"))} | Select-Object -Last 1
# Checking to see if SQL Server module is loaded
$SQLModuleCheck = Get-Module $SQLModuleName
# If SQL module not found in current session importing
IF($SQLModuleCheck -eq $null){Import-Module $SQLModuleName -ErrorAction SilentlyContinue}
##########################
# SQL - Checking Table Exists
##########################
# Manually setting SQL table name if not specified
IF($SQLTable -eq $null){$SQLTable = "RSCAWSTagAssignments"}
# Creating query
$SQLTableListQuery = "USE $SQLDB;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;"
# Run SQL query
Try
{
$SQLTableList = Invoke-SQLCmd -Query $SQLTableListQuery -ServerInstance $SQLInstance -QueryTimeout 300 
}
Catch
{
$Error[0] | Format-List -Force
}
# Selecting
$SQLTableList = $SQLTableList | Select-Object -ExpandProperty TABLE_NAME
# Checking
IF($SQLTableList -match $SQLTable){$SQLTableExists = $TRUE}ELSE{$SQLTableExists = $FALSE}
##########################
# SQL - Creating table if doesn't exist
##########################
IF($SQLTableExists -eq $FALSE)
{
# Logging
Write-Host "----------------------------------
SQLTableNotFound
CreatingSQLTable: $SQLTable"
Sleep 3
# SQL query
$SQLCreateTable = "USE $SQLDB;
CREATE TABLE [dbo].[$SQLTable](
	[RowID] [int] IDENTITY(1,1) NOT NULL,
    [RSCInstance] [varchar](max) NULL,
	[DateUTC] [datetime] NULL,
	[Cloud] [varchar](max) NULL,
    [Tag] [varchar](max) NULL,
	[TagKey] [varchar](max) NULL,
	[ObjectType] [varchar](max) NULL,
	[Object] [varchar](max) NULL,
	[ObjectID] [varchar](max) NULL,
	[Account] [varchar](max) NULL,
	[AccountID] [varchar](max) NULL,
    [TagAssignmentID] [varchar](max) NULL,
    [IsRelic] [varchar](50) NULL,
 CONSTRAINT [PK_$SQLTable] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];"
# Run SQL query
Try
{
Invoke-SQLCmd -Query $SQLCreateTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
# End of SQL table creation below
}
# End of SQL table creation above
##########################
# SQL - Creating temp table
##########################
IF($DontUseTempDB)
{
# Nothing to create, bypassing
}
ELSE
{
$RandomID = 0..10000 | Get-Random
# Create temp table name
$TempTableName =  $SQLTable + [string]$RandomID
# Create the table from an existing structure
$SQLCreateTable = "USE tempdb;
SELECT *   
INTO $TempTableName  
FROM $SQLDB.dbo.$SQLTable  
WHERE 1 > 2;"
# Run SQL query
Try
{
Invoke-SQLCmd -Query $SQLCreateTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
# Logging
Write-Host "----------------------------------
CreatingTableInTempDB: $TempTableName"
Start-Sleep 2
}
##################################
# SQL - Deleting Data From Existing Table if Switch
##################################
IF($DropExistingRows)
{
# Creating SQL query
$SQLDrop = "USE $SQLDB
DELETE FROM $SQLTable;"
# Run SQL query
Try
{
Invoke-SQLCmd -Query $SQLDrop -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
# Logging
Write-Host "----------------------------------
DeletingExistingRowsIn: $SQLTable"
}
################################################
# Getting times required
################################################
$ScriptStart = "{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date)
$UTCDateTime = [System.DateTime]::UtcNow
################################################
# Creating Array
################################################
$RSCTagAssignments = [System.Collections.ArrayList]@()
################################################
# Getting All AWS RDS instances
################################################
# Logging
Write-Host "----------------------------------
Collecting: AWS Tag Assignments"
# Creating array for objects
$CloudDBList = @()
# Building GraphQL query
$CloudDBListGraphql = @{"operationName" = "RDSInstancesListQuery";

"variables" = @{
"first" = 100
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
# Querying API
$CloudDBListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($CloudDBListGraphql | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$CloudDBList += $CloudDBListResponse.data.awsNativeRdsInstances.edges.node
# Getting all results from paginations
While ($CloudDBListResponse.data.awsNativeRdsInstances.pageInfo.hasNextPage) 
{
# Getting next set
$CloudDBListGraphql.variables.after = $CloudDBListResponse.data.awsNativeRdsInstances.pageInfo.endCursor
$CloudDBListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($CloudDBListGraphql | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
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
# Adding To Array for Each tag
ForEach($DBTag in $DBTags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "AWS"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $DBTag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $DBTag.key
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value "RDS"
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $DBName
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
"first" = 100
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
"first" = 100
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
################################################
# Processing Tag Assignments
################################################
$TotalTagAssignments = $RSCTagAssignments | Measure | Select-Object -ExpandProperty Count
# Logging
Write-Host "----------------------------------
TotalTagAssignments: $TotalTagAssignments
Inserting into TempTable.."
# For Each tag
ForEach ($RSCTag in $RSCTagAssignments)
{
# Setting variables
$RSCInstance = $RSCTag.RSCInstance
$Cloud = $RSCTag.Cloud
$Tag = $RSCTag.Tag
$TagKey = $RSCTag.TagKey
$ObjectType = $RSCTag.ObjectType
$Object = $RSCTag.Object
$ObjectID = $RSCTag.ObjectID
$Account = $RSCTag.Account
$AccountID = $RSCTag.AccountID
# Creating unique tag ID
$TagAssignmentID = $Tag + "-" + $ObjectID + "-" + "$AccountID"
############################
# Adding To SQL Table directly if no tempDB
############################
IF($DontUseTempDB)
{
$SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
-- Instance time & cloud
RSCInstance, DateUTC, Cloud,

-- Tag info
Tag, TagKey, ObjectType, Object, ObjectID,

-- Account info and relic tracking
Account, AccountID, TagAssignmentID, IsRelic)
VALUES(
-- Instance time & cloud
'$RSCInstance', '$UTCDateTime', '$Cloud', 

-- Tag info
'$Tag', '$TagKey', '$ObjectType', '$Object', '$ObjectID',

-- Account info & Generated Tag Assignment ID and IsRelic false as it's being inserted so must exist
'$Account', '$AccountID','$TagAssignmentID', 'FALSE');"
# Inserting
Try
{
Invoke-SQLCmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
}
ELSE
{
############################
# Adding To SQL temp table
############################
$SQLInsert = "USE tempdb
INSERT INTO $TempTableName (
-- Instance time & cloud
RSCInstance, DateUTC, Cloud,

-- Tag info
Tag, TagKey, ObjectType, Object, ObjectID,

-- Account info and relic tracking
Account, AccountID, TagAssignmentID, IsRelic)
VALUES(
-- Instance time & cloud
'$RSCInstance', '$UTCDateTime', '$Cloud', 

-- Tag info
'$Tag', '$TagKey', '$ObjectType', '$Object', '$ObjectID',

-- Account info & Generated Tag Assignment ID and IsRelic false as it's being inserted so must exist
'$Account', '$AccountID','$TagAssignmentID', 'FALSE');"
# Inserting
Try
{
Invoke-SQLCmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
# End of bypass for using tempdb below
}
# End of bypass for using tempdb above
#
# End of for each tag assignment below
}
# End of for each tag assignment above
##################################
# Finishing SQL Work
##################################
# Logging
Write-Host "----------------------------------
Finished Processing RSC Events
----------------------------------"
############################
# Removing Duplicates if not using TempDB
############################
IF($DontUseTempDB)
{
# Logging
Write-Host "RemovingDuplicatEventsFrom: $SQLTable
----------------------------------"
# Creating SQL query
$SQLQuery = "WITH cte AS (SELECT TagAssignmentID, ROW_NUMBER() OVER (PARTITION BY TagAssignmentID ORDER BY TagAssignmentID) rownum FROM $SQLDB.dbo.$SQLTable )
DELETE FROM cte WHERE rownum>1;"
# Run SQL query
Try
{
Invoke-SQLCmd -Query $SQLQuery -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
}
ELSE
{
############################
# Merging if using TempDB
############################
Write-Host "MergingTableInTempDB: $TempTableName"
Start-Sleep 3
# Creating SQL query
$SQLMergeTable = "MERGE $SQLDB.dbo.$SQLTable Target
USING tempdb.dbo.$TempTableName Source
ON (Target.TagAssignmentID = Source.TagAssignmentID)
WHEN NOT MATCHED BY TARGET
THEN INSERT (RSCInstance, DateUTC, Cloud,
            Tag, TagKey, ObjectType, Object, ObjectID,
            Account, AccountID, TagAssignmentID, IsRelic)
     VALUES (Source.RSCInstance, Source.DateUTC, Source.Cloud,
            Source.Tag, Source.TagKey, Source.ObjectType, Source.Object, Source.ObjectID,
            Source.Account, Source.AccountID, Source.TagAssignmentID, Source.IsRelic);"
# Run SQL query
Try
{
Invoke-SQLCmd -Query $SQLMergeTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
$SQLMergeSuccess = $TRUE
}
Catch
{
$SQLMergeSuccess = $FALSE
$Error[0] | Format-List -Force
}
##################################
# SQL - Updating Relics 
##################################
# Creating SQL query
$SQLUpdateRelics = "USE $SQLDB
UPDATE $SQLTable
SET IsRelic = 'TRUE'
FROM $SQLTable target
LEFT JOIN tempdb.dbo.$TempTableName source
  ON target.TagAssignmentID = source.TagAssignmentID
WHERE source.TagAssignmentID IS NULL;"
# Run SQL query
Try
{
Invoke-SQLCmd -Query $SQLUpdateRelics -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
##################################
# SQL - Deleting Temp Table
##################################
IF($SQLMergeSuccess -eq $TRUE)
{
# Creating SQL query
$SQLDropTable = "USE tempdb;
DROP TABLE $TempTableName;"
# Run SQL query
Try
{
Invoke-SQLCmd -Query $SQLDropTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
# Logging
Write-Host "----------------------------------
DroppedTableInTempDB: $TempTableName
----------------------------------"
}
ELSE
{
# Logging
Write-Host "----------------------------------
NotDroppedTableInTempDB: $TempTableName
SQLMergeSuccess: $SQLMergeSuccess
----------------------------------"	
}
Start-Sleep 2
# End of bypass for using tempDB below
}
# End of bypass for using tempDB above
##########################
# Benching
##########################
$ScriptEnd = "{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date)
IF (($ScriptStart -ne $null) -and ($ScriptEnd -ne $null))
{
$Timespan = New-TimeSpan -Start $ScriptStart -End $ScriptEnd
$ScriptDurationSeconds = $Timespan.TotalSeconds
$ScriptDurationSeconds = [Math]::Round($ScriptDurationSeconds)
$ScriptDuration = "{0:g}" -f $Timespan;$ScriptDuration = $ScriptDuration.Substring(0,8)
}
ELSE
{
$TimeTaken = 0
}
# Logging
Write-Host "----------------------------------
Script Execution Summary
----------------------------------
Start: $ScriptStart
End: $ScriptEnd
Runtime: $ScriptDuration"
# Returning null
Return $null
# End of function
}