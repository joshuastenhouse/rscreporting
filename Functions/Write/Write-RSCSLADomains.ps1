################################################
# Function - Write-RSCSLADomains - Getting all SLA domains visible to the RSC instance and writing them to a SQL database table
################################################
Function Write-RSCSLADomains {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for writing RSC Objects data into a MSSQL DB/Table of your choosing.

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

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
None, all the events are written into the MS SQL DB specified.

.EXAMPLE
Write-RSCSLADomains -SQLInstance "localhost" -SQLDB "YourDBName"
This example gets all object storage usage, creates a table called RSCObjectStorageUsage with the required structure then populates it with the API data.

.EXAMPLE
Write-RSCSLADomains -SQLInstance "localhost" -SQLDB "YourDBName" -DontUseTempDB
This example does the same as above, but doesn't use TempDB (if you have permissions issues with creating tables in it and aren't concerned about locks).

.EXAMPLE
Write-RSCSLADomains -SQLInstance "localhost" -SQLDB "YourDBName" -SQLTable "YourTableName" 
This example gets all object storage usage, creates a table using the name specified with the required structure then populates it with the API data.

.NOTES
Author: Joshua Stenhouse
Date: 10/16/2024
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
        [switch]$DisableLogging,
        [switch]$DebugWrites
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
# Checking to see if SQL Server module is loaded
$SQLModuleCheck = Get-Module $SQLModuleName
# If SQL module not found in current session importing
IF($SQLModuleCheck -eq $null){Import-Module $SQLModuleName -ErrorAction SilentlyContinue}
##########################
# SQL - Checking Table Exists
##########################
# Manually setting SQL table name if not specified
IF($SQLTable -eq $null){$SQLTable = "RSCSLADomains"}
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
	[SLADomain] [varchar](max) NULL,
	[SLADomainID] [varchar](max) NULL,
    [SLADomainDescription] [varchar](max) NULL,
	[ProtectedObjects] [int] NULL,
	[TotalObjectTypes] [int] NULL,
    [ObjectTypes] [varchar](max) NULL,
    [RetentionLocked] [varchar](50) NULL,
    [ArchiveEnabled] [varchar](50) NULL,
    [ArchiveTarget] [varchar](max) NULL,
    [ArchiveName] [varchar](max) NULL,
    [ArchiveType] [varchar](50) NULL,
    [ArchiveID] [varchar](max) NULL,
    [ReplicationEnabled] [varchar](50) NULL,
    [ReplicationDuration] [int] NULL,
    [ReplicationUnit] [varchar](50) NULL,
    [ReplicationTargetCluster] [varchar](max) NULL,
    [ReplicationTargetClusterID] [varchar](max) NULL,
    [LocalRetention] [int] NULL,
    [LocalRetentionUnit] [varchar](50) NULL,
    [Frequency] [int] NULL,
    [FrequencyUnit] [varchar](50) NULL,
    [FrequencyHours] [int] NULL,
    [FrequencyDays] [int] NULL,
    [HourlyFrequency] [int] NULL,
	[HourlyRetention] [int] NULL,
	[DailyFrequency] [int] NULL,
	[DailyRetention] [int] NULL,
	[WeeklyFrequency] [int] NULL,
	[WeeklyRetention] [int] NULL,
	[MonthlyFrequency] [int] NULL,
	[MonthlyRetention] [int] NULL,
	[QuarterlyFrequency] [int] NULL,
	[QuarterlyRetention] [int] NULL,
	[YearlyFrequency] [int] NULL,
	[YearlyRetention] [int] NULL,
    [VMJournalConfigured] [varchar](50) NULL,
    [VMJournalRetention] [int] NULL,
    [VMJournalRetentionUnit] [varchar](50) NULL,
    [MSSQLConfigured] [varchar](50) NULL,
    [MSSQLLogFrequency] [int] NULL,
    [MSSQLLogFrequencyUnit] [varchar](50) NULL,
    [MSSQLLogRetention] [int] NULL,
    [MSSQLLogRetentionUnit] [varchar](50) NULL,
    [OracleConfigured] [varchar](50) NULL,
    [OracleLogFrequency] [int] NULL,
    [OracleLogFrequencyUnit] [varchar](50) NULL,
    [OracleLogRetention] [int] NULL,
    [OracleLogRetentionUnit] [varchar](50) NULL,
    [SAPConfigured] [varchar](50) NULL,
    [SAPIncrementalFrequency] [int] NULL,
    [SAPIncrementalFrequencyUnit] [varchar](50) NULL,
    [SAPDifferentialFrequency] [int] NULL,
    [SAPDifferentialFrequencyUnit] [varchar](50) NULL,
    [SAPLogRetention] [int] NULL,
    [SAPLogRetentionUnit] [varchar](50) NULL,
    [DB2Configured] [varchar](50) NULL,
    [DB2IncrementalFrequency] [int] NULL,
    [DB2IncrementalFrequencyUnit] [varchar](50) NULL,
    [DB2DifferentialFrequency] [int] NULL,
    [DB2DifferentialFrequencyUnit] [varchar](50) NULL,
    [DB2LogRetention] [int] NULL,
    [DB2LogRetentionUnit] [varchar](50) NULL,
    [AWSRDSConfigured] [varchar](50) NULL,
    [AWSRDSLogRetention] [int] NULL,
    [AWSRDSLogRetentionUnit] [varchar](50) NULL,
    [AzureSQLMIConfigured] [varchar](50) NULL,
    [AzureSQLMILogRetention] [int] NULL,
    [AzureSQLMILogRetentionUnit] [varchar](50) NULL,
    [AzureSQLDBConfigured] [varchar](50) NULL,
    [AzureSQLDBLogRetention] [int] NULL,
    [AzureSQLDBLogRetentionUnit] [varchar](50) NULL,
    [URL] [varchar](max) NULL,
	[IsRelic] [varchar](5) NULL,
	[LastUpdated] [datetime] NULL
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
# Getting RSC SLA Domains
Write-Host "QueryingSLADomains.."
$RSCSLADomains = Get-RSCSLADomains
$RSCSLADomainCount = $RSCSLADomains | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "SLADomainsFound: $RSCSLADomainCount"
# Logging
# IF($DisableLogging){}ELSE{Write-Host "GettingObjects: $ObjectCount-$ObjectCounter"}
################################################
# Processing SLA Domains
################################################
$RSCSLADomainCounter = 0
# Getting current time for last snapshot age
$UTCDateTime = [System.DateTime]::UtcNow
# Processing
ForEach ($RSCObject in $RSCSLADomains)
{
# Logging
$RSCSLADomainCounter ++
IF($DisableLogging){}ELSE{Write-Host "ProcessingSLADomain: $RSCSLADomainCounter/$RSCSLADomainCount"}
# Setting variables
$RSCInstance = $RSCObject.RSCInstance
$SLADomain = $RSCObject.SLADomain
$SLADomainID = $RSCObject.SLADomainID
$SLADomainDescription = $RSCObject.Description
$ProtectedObjects = $RSCObject.ProtectedObjects
$TotalObjectTypes = $RSCObject.TotalObjectTypes
$ObjectTypes = $RSCObject.ObjectTypes
$RetentionLocked = $RSCObject.RetentionLocked
$ArchiveEnabled = $RSCObject.Archive
$ArchiveTarget = $RSCObject.ArchiveTarget
$ArchiveName = $RSCObject.ArchiveName
$ArchiveType = $RSCObject.ArchiveType
$ArchiveID = $RSCObject.ArchiveID
$ReplicationEnabled = $RSCObject.Replication
$ReplicationDuration = $RSCObject.ReplicationDuration
$ReplicationUnit = $RSCObject.ReplicationUnit
$ReplicationTargetCluster = $RSCObject.ReplicationTargetCluster
$ReplicationTargetClusterID = $RSCObject.ReplicationTargetClusterID
$LocalRetention = $RSCObject.LocalRetention
$LocalRetentionUnit = $RSCObject.LocalRetentionUnit
$Frequency = $RSCObject.Frequency
$FrequnecyUnit = $RSCObject.FrequnecyUnit
$FrequencyHours = $RSCObject.FrequencyHours
$FrequencyDays = $RSCObject.FrequencyDays
$HourlyFrequency = $RSCObject.HourlyFrequency
$HourlyRetention = $RSCObject.HourlyRetention
$DailyFrequency = $RSCObject.DailyFrequency
$DailyRetention = $RSCObject.DailyRetention
$WeeklyFrequency = $RSCObject.WeeklyFrequency
$WeeklyRetention = $RSCObject.WeeklyRetention
$MonthlyFrequency = $RSCObject.MonthlyFrequency
$MonthlyRetention = $RSCObject.MonthlyRetention
$QuarterlyFrequency = $RSCObject.QuarterlyFrequency
$QuarterlyRetention = $RSCObject.QuarterlyRetention
$YearlyFrequency = $RSCObject.YearlyFrequency
$YearlyRetention = $RSCObject.YearlyRetention
$VMJournalConfigured = $RSCObject.VMJournalConfigured
$VMJournalRetention = $RSCObject.VMJournalRetention
$VMJournalRetentionUnit = $RSCObject.VMJournalRetentionUnit
$MSSQLConfigured = $RSCObject.MSSQLConfigured
$MSSQLLogFrequency = $RSCObject.MSSQLLogFrequency
$MSSQLLogFrequencyUnit = $RSCObject.MSSQLLogFrequencyUnit
$MSSQLLogRetention = $RSCObject.MSSQLLogRetention
$MSSQLLogRetentionUnit = $RSCObject.MSSQLLogRetentionUnit
$OracleConfigured = $RSCObject.OracleConfigured
$OracleLogFrequency = $RSCObject.OracleLogFrequency
$OracleLogFrequencyUnit = $RSCObject.OracleLogFrequencyUnit
$OracleLogRetention = $RSCObject.OracleLogRetention
$OracleLogRetentionUnit = $RSCObject.OracleLogRetentionUnit
$SAPConfigured = $RSCObject.SAPConfigured
$SAPIncrementalFrequency = $RSCObject.SAPIncrementalFrequency
$SAPIncrementalFrequencyUnit = $RSCObject.SAPIncrementalFrequencyUnit
$SAPDifferentialFrequency = $RSCObject.SAPDifferentialFrequency
$SAPDifferentialFrequencyUnit = $RSCObject.SAPDifferentialFrequencyUnit
$SAPLogRetention = $RSCObject.SAPLogRetention
$SAPLogRetentionUnit = $RSCObject.SAPLogRetentionUnit
$DB2Configured = $RSCObject.DB2Configured
$DB2IncrementalFrequency = $RSCObject.DB2IncrementalFrequency
$DB2IncrementalFrequencyUnit = $RSCObject.DB2IncrementalFrequencyUnit
$DB2DifferentialFrequency = $RSCObject.DB2DifferentialFrequency
$DB2DifferentialFrequencyUnit = $RSCObject.DB2DifferentialFrequencyUnit
$DB2LogRetention = $RSCObject.DB2LogRetention
$DB2LogRetentionUnit = $RSCObject.DB2LogRetentionUnit
$AWSRDSConfigured = $RSCObject.AWSRDSConfigured
$AWSRDSLogRetention = $RSCObject.AWSRDSLogRetention
$AWSRDSLogRetentionUnit = $RSCObject.AWSRDSLogRetentionUnit
$AzureSQLMIConfigured = $RSCObject.AzureSQLMIConfigured
$AzureSQLMILogRetention = $RSCObject.AzureSQLMILogRetention
$AzureSQLMILogRetentionUnit = $RSCObject.AzureSQLMILogRetentionUnit
$AzureSQLDBConfigured = $RSCObject.AzureSQLDBConfigured
$AzureSQLDBLogRetention = $RSCObject.AzureSQLDBLogRetention
$AzureSQLDBLogRetentionUnit = $RSCObject.AzureSQLDBLogRetentionUnit
$URL = $RSCObject.URL
$LastUpdated = "{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date)
############################
# Adding To SQL Table directly if no tempDB
############################
IF($DontUseTempDB)
{
$SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
RSCInstance, SLADomain, SLADomainID, SLADomainDescription,
ProtectedObjects, TotalObjectTypes, ObjectTypes, RetentionLocked,
ArchiveEnabled, ArchiveTarget, ArchiveName, ArchiveType, ArchiveID, 
ReplicationEnabled, ReplicationDuration, ReplicationUnit, ReplicationTargetCluster, ReplicationTargetClusterID, 
LocalRetention, LocalRetentionUnit, Frequency, FrequencyUnit, FrequencyHours, FrequencyDays, 
HourlyFrequency, HourlyRetention, DailyFrequency, DailyRetention, WeeklyFrequency, WeeklyRetention, 
MonthlyFrequency, MonthlyRetention, QuarterlyFrequency, QuarterlyRetention, YearlyFrequency, YearlyRetention, 
VMJournalConfigured, VMJournalRetention, VMJournalRetentionUnit, 
MSSQLConfigured, MSSQLLogFrequency, MSSQLLogFrequencyUnit, MSSQLLogRetention, MSSQLLogRetentionUnit, 
OracleConfigured, OracleLogFrequency, OracleLogFrequencyUnit, OracleLogRetention, OracleLogRetentionUnit, 
SAPConfigured, SAPIncrementalFrequency, SAPIncrementalFrequencyUnit, SAPDifferentialFrequency, SAPDifferentialFrequencyUnit, SAPLogRetention, SAPLogRetentionUnit,
DB2Configured, DB2IncrementalFrequency, DB2IncrementalFrequencyUnit, DB2DifferentialFrequency, DB2DifferentialFrequencyUnit , DB2LogRetention, DB2LogRetentionUnit,
AWSRDSConfigured, AWSRDSLogRetention, AWSRDSLogRetentionUnit, 
AzureSQLMIConfigured , AzureSQLMILogRetention, AzureSQLMILogRetentionUnit, AzureSQLDBConfigured, AzureSQLDBLogRetention, AzureSQLDBLogRetentionUnit, 
URL, IsRelic, LastUpdated)
VALUES(
'$RSCInstance', '$SLADomain', '$SLADomainID', '$SLADomainDescription',
'$ProtectedObjects', '$TotalObjectTypes', '$ObjectTypes', '$RetentionLocked',
'$ArchiveEnabled', '$ArchiveTarget', '$ArchiveName', '$ArchiveType', '$ArchiveID', 
'$ReplicationEnabled', '$ReplicationDuration', '$ReplicationUnit', '$ReplicationTargetCluster', '$ReplicationTargetClusterID', 
'$LocalRetention', '$LocalRetentionUnit', '$Frequency', '$FrequencyUnit', '$FrequencyHours', '$FrequencyDays', 
'$HourlyFrequency', '$HourlyRetention', '$DailyFrequency', '$DailyRetention', '$WeeklyFrequency', ' $WeeklyRetention', 
'$MonthlyFrequency', '$MonthlyRetention', '$QuarterlyFrequency', '$QuarterlyRetention', '$YearlyFrequency', '$YearlyRetention', 
'$VMJournalConfigured', '$VMJournalRetention', '$VMJournalRetentionUnit', 
'$MSSQLConfigured', '$MSSQLLogFrequency', '$MSSQLLogFrequencyUnit', '$MSSQLLogRetention', '$MSSQLLogRetentionUnit', 
'$OracleConfigured', '$OracleLogFrequency', '$OracleLogFrequencyUnit', '$OracleLogRetention', '$OracleLogRetentionUnit', 
'$SAPConfigured', '$SAPIncrementalFrequency', '$SAPIncrementalFrequencyUnit', '$SAPDifferentialFrequency', '$SAPDifferentialFrequencyUnit', '$SAPLogRetention', '$SAPLogRetentionUnit',
'$DB2Configured', '$DB2IncrementalFrequency', '$DB2IncrementalFrequencyUnit', '$DB2DifferentialFrequency', '$DB2DifferentialFrequencyUnit', '$DB2LogRetention', '$DB2LogRetentionUnit',
'$AWSRDSConfigured', '$AWSRDSLogRetention', '$AWSRDSLogRetentionUnit', 
'$AzureSQLMIConfigured', '$AzureSQLMILogRetention', '$AzureSQLMILogRetentionUnit', '$AzureSQLDBConfigured', '$AzureSQLDBLogRetention', '$AzureSQLDBLogRetentionUnit', 
'$URL', '$FALSE', '$LastUpdated');"
# Inserting if SLA Domain not null
IF($SLADomainID -ne $null)
{
Try
{
Invoke-SQLCmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
}
}
ELSE
{
############################
# Adding To SQL temp table
############################
$SQLInsert = "USE tempdb
INSERT INTO $TempTableName (
RSCInstance, SLADomain, SLADomainID, SLADomainDescription,
ProtectedObjects, TotalObjectTypes, ObjectTypes, RetentionLocked,
ArchiveEnabled, ArchiveTarget, ArchiveName, ArchiveType, ArchiveID, 
ReplicationEnabled, ReplicationDuration, ReplicationUnit, ReplicationTargetCluster, ReplicationTargetClusterID, 
LocalRetention, LocalRetentionUnit, Frequency, FrequencyUnit, FrequencyHours, FrequencyDays, 
HourlyFrequency, HourlyRetention, DailyFrequency, DailyRetention, WeeklyFrequency, WeeklyRetention, 
MonthlyFrequency, MonthlyRetention, QuarterlyFrequency, QuarterlyRetention, YearlyFrequency, YearlyRetention, 
VMJournalConfigured, VMJournalRetention, VMJournalRetentionUnit, 
MSSQLConfigured, MSSQLLogFrequency, MSSQLLogFrequencyUnit, MSSQLLogRetention, MSSQLLogRetentionUnit, 
OracleConfigured, OracleLogFrequency, OracleLogFrequencyUnit, OracleLogRetention, OracleLogRetentionUnit, 
SAPConfigured, SAPIncrementalFrequency, SAPIncrementalFrequencyUnit, SAPDifferentialFrequency, SAPDifferentialFrequencyUnit, SAPLogRetention, SAPLogRetentionUnit,
DB2Configured, DB2IncrementalFrequency, DB2IncrementalFrequencyUnit, DB2DifferentialFrequency, DB2DifferentialFrequencyUnit , DB2LogRetention, DB2LogRetentionUnit,
AWSRDSConfigured, AWSRDSLogRetention, AWSRDSLogRetentionUnit, 
AzureSQLMIConfigured , AzureSQLMILogRetention, AzureSQLMILogRetentionUnit, AzureSQLDBConfigured, AzureSQLDBLogRetention, AzureSQLDBLogRetentionUnit, 
URL, IsRelic, LastUpdated)
VALUES(
'$RSCInstance', '$SLADomain', '$SLADomainID', '$SLADomainDescription',
'$ProtectedObjects', '$TotalObjectTypes', '$ObjectTypes', '$RetentionLocked',
'$ArchiveEnabled', '$ArchiveTarget', '$ArchiveName', '$ArchiveType', '$ArchiveID', 
'$ReplicationEnabled', '$ReplicationDuration', '$ReplicationUnit', '$ReplicationTargetCluster', '$ReplicationTargetClusterID', 
'$LocalRetention', '$LocalRetentionUnit', '$Frequency', '$FrequencyUnit', '$FrequencyHours', '$FrequencyDays', 
'$HourlyFrequency', '$HourlyRetention', '$DailyFrequency', '$DailyRetention', '$WeeklyFrequency', ' $WeeklyRetention', 
'$MonthlyFrequency', '$MonthlyRetention', '$QuarterlyFrequency', '$QuarterlyRetention', '$YearlyFrequency', '$YearlyRetention', 
'$VMJournalConfigured', '$VMJournalRetention', '$VMJournalRetentionUnit', 
'$MSSQLConfigured', '$MSSQLLogFrequency', '$MSSQLLogFrequencyUnit', '$MSSQLLogRetention', '$MSSQLLogRetentionUnit', 
'$OracleConfigured', '$OracleLogFrequency', '$OracleLogFrequencyUnit', '$OracleLogRetention', '$OracleLogRetentionUnit', 
'$SAPConfigured', '$SAPIncrementalFrequency', '$SAPIncrementalFrequencyUnit', '$SAPDifferentialFrequency', '$SAPDifferentialFrequencyUnit', '$SAPLogRetention', '$SAPLogRetentionUnit',
'$DB2Configured', '$DB2IncrementalFrequency', '$DB2IncrementalFrequencyUnit', '$DB2DifferentialFrequency', '$DB2DifferentialFrequencyUnit', '$DB2LogRetention', '$DB2LogRetentionUnit',
'$AWSRDSConfigured', '$AWSRDSLogRetention', '$AWSRDSLogRetentionUnit', 
'$AzureSQLMIConfigured', '$AzureSQLMILogRetention', '$AzureSQLMILogRetentionUnit', '$AzureSQLDBConfigured', '$AzureSQLDBLogRetention', '$AzureSQLDBLogRetentionUnit', 
'$URL', '$FALSE', '$LastUpdated');"
# Inserting if SLA Domain not null
IF($SLADomainID -ne $null)
{
Try
{
Invoke-SQLCmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
}
# End of bypass for using tempdb below
}
# End of bypass for using tempdb above
#
############################
# Debug SQL Insert
############################
IF($DebugWrites){Write-Host $SQLInsert}
# End of for each object below
}
# End of for each object above

##################################
# Finishing SQL Work
##################################
# Logging
Write-Host "----------------------------------
Finished Processing RSC SLA Domains
----------------------------------"
############################
# Removing Duplicates if not using TempDB
############################
IF($DontUseTempDB)
{
# Nothing to do
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
ON (Target.SLADomainID = Source.SLADomainID)
WHEN MATCHED 
     THEN UPDATE
     SET    Target.RSCInstance = Source.RSCInstance,
            Target.SLADomain = Source.SLADomain,
            Target.SLADomainID = Source.SLADomainID,
            Target.SLADomainDescription = Source.SLADomainDescription,
            Target.ProtectedObjects = Source.ProtectedObjects,
            Target.TotalObjectTypes = Source.TotalObjectTypes,
            Target.ObjectTypes = Source.ObjectTypes,
            Target.RetentionLocked = Source.RetentionLocked,
            Target.ArchiveEnabled = Source.ArchiveEnabled,
            Target.ArchiveTarget = Source.ArchiveTarget,
            Target.ArchiveName = Source.ArchiveName,
            Target.ArchiveType = Source.ArchiveType,
            Target.ArchiveID = Source.ArchiveID,
            Target.ReplicationEnabled = Source.ReplicationEnabled,
            Target.ReplicationDuration = Source.ReplicationDuration,
            Target.ReplicationUnit = Source.ReplicationUnit,
            Target.ReplicationTargetCluster = Source.ReplicationTargetCluster,
            Target.ReplicationTargetClusterID = Source.ReplicationTargetClusterID,
            Target.LocalRetention = Source.LocalRetention,
            Target.LocalRetentionUnit = Source.LocalRetentionUnit,
            Target.Frequency = Source.Frequency,
            Target.FrequencyUnit = Source.FrequencyUnit,
            Target.FrequencyHours = Source.FrequencyHours,
            Target.FrequencyDays = Source.FrequencyDays,
            Target.HourlyFrequency = Source.HourlyFrequency,
            Target.HourlyRetention = Source.HourlyRetention,
            Target.DailyFrequency = Source.DailyFrequency,
            Target.DailyRetention = Source.DailyRetention,
            Target.WeeklyFrequency = Source.WeeklyFrequency,
            Target.WeeklyRetention = Source.WeeklyRetention,
            Target.MonthlyFrequency = Source.MonthlyFrequency,
            Target.MonthlyRetention = Source.MonthlyRetention,
            Target.QuarterlyFrequency = Source.QuarterlyFrequency,
            Target.QuarterlyRetention = Source.QuarterlyRetention,
            Target.YearlyFrequency = Source.YearlyFrequency,
            Target.YearlyRetention = Source.YearlyRetention,
            Target.VMJournalConfigured = Source.VMJournalConfigured,
            Target.VMJournalRetention = Source.VMJournalRetention,
            Target.VMJournalRetentionUnit = Source.VMJournalRetentionUnit,
            Target.MSSQLConfigured = Source.MSSQLConfigured,
            Target.MSSQLLogFrequency = Source.MSSQLLogFrequency,
            Target.MSSQLLogFrequencyUnit = Source.MSSQLLogFrequencyUnit,
            Target.MSSQLLogRetention = Source.MSSQLLogRetention,
            Target.MSSQLLogRetentionUnit = Source.MSSQLLogRetentionUnit,
            Target.OracleConfigured = Source.OracleConfigured,
            Target.OracleLogFrequency = Source.OracleLogFrequency,
            Target.OracleLogFrequencyUnit = Source.OracleLogFrequencyUnit,
            Target.OracleLogRetention = Source.OracleLogRetention,
            Target.OracleLogRetentionUnit = Source.OracleLogRetentionUnit,
            Target.SAPConfigured = Source.SAPConfigured,
            Target.SAPIncrementalFrequency = Source.SAPIncrementalFrequency,
            Target.SAPIncrementalFrequencyUnit = Source.SAPIncrementalFrequencyUnit,
            Target.SAPDifferentialFrequency = Source.SAPDifferentialFrequency,
            Target.SAPDifferentialFrequencyUnit = Source.SAPDifferentialFrequencyUnit,
            Target.SAPLogRetention = Source.SAPLogRetention,
            Target.SAPLogRetentionUnit = Source.SAPLogRetentionUnit,
            Target.DB2Configured = Source.DB2Configured,
            Target.DB2IncrementalFrequency = Source.DB2IncrementalFrequency,
            Target.DB2IncrementalFrequencyUnit = Source.DB2IncrementalFrequencyUnit,
            Target.DB2DifferentialFrequency = Source.DB2DifferentialFrequency,
            Target.DB2DifferentialFrequencyUnit  = Source.DB2DifferentialFrequencyUnit,
            Target.DB2LogRetention = Source.DB2LogRetention,
            Target.DB2LogRetentionUnit = Source.DB2LogRetentionUnit,
            Target.AWSRDSConfigured = Source.AWSRDSConfigured,
            Target.AWSRDSLogRetention = Source.AWSRDSLogRetention,
            Target.AWSRDSLogRetentionUnit = Source.AWSRDSLogRetentionUnit,
            Target.AzureSQLMIConfigured = Source.AzureSQLMIConfigured,
            Target.AzureSQLMILogRetention = Source.AzureSQLMILogRetention,
            Target.AzureSQLMILogRetentionUnit = Source.AzureSQLMILogRetentionUnit,
            Target.AzureSQLDBConfigured = Source.AzureSQLDBConfigured,
            Target.AzureSQLDBLogRetention = Source.AzureSQLDBLogRetention,
            Target.AzureSQLDBLogRetentionUnit = Source.AzureSQLDBLogRetentionUnit,
            Target.URL = Source.URL,
            Target.IsRelic = Source.IsRelic,
            Target.LastUpdated = Source.LastUpdated
WHEN NOT MATCHED BY TARGET
THEN INSERT (RSCInstance, SLADomain, SLADomainID, SLADomainDescription,
            ProtectedObjects, TotalObjectTypes, ObjectTypes, RetentionLocked,
            ArchiveEnabled, ArchiveTarget, ArchiveName, ArchiveType, ArchiveID, 
            ReplicationEnabled, ReplicationDuration, ReplicationUnit, ReplicationTargetCluster, ReplicationTargetClusterID, 
            LocalRetention, LocalRetentionUnit, Frequency, FrequencyUnit, FrequencyHours, FrequencyDays, 
            HourlyFrequency, HourlyRetention, DailyFrequency, DailyRetention, WeeklyFrequency, WeeklyRetention, 
            MonthlyFrequency, MonthlyRetention, QuarterlyFrequency, QuarterlyRetention, YearlyFrequency, YearlyRetention, 
            VMJournalConfigured, VMJournalRetention, VMJournalRetentionUnit, 
            MSSQLConfigured, MSSQLLogFrequency, MSSQLLogFrequencyUnit, MSSQLLogRetention, MSSQLLogRetentionUnit, 
            OracleConfigured, OracleLogFrequency, OracleLogFrequencyUnit, OracleLogRetention, OracleLogRetentionUnit, 
            SAPConfigured, SAPIncrementalFrequency, SAPIncrementalFrequencyUnit, SAPDifferentialFrequency, SAPDifferentialFrequencyUnit, SAPLogRetention, SAPLogRetentionUnit,
            DB2Configured, DB2IncrementalFrequency, DB2IncrementalFrequencyUnit, DB2DifferentialFrequency, DB2DifferentialFrequencyUnit , DB2LogRetention, DB2LogRetentionUnit,
            AWSRDSConfigured, AWSRDSLogRetention, AWSRDSLogRetentionUnit, 
            AzureSQLMIConfigured , AzureSQLMILogRetention, AzureSQLMILogRetentionUnit, AzureSQLDBConfigured, AzureSQLDBLogRetention, AzureSQLDBLogRetentionUnit, 
            URL, IsRelic, LastUpdated)
     VALUES (Source.RSCInstance, Source.SLADomain, Source.SLADomainID, Source.SLADomainDescription,
            Source.ProtectedObjects, Source.TotalObjectTypes, Source.ObjectTypes, Source.RetentionLocked,
            Source.ArchiveEnabled, Source.ArchiveTarget, Source.ArchiveName, Source.ArchiveType, Source.ArchiveID, 
            Source.ReplicationEnabled, Source.ReplicationDuration, Source.ReplicationUnit, Source.ReplicationTargetCluster, Source.ReplicationTargetClusterID, 
            Source.LocalRetention, Source.LocalRetentionUnit, Source.Frequency, Source.FrequencyUnit, Source.FrequencyHours, Source.FrequencyDays, 
            Source.HourlyFrequency, Source.HourlyRetention, Source.DailyFrequency, Source.DailyRetention, Source.WeeklyFrequency, Source.WeeklyRetention, 
            Source.MonthlyFrequency, Source.MonthlyRetention, Source.QuarterlyFrequency, Source.QuarterlyRetention, Source.YearlyFrequency, Source.YearlyRetention, 
            Source.VMJournalConfigured, Source.VMJournalRetention, Source.VMJournalRetentionUnit, 
            Source.MSSQLConfigured, Source.MSSQLLogFrequency, Source.MSSQLLogFrequencyUnit, Source.MSSQLLogRetention, Source.MSSQLLogRetentionUnit, 
            Source.OracleConfigured, Source.OracleLogFrequency, Source.OracleLogFrequencyUnit, Source.OracleLogRetention, Source.OracleLogRetentionUnit, 
            Source.SAPConfigured, Source.SAPIncrementalFrequency, Source.SAPIncrementalFrequencyUnit, Source.SAPDifferentialFrequency, Source.SAPDifferentialFrequencyUnit, Source.SAPLogRetention, Source.SAPLogRetentionUnit,
            Source.DB2Configured, Source.DB2IncrementalFrequency, Source.DB2IncrementalFrequencyUnit, Source.DB2DifferentialFrequency, Source.DB2DifferentialFrequencyUnit , Source.DB2LogRetention, Source.DB2LogRetentionUnit,
            Source.AWSRDSConfigured, Source.AWSRDSLogRetention, Source.AWSRDSLogRetentionUnit, 
            Source.AzureSQLMIConfigured , Source.AzureSQLMILogRetention, Source.AzureSQLMILogRetentionUnit, Source.AzureSQLDBConfigured, Source.AzureSQLDBLogRetention, Source.AzureSQLDBLogRetentionUnit, 
            Source.URL, Source.IsRelic, Source.LastUpdated);"
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
  ON target.SLADomainID = source.SLADomainID
WHERE source.SLADomainID IS NULL;"
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
# Calculating seconds per event
IF($RSCSLADomainCount -gt 0){$SecondsPerObject = $ScriptDurationSeconds/$RSCSLADomainCount;$SecondsPerObject=[Math]::Round($SecondsPerObject,2)}ELSE{$SecondsPerObject=0}
# Logging
Write-Host "Script Execution Summary
----------------------------------
Start: $ScriptStart
End: $ScriptEnd
CollectedEventsFrom: $TimeRange
TotalSLADomains: $RSCSLADomainCount
Runtime: $ScriptDuration
SecondsPerSLA: $SecondsPerObject"
# Returning null
Return $null
# End of function
}