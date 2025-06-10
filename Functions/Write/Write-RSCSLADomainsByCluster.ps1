################################################
# Function - Write-RSCSLADomainsByCluster - Getting all cluster SLA domains visible to the RSC instance and writing them to a SQL database table
################################################
Function Write-RSCSLADomainsByCluster {

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
Write-RSCSLADomainsByCluster -SQLInstance "localhost" -SQLDB "YourDBName"
This example gets all object storage usage, creates a table called RSCObjectStorageUsage with the required structure then populates it with the API data.

.EXAMPLE
Write-RSCSLADomainsByCluster -SQLInstance "localhost" -SQLDB "YourDBName" -DontUseTempDB
This example does the same as above, but doesn't use TempDB (if you have permissions issues with creating tables in it and aren't concerned about locks).

.EXAMPLE
Write-RSCSLADomainsByCluster -SQLInstance "localhost" -SQLDB "YourDBName" -SQLTable "YourTableName" 
This example gets all object storage usage, creates a table using the name specified with the required structure then populates it with the API data.

.NOTES
Author: Joshua Stenhouse
Date: 12/11/2024
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
IF($SQLTable -eq $null){$SQLTable = "RSCClusterSLADomains"}
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
    [Description] [varchar](max) NULL,
    [RubrikCluster] [varchar](max) NULL,
    [RubrikClusterID] [varchar](max) NULL,
    [Status] [varchar](50) NULL,
    [Version] [varchar](50) NULL,
    [URL] [varchar](max) NULL,
    [IsRelic] [varchar](50) NULL,
	[LastUpdated] [datetime] NULL,
    [UniqueID] [varchar](max) NULL
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
$RSCSLADomainsList = Get-RSCSLADomainsByCluster
$RSCSLADomainCount = $RSCSLADomainsList | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "ClusterSLADomainsFound: $RSCSLADomainCount"
# Logging
# IF($DisableLogging){}ELSE{Write-Host "GettingObjects: $ObjectCount-$ObjectCounter"}
################################################
# Processing SLA Domains
################################################
$RSCSLADomainCounter = 0
# Getting current time for last snapshot age
$UTCDateTime = [System.DateTime]::UtcNow
# Processing
ForEach ($RSCSLADomain in $RSCSLADomainsList)
{
# Setting variables
$RSCInstance = $RSCSLADomain.RSCInstance
$SLADomain = $RSCSLADomain.SLADomain
$SLADomainID = $RSCSLADomain.SLADomainID
$Description = $RSCSLADomain.Description
$RubrikCluster = $RSCSLADomain.RubrikCluster
$RubrikClusterID = $RSCSLADomain.RubrikClusterID
$Status = $RSCSLADomain.Status
$Version = $RSCSLADomain.Version
$URL = $RSCSLADomain.URL
$LastUpdated = "{0:yyyy-MM-dd HH:mm:ss}" -f (Get-Date)
$UniqueID = $RubrikClusterID + "-" + $SLADomainID
# Logging
$RSCSLADomainCounter ++
IF($DisableLogging){}ELSE{Write-Host "InsertingSLADomain:$RSCSLADomainCounter/$RSCSLADomainCount"}
############################
# Adding To SQL Table directly if no tempDB
############################
IF($DontUseTempDB)
{
$SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
RSCInstance, SLADomain, SLADomainID, Description,
RubrikCluster, RubrikClusterID, Status, Version, 
URL, IsRelic, LastUpdated, UniqueID)
VALUES(
'$RSCInstance', '$SLADomain', '$SLADomainID', '$Description',
'$RubrikCluster', '$RubrikClusterID', '$Status', '$Version', 
'$URL', '$FALSE', '$LastUpdated', '$UniqueID');"
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
RSCInstance, SLADomain, SLADomainID, Description,
RubrikCluster, RubrikClusterID, Status, Version, 
URL, IsRelic, LastUpdated, UniqueID)
VALUES(
'$RSCInstance', '$SLADomain', '$SLADomainID', '$Description',
'$RubrikCluster', '$RubrikClusterID', '$Status', '$Version', 
'$URL', '$FALSE', '$LastUpdated', '$UniqueID');"
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
ON (Target.UniqueID = Source.UniqueID)
WHEN MATCHED 
     THEN UPDATE
     SET    Target.RSCInstance = Source.RSCInstance,
            Target.SLADomain = Source.SLADomain,
            Target.SLADomainID = Source.SLADomainID,
            Target.Description = Source.Description,
            Target.RubrikCluster = Source.RubrikCluster,
            Target.RubrikClusterID = Source.RubrikClusterID,
            Target.Status = Source.Status,
            Target.Version = Source.Version,
            Target.URL = Source.URL,
            Target.IsRelic = Source.IsRelic,
            Target.LastUpdated = Source.LastUpdated
WHEN NOT MATCHED BY TARGET
THEN INSERT (RSCInstance, SLADomain, SLADomainID, Description,
            RubrikCluster, RubrikClusterID, Status, Version, 
            URL, IsRelic, LastUpdated, UniqueID)
     VALUES (Source.RSCInstance, Source.SLADomain, Source.SLADomainID, Source.Description,
            Source.RubrikCluster, Source.RubrikClusterID, Source.Status, Source.Version, 
            Source.URL, Source.IsRelic, Source.LastUpdated, Source.UniqueID);"
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
  ON target.UniqueID = source.UniqueID
WHERE source.UniqueID IS NULL;"
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