################################################
# Function - Write-RSCObjectStorageUsage - Getting all RSC Object Storage Usage
################################################
Function Write-RSCObjectStorageUsage {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for writing ObjectStorageUsage data into a MSSQL DB/Table of your choosing.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.PARAMETER SQLInstance
The SQL server and instance name (if required) to connect to your MS SQL server. Ensure the user running the script has permission to connect, recommended to check using MS SQL Mgmt Studio first.
.PARAMETER SQLDB
The SQL database in which to create the required table to write the events. This must already exist, it will not create the database for you.
.PARAMETER SQLTable
Not required, it will create a table called RSCEvents for you, but you can customize the name (not the structure). Has to not already exist on 1st run unless you already used the correct structure. 
.PARAMETER DontUseTempDB
Switch to disable use of TempDB for scale. Use if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.
.PARAMETER DropExistingRows
Drops all existing rows in the table specified, otherwise it just uses a new datetime on each run (so you can either just maintain the latest, or over time on a frequency you desire).
.PARAMETER SampleFirst10Objects
If you have a large environment and simply want to do a test run, use this to get a sample.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
None, all the events are written into the MS SQL DB specified.

.EXAMPLE
Write-RSCObjectStorageUsage -SQLInstance "localhost" -SQLDB "YourDBName"
This example gets all object storage usage, creates a table called RSCObjectStorageUsage with the required structure then populates it with the API data.

.EXAMPLE
Write-RSCObjectStorageUsage -SQLInstance "localhost" -SQLDB "YourDBName" -DontUseTempDB
This example does the same as above, but doesn't use TempDB (if you have permissions issues with creating tables in it and aren't concerned about locks).

.EXAMPLE
Write-RSCObjectStorageUsage -SQLInstance "localhost" -SQLDB "YourDBName" -SQLTable "YourTableName" 
This example gets all object storage usage, creates a table using the name specified with the required structure then populates it with the API data.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
	Param
    (
        [Parameter(Mandatory=$true)]$SQLInstance,
		[Parameter(Mandatory=$true)]$SQLDB,$SQLTable,
        [switch]$DropExistingRows,
        [switch]$DontUseTempDB,
        [switch]$SampleFirst10Objects,
		[switch]$LogProgress
    )
	
################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting list of objects
$RSCObjects = Get-RSCObjects
################################################
# Getting times required
################################################
$ScriptStart = Get-Date
$MachineDateTime = Get-Date
$UTCDateTime = [System.DateTime]::UtcNow
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
IF($SQLTable -eq $null){$SQLTable = "RSCObjectStorageUsage"}
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
Start-Sleep 3
# SQL query
$SQLCreateTable = "USE $SQLDB;
CREATE TABLE [dbo].[$SQLTable](
	[RowID] [int] IDENTITY(1,1) NOT NULL,
	[DateUTC] [datetime] NULL,
	[RSCInstance] [varchar](max) NULL,
	[Object] [varchar](max) NULL,
	[ObjectID] [varchar](max) NULL,
	[ObjectCDMID] [varchar](max) NULL,
	[Type] [varchar](max) NULL,
	[Location] [varchar](max) NULL,
	[RubrikCluster] [varchar](max) NULL,
	[RubrikClusterID] [varchar](max) NULL,
	[SLADomain] [varchar](max) NULL,
	[SLADomainID] [varchar](max) NULL,
	[Org] [varchar](50) NULL,
	[SLADomainRetentionLock] [varchar](50) NULL,
	[TotalSnapshots] [int] NULL,
	[ProtectedOn] [datetime] NULL,
	[LastSnapshot] [datetime] NULL,
	[PendingFirstFull] [varchar](50) NULL,
	[DataReduction] [decimal](18, 2) NULL,
	[LogicalDataReduction] [decimal](18, 2) NULL,
	[TotalUsedGB] [decimal](18, 2) NULL,
	[ProtectedGB] [decimal](18, 2) NULL,
	[LocalStorageGB] [decimal](18, 2) NULL,
	[TransferredGB] [decimal](18, 2) NULL,
	[LogicalGB] [decimal](18, 2) NULL,
	[ReplicaStorageGB] [decimal](18, 2) NULL,
	[ArchiveStorageGB] [decimal](18, 2) NULL,
	[LastSnapshotLogicalGB] [decimal](18, 2) NULL,
	[LocalMeteredDataGB] [decimal](18, 2) NULL,
	[UsedGB] [decimal](18, 2) NULL,
	[ProvisionedGB] [decimal](18, 2) NULL,
	[LocalProtectedGB] [decimal](18, 2) NULL,
	[LocalEffectiveStorageGB] [decimal](18, 2) NULL,
	[TotalUsedBytes] [bigint] NULL,
	[ProtectedBytes] [bigint] NULL,
	[LocalStorageBytes] [bigint] NULL,
	[TransferredBytes] [bigint] NULL,
	[LogicalBytes] [bigint] NULL,
	[ReplicaStorageBytes] [bigint] NULL,
	[ArchiveStorageBytes] [bigint] NULL,
	[LastSnapshotLogicalBytes] [bigint] NULL,
	[LocalMeteredDataBytes] [bigint] NULL,
	[UsedBytes] [bigint] NULL,
	[ProvisionedBytes] [bigint] NULL,
	[LocalProtectedBytes] [bigint] NULL,
	[LocalEffectiveStorageBytes] [bigint] NULL,
    [Exported] [varchar](50) NULL,
    [URL] [varchar](max) NULL,
 CONSTRAINT [PK_$SQLTable] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON) ON [PRIMARY]
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
# Getting RSC Objects
################################################
# Logging
Write-Host "----------------------------------
Collecting: Object Storage Usage..."
# Creating array for events
$ObjectStorageList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "CapacityTableQuery";

"variables" = @{
"first" = 1000
};

"query" = "query CapacityTableQuery(`$first: Int!, `$after: String) {
  snappableConnection(first: `$first, after: `$after) {
    edges {
      cursor
      node {
        id
        fid
        name
        objectType
        cluster {
          id
          name
          __typename
        }
        slaDomain {
          id
          name
          ... on GlobalSlaReply {
            isRetentionLockedSla
            __typename
          }
          ... on ClusterSlaDomain {
            isRetentionLockedSla
            __typename
          }
          __typename
        }
        location
        physicalBytes
        transferredBytes
        logicalBytes
        replicaStorage
        archiveStorage
        dataReduction
        logicalDataReduction
        lastSnapshotLogicalBytes
        pullTime
        localStorage
        localMeteredData
        usedBytes
        provisionedBytes
        localProtectedData
        localEffectiveStorage
        orgName
        __typename
      }
      __typename
    }
    pageInfo {
      endCursor
      hasNextPage
      __typename
    }
    __typename
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$ObjectStorageResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 32) -Headers $RSCSessionHeader
$ObjectStorageList += $ObjectStorageResponse.data.snappableConnection.edges.node
# Getting all results from paginations
While ($ObjectStorageResponse.data.snappableConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $ObjectStorageResponse.data.snappableConnection.pageInfo.endCursor
$ObjectStorageResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$ObjectStorageList += $ObjectStorageResponse.data.snappableConnection.edges.node
}
# Counting
$ObjectStorageListCount = $ObjectStorageList | Measure-Object | Select-Object -ExpandProperty Count
$ObjectStorageListCounter = 0
################################################
# Processing Objects
################################################
$RSCObjectStorageUsage = [System.Collections.ArrayList]@()
# For Each Getting info
ForEach ($ObjectListed in $ObjectStorageList)
{
$ObjectStorageListCounter ++
Write-Host "ProcessingObject: $ObjectStorageListCounter/$ObjectStorageListCount"
# Setting variables
$ObjectName = $ObjectListed.name
$ObjectID = $ObjectListed.fid
$ObjectCDMID =$ObjectListed.id
$ObjectType = $ObjectListed.objectType
$ObjectLocation = $ObjectListed.location
$RubrikCluster = $ObjectListed.cluster.name
$RubrikClusterID = $ObjectListed.cluster.id
$SLADomain = $ObjectListed.slaDomain.name
$SLADomainID = $ObjectListed.slaDomain.id
$SLADomainIsRetentionLocked = $ObjectListed.slaDomain.isRetentionLockedSla
$LastUpdatedUNIX = $ObjectListed.pullTime
$OrgName = $ObjectListed.orgName
# Getting data from object list
$ObjectListData = $RSCObjects | Where-Object {$_.ObjectID -eq $ObjectID}
$ProtectedOn = $ObjectListData.ProtectedOn
$LastSnapshot = $ObjectListData.LastSnapshot
$PendingFirstFull = $ObjectListData.PendingFirstFull
$TotalSnapshots = $ObjectListData.TotalSnapshots;IF($TotalSnapshots -eq $null){$TotalSnapshots = 0}
# Getting URL
$ObjectURL = $ObjectListData.URL
# Fixing cluster name
IF($RubrikCluster -eq "Polaris"){$RubrikCluster = "RSC-Native"}
# Converting time
IF($LastUpdatedUNIX -ne $null){$LastUpdatedUTC = Convert-RSCUNIXTime $LastUpdatedUNIX}ELSE{$LastUpdatedUTC = $null}
# Data reduction stats
$DataReduction = $ObjectListed.dataReduction
$LogicalDataReduction = $ObjectListed.logicalDataReduction
# Getting storage stats
$physicalBytes = $ObjectListed.physicalBytes
$transferredBytes = $ObjectListed.transferredBytes
$logicalBytes = $ObjectListed.logicalBytes
$replicaStorage = $ObjectListed.replicaStorage
$archiveStorage = $ObjectListed.archiveStorage
$lastSnapshotLogicalBytes = $ObjectListed.lastSnapshotLogicalBytes
$localStorage = $ObjectListed.localStorage
$localMeteredData = $ObjectListed.localMeteredData
$usedBytes = $ObjectListed.usedBytes
$provisionedBytes = $ObjectListed.provisionedBytes
$localProtectedData = $ObjectListed.localProtectedData
$localEffectiveStorage = $ObjectListed.localEffectiveStorage
# Converting storage units
IF($physicalBytes -ne $null){$PhysicalGB = $physicalBytes / 1000 / 1000 / 1000}ELSE{$PhysicalGB = $null}
IF($transferredBytes -ne $null){$TransferredGB = $transferredBytes / 1000 / 1000 / 1000}ELSE{$TransferredGB = $null}
IF($logicalBytes -ne $null){$LogicalGB = $logicalBytes / 1000 / 1000 / 1000}ELSE{$LogicalGB = $null}
IF($replicaStorage -ne $null){$ReplicaStorageGB = $replicaStorage / 1000 / 1000 / 1000}ELSE{$ReplicaStorageGB = $null}
IF($archiveStorage -ne $null){$ArchiveStorageGB = $archiveStorage / 1000 / 1000 / 1000}ELSE{$ArchiveStorageGB = $null}
IF($lastSnapshotLogicalBytes -ne $null){$LastSnapshotLogicalGB = $lastSnapshotLogicalBytes / 1000 / 1000 / 1000}ELSE{$LastSnapshotLogicalGB = $null}
IF($localStorage -ne $null){$LocalStorageGB = $localStorage / 1000 / 1000 / 1000}ELSE{$LocalStorageGB = $null}
IF($localMeteredData -ne $null){$LocalMeteredDataGB = $localMeteredData / 1000 / 1000 / 1000}ELSE{$LocalMeteredDataGB = $null}
IF($usedBytes -ne $null){$UsedGB = $usedBytes / 1000 / 1000 / 1000}ELSE{$UsedGB = $null}
IF($provisionedBytes -ne $null){$ProvisionedGB = $provisionedBytes / 1000 / 1000 / 1000}ELSE{$ProvisionedGB = $null}
IF($localProtectedData -ne $null){$LocalProtectedGB = $localProtectedData / 1000 / 1000 / 1000}ELSE{$LocalProtectedGB = $null}
IF($localEffectiveStorage -ne $null){$LocalEffectiveStorageGB = $localEffectiveStorage / 1000 / 1000 / 1000}ELSE{$LocalEffectiveStorageGB = $null}
# Getting totals
$TotalUsedBytes = $localStorage + $archiveStorage + $replicaStorage
IF($TotalUsedBytes -ne $null){$TotalUsedGB = $TotalUsedBytes / 1000 / 1000 / 1000;$TotalUsedGB = [Math]::Round($TotalUsedGB,2)}ELSE{$TotalUsedGB = $null}
# Rounding
IF($TotalUsedGB -ne $null){$TotalUsedGB = [Math]::Round($TotalUsedGB,2)}
IF($PhysicalGB -ne $null){$PhysicalGB = [Math]::Round($PhysicalGB,2)}
IF($TransferredGB -ne $null){$TransferredGB = [Math]::Round($TransferredGB,2)}
IF($LogicalGB -ne $null){$LogicalGB = [Math]::Round($LogicalGB,2)}
IF($ReplicaStorageGB -ne $null){$ReplicaStorageGB = [Math]::Round($ReplicaStorageGB,2)}
IF($ArchiveStorageGB -ne $null){$ArchiveStorageGB = [Math]::Round($ArchiveStorageGB,2)}
IF($LastSnapshotLogicalGB -ne $null){$LastSnapshotLogicalGB = [Math]::Round($LastSnapshotLogicalGB,2)}
IF($LocalStorageGB -ne $null){$LocalStorageGB = [Math]::Round($LocalStorageGB,2)}
IF($LocalMeteredDataGB -ne $null){$LocalMeteredDataGB = [Math]::Round($LocalMeteredDataGB,2)}
IF($UsedGB -ne $null){$UsedGB = [Math]::Round($UsedGB,2)}
IF($ProvisionedGB -ne $null){$ProvisionedGB = [Math]::Round($ProvisionedGB,2)}
IF($LocalProtectedGB -ne $null){$LocalProtectedGB = [Math]::Round($LocalProtectedGB,2)}
IF($LocalProtectedGB -ne $null){$LocalProtectedGB = [Math]::Round($LocalProtectedGB,2)}
IF($LocalEffectiveStorageGB -ne $null){$LocalEffectiveStorageGB = [Math]::Round($LocalEffectiveStorageGB,2)}
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $ObjectCDMID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ObjectLocation
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Org" -Value $OrgName
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainRetentionLock" -Value $SLADomainIsRetentionLocked
$Object | Add-Member -MemberType NoteProperty -Name "TotalSnapshots" -Value $TotalSnapshots
# Other useful info
$Object | Add-Member -MemberType NoteProperty -Name "LastUpdatedUTC" -Value $LastUpdatedUTC
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $ProtectedOn
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $LastSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $PendingFirstFull
# Data reduction
$Object | Add-Member -MemberType NoteProperty -Name "DataReduction" -Value $DataReduction
$Object | Add-Member -MemberType NoteProperty -Name "LogicalDataReduction" -Value $LogicalDataReduction
# Storage stats in GB
$Object | Add-Member -MemberType NoteProperty -Name "TotalUsedGB" -Value $TotalUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedGB" -Value $PhysicalGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalStorageGB" -Value $LocalStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "TransferredGB" -Value $TransferredGB
$Object | Add-Member -MemberType NoteProperty -Name "LogicalGB" -Value $LogicalGB
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaStorageGB" -Value $ReplicaStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveStorageGB" -Value $ArchiveStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshotLogicalGB" -Value $LastSnapshotLogicalGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalMeteredDataGB" -Value $LocalMeteredDataGB
$Object | Add-Member -MemberType NoteProperty -Name "UsedGB" -Value $UsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedGB" -Value $ProvisionedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalProtectedGB" -Value $LocalProtectedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalEffectiveStorageGB" -Value $LocalEffectiveStorageGB
# Storage stats in bytes
$Object | Add-Member -MemberType NoteProperty -Name "TotalUsedBytes" -Value $TotalUsedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedBytes" -Value $physicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalStorageBytes" -Value $localStorage
$Object | Add-Member -MemberType NoteProperty -Name "TransferredBytes" -Value $transferredBytes
$Object | Add-Member -MemberType NoteProperty -Name "LogicalBytes" -Value $logicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaStorageBytes" -Value $replicaStorage
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveStorageBytes" -Value $archiveStorage
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshotLogicalBytes" -Value $lastSnapshotLogicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalMeteredDataBytes" -Value $localMeteredData
$Object | Add-Member -MemberType NoteProperty -Name "UsedBytes" -Value $usedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedBytes" -Value $provisionedBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalProtectedBytes" -Value $localProtectedData
$Object | Add-Member -MemberType NoteProperty -Name "LocalEffectiveStorageBytes" -Value $localEffectiveStorage
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding to array
# $RSCObjectStorageUsage.Add($Object) | Out-Null
############################
# SQL Pre-Insert Work
############################
# Fixing nulls for SQL insert
IF($DataReduction -eq $null){$DataReduction = 0}
IF($LogicalDataReduction -eq $null){$LogicalDataReduction = 0}
IF($TotalUsedGB -eq $null){$TotalUsedGB = 0}
IF($PhysicalGB -eq $null){$PhysicalGB = 0}
IF($LocalStorageGB -eq $null){$LocalStorageGB = 0}
IF($TransferredGB -eq $null){$TransferredGB = 0}
IF($LogicalGB -eq $null){$LogicalGB = 0}
IF($ReplicaStorageGB -eq $null){$ReplicaStorageGB = 0}
IF($ArchiveStorageGB -eq $null){$ArchiveStorageGB = 0}
IF($LastSnapshotLogicalGB -eq $null){$LastSnapshotLogicalGB = 0}
IF($LocalMeteredDataGB -eq $null){$LocalMeteredDataGB = 0}
IF($UsedGB -eq $null){$UsedGB = 0}
IF($ProvisionedGB -eq $null){$ProvisionedGB = 0}
IF($LocalProtectedGB -eq $null){$LocalProtectedGB = 0}
IF($LocalEffectiveStorageGB -eq $null){$LocalEffectiveStorageGB = 0}
IF($TotalUsedBytes -eq $null){$TotalUsedBytes = 0}
IF($physicalBytes -eq $null){$physicalBytes = 0}
IF($localStorage -eq $null){$localStorage = 0}
IF($transferredBytes -eq $null){$transferredBytes = 0}
IF($logicalBytes -eq $null){$logicalBytes = 0}
IF($replicaStorage -eq $null){$replicaStorage = 0}
IF($archiveStorage -eq $null){$archiveStorage = 0}
IF($lastSnapshotLogicalBytes -eq $null){$lastSnapshotLogicalBytes = 0}
IF($localMeteredData -eq $null){$localMeteredData = 0}
IF($usedBytes -eq $null){$usedBytes = 0}
IF($provisionedBytes -eq $null){$provisionedBytes = 0}
IF($localProtectedData -eq $null){$localProtectedData = 0}
IF($localEffectiveStorage -eq $null){$localEffectiveStorage = 0}
# Removing illegal SQL characters from object or location
$ObjectName = $ObjectName.Replace("'","")
$ObjectLocation = $ObjectLocation.Replace("'","")
############################
# Adding To SQL Table directly if no tempDB
############################
IF($DontUseTempDB)
{
$SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
-- Date RSC & Object IDs
DateUTC, RSCInstance, Object, ObjectID, ObjectCDMID, Type, Location,

-- Cluster & SLA info
RubrikCluster, RubrikClusterID, SLADomain, SLADomainID, Org,

-- Retention lock and snapshots
SLADomainRetentionLock, TotalSnapshots, ProtectedOn, LastSnapshot, PendingFirstFull,

-- Data Reduction
DataReduction, LogicalDataReduction,

-- GB Stats 1
TotalUsedGB, ProtectedGB, LocalStorageGB, TransferredGB,

-- GB Stats 2
LogicalGB, ReplicaStorageGB, ArchiveStorageGB,

-- GB Stats 3
LastSnapshotLogicalGB, LocalMeteredDataGB,

-- GB Stats 4
UsedGB,ProvisionedGB, LocalProtectedGB, LocalEffectiveStorageGB,

-- Bytes Stats 1
TotalUsedBytes, ProtectedBytes, LocalStorageBytes,

-- Bytes Stats 2
TransferredBytes, LogicalBytes, ReplicaStorageBytes,

-- Bytes Stats 3
ArchiveStorageBytes, LastSnapshotLogicalBytes, LocalMeteredDataBytes,

-- Bytes Stats 4
UsedBytes, ProvisionedBytes, LocalProtectedBytes, LocalEffectiveStorageBytes, Exported, URL)
VALUES(
-- Date RSC & Object IDs
'$UTCDateTime', '$RSCInstance', '$ObjectName', '$ObjectID', '$ObjectCDMID', '$ObjectType', '$ObjectLocation',

-- Cluster & SLA info
'$RubrikCluster', '$RubrikClusterID', '$SLADomain', '$SLADomainID', '$OrgName',

-- Retention lock and snapshots
'$SLADomainIsRetentionLocked', '$TotalSnapshots', '$ProtectedOn', '$LastSnapshot', '$PendingFirstFull',

-- Data Reduction
'$DataReduction', '$LogicalDataReduction',

-- GB Stats 1
'$TotalUsedGB', '$PhysicalGB', '$LocalStorageGB', '$TransferredGB',

-- GB Stats 2
'$LogicalGB', '$ReplicaStorageGB', '$ArchiveStorageGB',

-- GB Stats 3
'$LastSnapshotLogicalGB', '$LocalMeteredDataGB',

-- GB Stats 4
'$UsedGB', '$ProvisionedGB', '$LocalProtectedGB', '$LocalEffectiveStorageGB',

-- Bytes Stats 1
'$TotalUsedBytes', '$physicalBytes', '$localStorage',

-- Bytes Stats 2
'$transferredBytes', '$logicalBytes', '$replicaStorage',

-- Bytes Stats 3
'$archiveStorage', '$lastSnapshotLogicalBytes', '$localMeteredData',

-- Bytes Stats 4
'$usedBytes', '$provisionedBytes', '$localProtectedData', '$localEffectiveStorage','FALSE', '$ObjectURL');"
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
-- Date RSC & Object IDs
DateUTC, RSCInstance, Object, ObjectID, ObjectCDMID, Type, Location,

-- Cluster & SLA info
RubrikCluster, RubrikClusterID, SLADomain, SLADomainID,Org,

-- Retention lock and snapshots
SLADomainRetentionLock, TotalSnapshots, ProtectedOn, LastSnapshot, PendingFirstFull,

-- Data Reduction
DataReduction, LogicalDataReduction,

-- GB Stats 1
TotalUsedGB, ProtectedGB, LocalStorageGB, TransferredGB,

-- GB Stats 2
LogicalGB, ReplicaStorageGB, ArchiveStorageGB,

-- GB Stats 3
LastSnapshotLogicalGB, LocalMeteredDataGB,

-- GB Stats 4
UsedGB,ProvisionedGB, LocalProtectedGB, LocalEffectiveStorageGB,

-- Bytes Stats 1
TotalUsedBytes, ProtectedBytes, LocalStorageBytes,

-- Bytes Stats 2
TransferredBytes, LogicalBytes, ReplicaStorageBytes,

-- Bytes Stats 3
ArchiveStorageBytes, LastSnapshotLogicalBytes, LocalMeteredDataBytes,

-- Bytes Stats 4
UsedBytes, ProvisionedBytes, LocalProtectedBytes, LocalEffectiveStorageBytes, Exported, URL)
VALUES(
-- Date RSC & Object IDs
'$UTCDateTime', '$RSCInstance', '$ObjectName', '$ObjectID', '$ObjectCDMID', '$ObjectType', '$ObjectLocation',

-- Cluster & SLA info
'$RubrikCluster', '$RubrikClusterID', '$SLADomain', '$SLADomainID', '$OrgName',

-- Retention lock and snapshots
'$SLADomainIsRetentionLocked', '$TotalSnapshots', '$ProtectedOn', '$LastSnapshot', '$PendingFirstFull',

-- Data Reduction
'$DataReduction', '$LogicalDataReduction',

-- GB Stats 1
'$TotalUsedGB', '$PhysicalGB', '$LocalStorageGB', '$TransferredGB',

-- GB Stats 2
'$LogicalGB', '$ReplicaStorageGB', '$ArchiveStorageGB',

-- GB Stats 3
'$LastSnapshotLogicalGB', '$LocalMeteredDataGB',

-- GB Stats 4
'$UsedGB', '$ProvisionedGB', '$LocalProtectedGB', '$LocalEffectiveStorageGB',

-- Bytes Stats 1
'$TotalUsedBytes', '$physicalBytes', '$localStorage',

-- Bytes Stats 2
'$transferredBytes', '$logicalBytes', '$replicaStorage',

-- Bytes Stats 3
'$archiveStorage', '$lastSnapshotLogicalBytes', '$localMeteredData',

-- Bytes Stats 4
'$usedBytes', '$provisionedBytes', '$localProtectedData', '$localEffectiveStorage', 'FALSE', '$ObjectURL');"
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


#
# End of for each object below
}
# End of for each object above

# Assigning to global array
$Global:RSCObjectStorageUsage = $RSCObjectStorageUsage

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
# Nothing to do, this table is supposed to have multiple entries to track storage usage over time if desired
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
ON (Target.RowID = Source.RowID)
WHEN NOT MATCHED BY TARGET
THEN INSERT (DateUTC, RSCInstance, Object, ObjectID, ObjectCDMID, Type, Location,
            RubrikCluster, RubrikClusterID, SLADomain, SLADomainID, Org,
            SLADomainRetentionLock, TotalSnapshots, ProtectedOn, LastSnapshot, PendingFirstFull,
            DataReduction, LogicalDataReduction, TotalUsedGB,
            ProtectedGB, LocalStorageGB, TransferredGB,
            LogicalGB, ReplicaStorageGB, ArchiveStorageGB,
            LastSnapshotLogicalGB, LocalMeteredDataGB,
            UsedGB, ProvisionedGB, LocalProtectedGB, LocalEffectiveStorageGB,
            TotalUsedBytes, ProtectedBytes, LocalStorageBytes,
            TransferredBytes, LogicalBytes, ReplicaStorageBytes,
            ArchiveStorageBytes, LastSnapshotLogicalBytes, LocalMeteredDataBytes,
            UsedBytes, ProvisionedBytes, LocalProtectedBytes, LocalEffectiveStorageBytes, Exported, URL)
     VALUES (Source.DateUTC, Source.RSCInstance, Source.Object, Source.ObjectID, Source.ObjectCDMID, Source.Type, Source.Location,
            Source.RubrikCluster, Source.RubrikClusterID, Source.SLADomain, Source.SLADomainID, Source.Org,
            Source.SLADomainRetentionLock, Source.TotalSnapshots, Source.ProtectedOn, Source.LastSnapshot, Source.PendingFirstFull,
            Source.DataReduction, Source.LogicalDataReduction, Source.TotalUsedGB,
            Source.ProtectedGB, Source.LocalStorageGB, Source.TransferredGB,
            Source.LogicalGB, Source.ReplicaStorageGB, Source.ArchiveStorageGB,
            Source.LastSnapshotLogicalGB, Source.LocalMeteredDataGB,
            Source.UsedGB, Source.ProvisionedGB, Source.LocalProtectedGB, Source.LocalEffectiveStorageGB,
            Source.TotalUsedBytes, Source.ProtectedBytes, Source.LocalStorageBytes,
            Source.TransferredBytes, Source.LogicalBytes, Source.ReplicaStorageBytes,
            Source.ArchiveStorageBytes, Source.LastSnapshotLogicalBytes, Source.LocalMeteredDataBytes,
            Source.UsedBytes, Source.ProvisionedBytes, Source.LocalProtectedBytes, Source.LocalEffectiveStorageBytes, Source.Exported, Source.URL);"
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
$RSCTotalEventsCount = $RSCEvents | Measure-Object | Select-Object -ExpandProperty Count
$RSCTotalInsertedEventsCount = $RSCEvents | Where-Object {$_.InsertDisabled -eq $FALSE} | Measure-Object | Select-Object -ExpandProperty Count
$ScriptEnd = Get-Date
IF (($ScriptStart -ne $null) -and ($ScriptEnd -ne $null))
{
$Timespan = New-TimeSpan -Start $ScriptStart -End $ScriptEnd
$ScriptDurationSeconds = $Timespan.TotalSeconds
$ScriptDurationSeconds = [Math]::Round($ScriptDurationSeconds)
$ScriptDuration = "{0:}" -f $Timespan;$ScriptDuration = $ScriptDuration.Substring(0,8)
}
ELSE
{
$ScriptDuration = 0
}
# Calculating seconds per event
IF($RSCEventsCount -gt 0){$SecondsPerEvent = $ScriptDurationSeconds/$RSCTotalEventsCount;$SecondsPerEvent=[Math]::Round($SecondsPerEvent,2)}ELSE{$SecondsPerEvent=0}
# Logging
Write-Host "Script Execution Summary
----------------------------------
Start: $ScriptStart
End: $ScriptEnd
CollectedEventsFrom: $TimeRange
TotalEvents: $RSCTotalEventsCount
Runtime: $ScriptDuration
SecondsPerEvent: $SecondsPerEvent"
# Returning null
Return $null
# End of function
}
