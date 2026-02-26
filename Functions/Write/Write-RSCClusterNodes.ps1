################################################
# Function - Write-RSCClusterNodes - Getting all RSC Cluster nodes and writing their data to a SQL table
################################################
function Write-RSCClusterNode {

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
Write-RSCClusterNodes -SQLInstance "localhost" -SQLDB "YourDBName"
This example gets all object storage usage, creates a table called RSCClusters with the required structure then populates it with the API data.

.EXAMPLE
Write-RSCClusterNodes -SQLInstance "localhost" -SQLDB "YourDBName" -DontUseTempDB
This example does the same as above, but doesn't use TempDB (if you have permissions issues with creating tables in it and aren't concerned about locks).

.EXAMPLE
Write-RSCClusterNodes -SQLInstance "localhost" -SQLDB "YourDBName" -SQLTable "YourTableName" 
This example gets all RSC cluster nodes, creates a table using the name specified with the required structure then populates it with the API data.

.NOTES
Author: Joshua Stenhouse
Date: 01/22/2026
#>

    ################################################
    # Paramater Config
    ################################################
    [CmdletBinding()]
    [Alias('Write-RSCClusterNodes')]
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
    if ($SQLTable -eq $null) { $SQLTable = "RSCClusterNodes" }
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
    [NodeID] [varchar](max) NULL,
    [NodeStatus] [varchar](max) NULL,
    [IPAddress] [varchar](max) NULL,
	[Cluster] [varchar](max) NULL,
	[ClusterStatus] [varchar](50) NULL,
    [ClusterID] [varchar](max) NULL,
    [Type] [varchar](max) NULL,
    [Encrypted] [varchar](max) NULL,
    [Location] [varchar](max) NULL,
    [Healthy] [varchar](max) NULL,
    [Version] [varchar](max) NULL,
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
    # Getting RSC Cluster Nodes
    ################################################
    # Logging
    Write-Host "----------------------------------
Collecting: Cluster Nodes..."
    # Making API call
    $ObjectList = Get-RSCClusterNodes
    $ObjectList = $ObjectList | Where-Object { $_.NodeID -ne $null }
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
        $NodeID = $Object.NodeID
        $NodeStatus = $Object.NodeStatus
        $IPAddress = $Object.IPAddress
        $Cluster = $Object.Cluster
        $ClusterStatus = $Object.ClusterStatus
        $ClusterID = $Object.ClusterID
        $Type = $Object.Type
        $FullNodeID = $Object.FullNodeID
        $Encrypted = $Object.Encrypted
        $Location = $Object.Location
        $Healthy = $Object.Healthy
        $Version = $Object.Version
        $URL = $Object.URL
        # Removing illegal SQL characters 
        $Cluster = $Cluster.Replace("'", "")
        $Location = $Location.Replace(",", "")
        ############################
        # Adding To SQL Table directly if no tempDB
        ############################
        if ($DontUseTempDB) {
            $SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
DateUTC, RSCInstance, NodeID, NodeStatus, IPAddress,

Cluster, ClusterStatus, ClusterID, Type,

Encrypted, Location, Healthy, Version, Exported, URL)
VALUES(
'$UTCDateTime', '$RSCInstance', '$NodeID', '$NodeStatus', '$IPAddress',

'$Cluster', '$ClusterStatus', '$ClusterID', '$Type',

'$Encrypted', '$Location', '$Healthy', '$Version', 'False', '$URL');"
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
DateUTC, RSCInstance, NodeID, NodeStatus, IPAddress,

Cluster, ClusterStatus, ClusterID, Type,

Encrypted, Location, Healthy, Version, Exported, URL)
VALUES(
'$UTCDateTime', '$RSCInstance', '$NodeID', '$NodeStatus', '$IPAddress',

'$Cluster', '$ClusterStatus', '$ClusterID', '$Type',

'$Encrypted', '$Location', '$Healthy', '$Version', 'False', '$URL');"
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
        # End of for each object below
    }
    # End of for each object above
    ##################################
    # Finishing SQL Work
    ##################################
    # Logging
    Write-Host "----------------------------------
Finished Processing RSC Cluster Nodes
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
THEN INSERT (DateUTC, RSCInstance, NodeID, NodeStatus, IPAddress,
            Cluster, ClusterStatus, ClusterID, Type,
            Encrypted, Location, Healthy, Version, Exported, URL)
     VALUES (Source.DateUTC, Source.RSCInstance, Source.NodeID, Source.NodeStatus, Source.IPAddress,
            Source.Cluster, Source.ClusterStatus, Source.ClusterID, Source.Type,
            Source.Encrypted, Source.Location, Source.Healthy, Source.Version, Source.Exported, Source.URL);"
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
TotalClusterNodes: $ObjectListCount
Runtime: $ScriptDuration"
    # Returning null
    return $null
    # End of function
}

