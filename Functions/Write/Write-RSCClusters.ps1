################################################
# Function - Write-RSCClusters - Getting all RSC Clusters and writing their data to a SQL table
################################################
function Write-RSCCluster {

    <#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for writing cluster data into a MSSQL DB/Table of your choosing.

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
Write-RSCClusters -SQLInstance "localhost" -SQLDB "YourDBName"
This example gets all object storage usage, creates a table called RSCClusters with the required structure then populates it with the API data.

.EXAMPLE
Write-RSCClusters -SQLInstance "localhost" -SQLDB "YourDBName" -DontUseTempDB
This example does the same as above, but doesn't use TempDB (if you have permissions issues with creating tables in it and aren't concerned about locks).

.EXAMPLE
Write-RSCClusters -SQLInstance "localhost" -SQLDB "YourDBName" -SQLTable "YourTableName" 
This example gets all RSC clusters, creates a table using the name specified with the required structure then populates it with the API data.

.NOTES
Author: Joshua Stenhouse
Date: 01/22/2026
#>

    ################################################
    # Paramater Config
    ################################################
    [CmdletBinding()]
    [Alias('Write-RSCClusters')]
    param
    (
        [Parameter(Mandatory = $true)]$SQLInstance,
        [Parameter(Mandatory = $true)]$SQLDB, $SQLTable,
        [Parameter(Mandatory = $false)]$RubrikClusterID,
        [switch]$DropExistingRows,
        [switch]$DontUseTempDB,
        [switch]$ShowSQLQuery
    )
	
    ################################################
    # Importing Module & Running Required Functions
    ################################################
    # Importing the module is it needs other modules
    Import-Module RSCReporting
    # Checking connectivity, exiting function with error if not connected
    Test-RSCConnection
    # Getting objects list if not already pulled as a global variable in this session
    # IF($RSCGlobalObjects -eq $null){$RSCObjects = Get-RSCObjects -Logging;$Global:RSCGlobalObjects = $RSCObjects}ELSE{$RSCObjects = $RSCGlobalObjects}
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
    $SQLModuleName = $PSModules | Where-Object { (($_ -eq "SQLPS") -or ($_ -eq "SqlServer")) } | Select-Object -Last 1
    # Checking to see if SQL Server module is loaded
    $SQLModuleCheck = Get-Module $SQLModuleName
    # If SQL module not found in current session importing
    if ($SQLModuleCheck -eq $null) { Import-Module $SQLModuleName -ErrorAction SilentlyContinue }
    ##########################
    # SQL - Checking Table Exists
    ##########################
    # Manually setting SQL table name if not specified
    if ($SQLTable -eq $null) { $SQLTable = "RSCClusters" }
    # Creating query
    $SQLTableListQuery = "USE $SQLDB;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;"
    # Run SQL query
    try {
        $SQLTableList = Invoke-Sqlcmd -Query $SQLTableListQuery -ServerInstance $SQLInstance -QueryTimeout 300 
    }
    catch {
        $Error[0] | Format-List -Force
    }
    # Selecting
    $SQLTableList = $SQLTableList | Select-Object -ExpandProperty TABLE_NAME
    # Checking
    if ($SQLTableList -match $SQLTable) { $SQLTableExists = $TRUE }else { $SQLTableExists = $FALSE }
    ##########################
    # SQL - Creating table if doesn't exist
    ##########################
    if ($SQLTableExists -eq $FALSE) {
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
	[Cluster] [varchar](max) NULL,
	[ClusterID] [varchar](max) NULL,
	[Status] [varchar](50) NULL,
    [Errors] [varchar](max) NULL,
    [Version] [varchar](max) NULL,
    [VersionStatus] [varchar](50) NULL,
    [ConnectionStatus] [varchar](50) NULL,
    [LastConnected] [datetime] NULL,
    [HoursSince] [decimal](18, 1) NULL,
    [MinutesSince] [bigint] NULL,
    [Type] [varchar](max) NULL,
    [Product] [varchar](max) NULL,
    [Encrypted] [varchar](max) NULL,
    [Snapshots] [bigint] NULL,
    [Location] [varchar](max) NULL,
    [Latitude] [varchar](max) NULL,
    [Longitude] [varchar](max) NULL,
    [Timezone] [varchar](max) NULL,
    [TotalStorageTB] [decimal](18, 2) NULL,
    [UsedStorageTB] [decimal](18, 2) NULL,
    [FreeStorageTB] [decimal](18, 2) NULL,
    [Used] [varchar](max) NULL,
    [Free] [varchar](max) NULL,
    [UsedINT] [decimal](18, 2) NULL,
    [FreeINT] [decimal](18, 2) NULL,
    [RunwayDays] [int] NULL,
    [TotalNodes] [int] NULL,
    [BadNodes] [int] NULL,
    [HealthyNodes] [int] NULL,
    [TotalDisks] [int] NULL,
    [BadDisks] [int] NULL,
    [HealthyDisks] [int] NULL,
    [ArchiveTargets] [int] NULL,
    [ReplicationTargets] [int] NULL,
    [ReplicationSources] [int] NULL,
	[PauseStatus] [varchar](50) NULL,
    [RegisteredUTC] [varchar](max) NULL,
    [URL] [varchar](max) NULL,
    [Exported] [varchar](50) NULL,
 CONSTRAINT [PK_$SQLTable] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];"
        # Run SQL query
        try {
            Invoke-Sqlcmd -Query $SQLCreateTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
        }
        catch {
            $Error[0] | Format-List -Force
        }
        # End of SQL table creation below
    }
    # End of SQL table creation above
    ##########################
    # SQL - Creating temp table
    ##########################
    if ($DontUseTempDB) {
        # Nothing to create, bypassing
    }
    else {
        $RandomID = 0..10000 | Get-Random
        # Create temp table name
        $TempTableName = $SQLTable + [string]$RandomID
        # Create the table from an existing structure
        $SQLCreateTable = "USE tempdb;
SELECT *   
INTO $TempTableName  
FROM $SQLDB.dbo.$SQLTable  
WHERE 1 > 2;"
        # Run SQL query
        try {
            Invoke-Sqlcmd -Query $SQLCreateTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
        }
        catch {
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
    if ($DropExistingRows) {
        # Creating SQL query
        $SQLDrop = "USE $SQLDB
DELETE FROM $SQLTable;"
        # Run SQL query
        try {
            Invoke-Sqlcmd -Query $SQLDrop -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
        }
        catch {
            $Error[0] | Format-List -Force
        }
        # Logging
        Write-Host "----------------------------------
DeletingExistingRowsIn: $SQLTable"
    }
    ################################################
    # Getting RSC Clusters
    ################################################
    # Logging
    Write-Host "----------------------------------
Collecting: Clusters..."
    # Making API call
    $ObjectList = Get-RSCClusters
    $ObjectList = $ObjectList | Where-Object { $_.ClusterID -ne $null }
    # Counting
    $ObjectListCount = $ObjectList | Measure-Object | Select-Object -ExpandProperty Count
    $ObjectListCounter = 0
    ################################################
    # Processing Clusters
    ################################################
    foreach ($Object in $ObjectList) {
        $ObjectListCounter ++
        Write-Host "ProcessingObject: $ObjectListCounter/$ObjectListCount"
        # Setting variables
        $RSCInstance = $Object.RSCInstance
        $Cluster = $Object.Cluster
        $ClusterID = $Object.ClusterID
        $Status = $Object.Status
        $Errors = $Object.Errors
        $Version = $Object.Version
        $VersionStatus = $Object.VersionStatus
        $ConnectionStatus = $Object.ConnectionStatus
        $LastConnected = $Object.LastConnected
        $HoursSince = $Object.HoursSince
        $MinutesSince = $Object.MinutesSince
        $Type = $Object.Type
        $Product = $Object.Product
        $Encrypted = $Object.Encrypted
        $Snapshots = $Object.Snapshots
        $Location = $Object.Location
        $Latitude = $Object.Latitude
        $Longitude = $Object.Longitude
        $Timezone = $Object.Timezone
        $TotalStorageTB = $Object.TotalStorageTB
        $UsedStorageTB = $Object.UsedStorageTB
        $FreeStorageTB = $Object.FreeStorageTB
        $Used = $Object.Used
        $Free = $Object.Free
        $UsedINT = $Object.UsedINT
        $FreeINT = $Object.FreeINT
        $RunwayDays = $Object.RunwayDays
        $TotalNodes = $Object.TotalNodes
        $BadNodes = $Object.BadNodes
        $HealthyNodes = $Object.HealthyNodes
        $TotalDisks = $Object.TotalDisks
        $BadDisks = $Object.BadDisks
        $HealthyDisks = $Object.HealthyDisks
        $ArchiveTargets = $Object.ArchiveTargets
        $ReplicationTargets = $Object.ReplicationTargets
        $ReplicationSources = $Object.ReplicationSources
        $PauseStatus = $Object.PauseStatus
        $RegisteredUTC = $Object.RegisteredUTC
        $URL = $Object.URL
        ############################
        # SQL Pre-Insert Work
        ############################
        # Fixing nulls for SQL insert
        if ($TotalStorageTB -eq $null) { $TotalStorageTB = 0 }
        if ($UsedStorageTB -eq $null) { $UsedStorageTB = 0 }
        if ($FreeStorageTB -eq $null) { $FreeStorageTB = 0 }
        # Removing illegal SQL characters 
        $Cluster = $Cluster.Replace("'", "")
        $Location = $Location.Replace("'", "")
        $Location = $Location.Replace(",", "")
        ############################
        # Adding To SQL Table directly if no tempDB
        ############################
        if ($DontUseTempDB) {
            $SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
DateUTC, RSCInstance, Cluster, ClusterID, Status, Errors, Version, VersionStatus,

ConnectionStatus, LastConnected, HoursSince, MinutesSince, Type, Product, Encrypted, Snapshots,

Location, Latitude, Longitude, Timezone,

TotalStorageTB, UsedStorageTB, FreeStorageTB, Used, Free, UsedINT, FreeINT, RunwayDays,

TotalNodes, BadNodes, HealthyNodes, TotalDisks, BadDisks, HealthyDisks, ArchiveTargets, ReplicationTargets, ReplicationSources,

PauseStatus, RegisteredUTC, Exported, URL)
VALUES(
'$UTCDateTime', '$RSCInstance', '$Cluster', '$ClusterID', '$Status', '$Errors', '$Version', '$VersionStatus',

'$ConnectionStatus', '$LastConnected', '$HoursSince', '$MinutesSince', '$Type', '$Product', '$Encrypted', '$Snapshots',

'$Location', '$Latitude', '$Longitude', '$Timezone',

'$TotalStorageTB', '$UsedStorageTB', '$FreeStorageTB', '$Used', '$Free', '$UsedINT', '$FreeINT', '$RunwayDays',

'$TotalNodes', '$BadNodes', '$HealthyNodes', '$TotalDisks', '$BadDisks', '$HealthyDisks', '$ArchiveTargets', '$ReplicationTargets', '$ReplicationSources',

'$PauseStatus', '$RegisteredUTC', 'False', '$URL');"
            # Inserting
            try {
                Invoke-Sqlcmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
            }
            catch {
                $Error[0] | Format-List -Force
            }
        }
        else {
            ############################
            # Adding To SQL temp table
            ############################
            $SQLInsert = "USE tempdb
INSERT INTO $TempTableName (
DateUTC, RSCInstance, Cluster, ClusterID, Status, Errors, Version, VersionStatus,

ConnectionStatus, LastConnected, HoursSince, MinutesSince, Type, Product, Encrypted, Snapshots,

Location, Latitude, Longitude, Timezone,

TotalStorageTB, UsedStorageTB, FreeStorageTB, Used, Free, UsedINT, FreeINT, RunwayDays,

TotalNodes, BadNodes, HealthyNodes, TotalDisks, BadDisks, HealthyDisks, ArchiveTargets, ReplicationTargets, ReplicationSources,

PauseStatus, RegisteredUTC, Exported, URL)
VALUES(
'$UTCDateTime', '$RSCInstance', '$Cluster', '$ClusterID', '$Status', '$Errors', '$Version', '$VersionStatus',

'$ConnectionStatus', '$LastConnected', '$HoursSince', '$MinutesSince', '$Type', '$Product', '$Encrypted', '$Snapshots',

'$Location', '$Latitude', '$Longitude', '$Timezone',

'$TotalStorageTB', '$UsedStorageTB', '$FreeStorageTB', '$Used', '$Free', '$UsedINT', '$FreeINT', '$RunwayDays',

'$TotalNodes', '$BadNodes', '$HealthyNodes', '$TotalDisks', '$BadDisks', '$HealthyDisks', '$ArchiveTargets', '$ReplicationTargets', '$ReplicationSources',

'$PauseStatus', '$RegisteredUTC', 'False', '$URL');"
            # Inserting
            try {
                Invoke-Sqlcmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
            }
            catch {
                $Error[0] | Format-List -Force
            }
            # End of bypass for using tempdb below
        }
        # End of bypass for using tempdb above
        #
        # Logging
        if ($ShowSQLQuery) { Write-Host $SQLInsert }
        #
        # End of for each object below
    }
    # End of for each object above
    ##################################
    # Finishing SQL Work
    ##################################
    # Logging
    Write-Host "----------------------------------
Finished Processing RSC Clusters
----------------------------------"
    ############################
    # Removing Duplicates if not using TempDB
    ############################
    if ($DontUseTempDB) {
        # Nothing to do, this table is supposed to have multiple entries to track storage usage over time if desired
    }
    else {
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
THEN INSERT (DateUTC, RSCInstance, Cluster, ClusterID, Status, Errors, Version, VersionStatus,
            ConnectionStatus, LastConnected, HoursSince, MinutesSince, Type, Product, Encrypted, Snapshots,
            Location, Latitude, Longitude, Timezone,
            TotalStorageTB, UsedStorageTB, FreeStorageTB, Used, Free, UsedINT, FreeINT, RunwayDays,
            TotalNodes, BadNodes, HealthyNodes, TotalDisks, BadDisks, HealthyDisks, ArchiveTargets, ReplicationTargets, ReplicationSources,
            PauseStatus, RegisteredUTC, Exported, URL)
     VALUES (Source.DateUTC, Source.RSCInstance, Source.Cluster, Source.ClusterID, Source.Status, Source.Errors, Source.Version, Source.VersionStatus,
            Source.ConnectionStatus, Source.LastConnected, Source.HoursSince, Source.MinutesSince, Source.Type, Source.Product, Source.Encrypted, Source.Snapshots,
            Source.Location, Source.Latitude, Source.Longitude, Source.Timezone,
            Source.TotalStorageTB, Source.UsedStorageTB, Source.FreeStorageTB, Source.Used, Source.Free, Source.UsedINT, Source.FreeINT, Source.RunwayDays,
            Source.TotalNodes, Source.BadNodes, Source.HealthyNodes, Source.TotalDisks, Source.BadDisks, Source.HealthyDisks, Source.ArchiveTargets, Source.ReplicationTargets, Source.ReplicationSources,
            Source.PauseStatus, Source.RegisteredUTC, Source.Exported, Source.URL);"
        # Run SQL query
        try {
            Invoke-Sqlcmd -Query $SQLMergeTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
            $SQLMergeSuccess = $TRUE
        }
        catch {
            $SQLMergeSuccess = $FALSE
            $Error[0] | Format-List -Force
        }
        ##################################
        # SQL - Deleting Temp Table
        ##################################
        if ($SQLMergeSuccess -eq $TRUE) {
            # Creating SQL query
            $SQLDropTable = "USE tempdb;
DROP TABLE $TempTableName;"
            # Run SQL query
            try {
                Invoke-Sqlcmd -Query $SQLDropTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
            }
            catch {
                $Error[0] | Format-List -Force
            }
            # Logging
            Write-Host "----------------------------------
DroppedTableInTempDB: $TempTableName
----------------------------------"
        }
        else {
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
    if (($ScriptStart -ne $null) -and ($ScriptEnd -ne $null)) {
        $Timespan = New-TimeSpan -Start $ScriptStart -End $ScriptEnd
        $ScriptDurationSeconds = $Timespan.TotalSeconds
        $ScriptDurationSeconds = [Math]::Round($ScriptDurationSeconds)
        $ScriptDuration = "{0:}" -f $Timespan; $ScriptDuration = $ScriptDuration.Substring(0, 8)
    }
    else {
        $ScriptDuration = 0
    }
    # Logging
    Write-Host "Script Execution Summary
----------------------------------
Start: $ScriptStart
End: $ScriptEnd
TotalClusters: $ObjectListCount
Runtime: $ScriptDuration"
    # Returning null
    return $null
    # End of function
}

