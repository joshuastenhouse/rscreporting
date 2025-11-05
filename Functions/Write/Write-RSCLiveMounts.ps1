################################################
# Function - Write-RSCLiveMounts - Getting all active live mounts in RSC and writing them to a SQL database table
################################################
Function Write-RSCLiveMounts {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for writing RSC live mount data into a MSSQL DB/Table of your choosing.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.PARAMETER SQLInstance
The SQL server and instance name (if required) to connect to your MS SQL server. Ensure the user running the script has permission to connect, recommended to check using MS SQL Mgmt Studio first.
.PARAMETER SQLDB
The SQL database in which to create the required table to write the events. This must already exist, it will not create the database for you.
.PARAMETER SQLTable
Not required, it will create a table for you, but you can customize the name (not the structure). Has to not already exist on 1st run unless you already used the correct structure. 
.PARAMETER DontUseTempDB
Switch to disable use of TempDB for scale. Use if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.
.PARAMETER DropExistingRows
Drops all existing rows in the table specified, otherwise it just uses a new datetime on each run (so you can either just maintain the latest, or over time on a frequency you desire).

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
None, all the events are written into the MS SQL DB specified.

.EXAMPLE
Write-RSCLiveMounts -SQLInstance "localhost" -SQLDB "YourDBName"
This example gets all object storage usage, creates a table called RSCObjectStorageUsage with the required structure then populates it with the API data.

.EXAMPLE
Write-RSCLiveMounts -SQLInstance "localhost" -SQLDB "YourDBName" -DontUseTempDB
This example does the same as above, but doesn't use TempDB (if you have permissions issues with creating tables in it and aren't concerned about locks).

.EXAMPLE
Write-RSCLiveMounts -SQLInstance "localhost" -SQLDB "YourDBName" -SQLTable "YourTableName" 
This example gets all object storage usage, creates a table using the name specified with the required structure then populates it with the API data.

.NOTES
Author: Joshua Stenhouse
Date: 11/04/2025
#>

################################################
# Paramater Config
################################################
	Param
    (
        [Parameter(Mandatory=$true)]$SQLInstance,
		[Parameter(Mandatory=$true)]$SQLDB,
        [Parameter(Mandatory=$false)]$SQLTable,
        [switch]$DropExistingRows,
        [switch]$DontUseTempDB,
        [switch]$DisablePerMountLogging
    )
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
# Override to always select sqlserver if present to prevent conflict bug as of 11/04/25
IF($PSModules -match "SqlServer"){$SQLModuleName = "SqlServer"}
# Checking to see if SQL Server module is loaded
$SQLModuleCheck = Get-Module -Name $SQLModuleName
# If SQL module not found in current session importing
IF($SQLModuleCheck -eq $null){Import-Module $SQLModuleName -ErrorAction SilentlyContinue}
##########################
# SQL - Checking Table Exists
##########################
# Manually setting SQL table name if not specified
IF($SQLTable -eq $null){$SQLTable = "RSCLiveMounts"}
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
	[RSCInstance] [varchar](max) NULL,
    [LiveMountID] [varchar](max) NULL,
    [Type] [varchar](max) NULL,
	[Object] [varchar](max) NULL,
    [SourceObject] [varchar](max) NULL,
	[SourceObjectID] [varchar](max) NULL,
    [Snapshot] [datetime] NULL,
    [Status] [varchar](50) NULL,
    [IsReady] [varchar](50) NULL,
    [MountPath] [varchar](max) NULL,
	[MountTimeUTC] [datetime] NULL,
    [Duration] [varchar](50) NULL,
    [TotalDays] [int] NULL,
    [TotalHours] [int] NULL,
    [TotalMinutes] [int] NULL,
	[TargetHost] [varchar](max) NULL,
    [TargetHostID] [varchar](max) NULL,
	[RubrikCluster] [varchar](max) NULL,
	[RubrikClusterID] [varchar](max) NULL,
    [LastUpdated] [datetime] NULL,
    [IsRelic] [varchar](50) NULL,
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
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting Live Mounts
################################################
Write-Host "Running: Get-RSCLiveMounts
----------------------------------"
# Getting mounts
$RSCLiveMounts = Get-RSCLiveMounts
# Removing any entries without a livemount ID
$RSCLiveMounts = $RSCLiveMounts | Where-Object {$_.LiveMountID -ne $null}
################################################
# Processing All Objects 
################################################
# Creating array
$RSCObjects = [System.Collections.ArrayList]@()
# Counting
$RSCObjectsCount = $RSCLiveMounts | Measure-Object | Select-Object -ExpandProperty Count
$RSCObjectsCounter = 0
# Getting current time for last snapshot age
$UTCDateTime = [System.DateTime]::UtcNow
# Processing
ForEach ($LiveMount in $RSCLiveMounts)
{
# Logging
$RSCObjectsCounter ++
IF($DisablePerMountLogging){}ELSE{Write-Host "ProcessingLiveMount: $RSCObjectsCounter/$RSCObjectsCount"}
# Setting variables
$LiveMountID = $LiveMount.LiveMountID
$Type = $LiveMount.Type
$Object = $LiveMount.Object
$SourceObject = $LiveMount.SourceObject
$SourceObjectID = $LiveMount.SourceObjectID
$Snapshot = $LiveMount.Snapshot
$Status = $LiveMount.Status
$IsReady = $LiveMount.IsReady
$Mountpath = $LiveMount.MountPath
$MountTimeUTC = $LiveMount.MountTimeUTC
$Duration = $LiveMount.Duration
$TotalDays = $LiveMount.TotalDays
$TotalHours = $LiveMount.TotalHours
$TotalMinutes = $LiveMount.TotalMinutes
$TargetHost = $LiveMount.Host
$TargetHostID = $LiveMount.HostID
$RubrikCluster = $LiveMount.RubrikCluster
$RubrikClusterID = $LiveMount.RubrikClusterID
$URL = $LiveMount.URL
############################
# Adding To SQL Table directly if no tempDB
############################
IF($DontUseTempDB)
{
$SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
-- RSC & Object IDs
RSCInstance,LiveMountID,Type,Object,SourceObject,SourceObjectID,

-- Live mount data
Snapshot,Status,IsReady,MountPath,MountTimeUTC,

-- Timing
Duration,TotalDays,TotalHours,TotalMinutes,

-- Target & Cluster
TargetHost,TargetHostID,RubrikCluster,RubrikClusterID,

-- Closing data
LastUpdated,IsRelic,URL)
VALUES(
-- RSC & Object IDs
'$RSCInstance', '$LiveMountID', '$Type','$Object','$SourceObject','$SourceObjectID',

-- Live mount data
'$Snapshot','$Status','$IsReady','$Mountpath','$MountTimeUTC',

-- Timing
'$Duration','$TotalDays','$TotalHours','$TotalMinutes',

-- Target & Cluster
'$TargetHost','$TargetHostID','$RubrikCluster','$RubrikClusterID',

-- Closing data
'$UTCDateTime','FALSE','$URL');"
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
-- RSC & Object IDs
RSCInstance,LiveMountID,Type,Object,SourceObject,SourceObjectID,

-- Live mount data
Snapshot,Status,IsReady,MountPath,MountTimeUTC,

-- Timing
Duration,TotalDays,TotalHours,TotalMinutes,

-- Target & Cluster
TargetHost,TargetHostID,RubrikCluster,RubrikClusterID,

-- Closing data
LastUpdated,IsRelic,URL)
VALUES(
-- RSC & Object IDs
'$RSCInstance', '$LiveMountID', '$Type','$Object','$SourceObject','$SourceObjectID',

-- Live mount data
'$Snapshot','$Status','$IsReady','$Mountpath','$MountTimeUTC',

-- Timing
'$Duration','$TotalDays','$TotalHours','$TotalMinutes',

-- Target & Cluster
'$TargetHost','$TargetHostID','$RubrikCluster','$RubrikClusterID',

-- Closing data
'$UTCDateTime','FALSE','$URL');"
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
# End of for each live mount below
}
# End of for each live mount above

##################################
# Finishing SQL Work
##################################
Write-Host "----------------------------------
Finished Processing RSC Live Mounts
----------------------------------"
############################
# Removing Duplicates if not using TempDB
############################
IF($DontUseTempDB)
{
# Nothing to do, this table is supposed to have multiple entries
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
ON (Target.LiveMountID = Source.LiveMountID)
WHEN MATCHED 
     THEN UPDATE
     SET    Target.RSCInstance = Source.RSCInstance,
            Target.Type = Source.Type,
            Target.Object = Source.Object,
            Target.SourceObject = Source.SourceObject,
            Target.SourceObjectID = Source.SourceObjectID,
            Target.Snapshot = Source.Snapshot,
            Target.Status = Source.Status,
            Target.IsReady = Source.IsReady,
            Target.MountPath = Source.MountPath,
            Target.MountTimeUTC = Source.MountTimeUTC,
            Target.Duration = Source.Duration,
            Target.TotalDays = Source.TotalDays,
            Target.TotalHours = Source.TotalHours,
            Target.TotalMinutes = Source.TotalMinutes,
            Target.TargetHost = Source.TargetHost,
            Target.TargetHostID = Source.TargetHostID,
            Target.RubrikCluster = Source.RubrikCluster,
            Target.RubrikClusterID = Source.RubrikClusterID,
            Target.LastUpdated = Source.LastUpdated,
            Target.IsRelic = Source.IsRelic,
            Target.URL = Source.URL
WHEN NOT MATCHED BY TARGET
THEN INSERT (RSCInstance,LiveMountID,Type,Object,SourceObject,SourceObjectID,
            Snapshot,Status,IsReady,MountPath,MountTimeUTC,
            Duration,TotalDays,TotalHours,TotalMinutes,
            TargetHost,TargetHostID,RubrikCluster,RubrikClusterID,
            LastUpdated,IsRelic,URL)
     VALUES (Source.RSCInstance,Source.LiveMountID,Source.Type,Source.Object,Source.SourceObject,Source.SourceObjectID,
            Source.Snapshot,Source.Status,Source.IsReady,Source.MountPath,Source.MountTimeUTC,
            Source.Duration,Source.TotalDays,Source.TotalHours,Source.TotalMinutes,
            Source.TargetHost,Source.TargetHostID,Source.RubrikCluster,Source.RubrikClusterID,
            Source.LastUpdated,Source.IsRelic,Source.URL);"
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
Write-Host "UpdatingRelics: $SQLTable"
Start-Sleep 3
# Creating SQL query
$SQLUpdateRelics = "USE $SQLDB
UPDATE $SQLTable
SET IsRelic = 'TRUE'
FROM $SQLTable target
LEFT JOIN tempdb.dbo.$TempTableName source
  ON target.LiveMountID = source.LiveMountID
WHERE source.LiveMountID IS NULL;"
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
# Logging
Write-Host "Script Execution Summary
----------------------------------
Start: $ScriptStart
End: $ScriptEnd
TotalObjects: $RSCObjectsCount
Runtime: $ScriptDuration"
# Returning null
Return $null
# End of function
}