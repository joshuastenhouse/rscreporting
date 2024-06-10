################################################
# Function - Write-RSCEventsAudit - Inserting all RSC Audit events into SQL
################################################
Function Write-RSCEventsAudit {

<#
.SYNOPSIS
Collects the event type specified and writes them to an existing MS SQL databse of your choosing, if not specified the default table name RSCEventsAudit will created (so you don't need to know the required structure).

.DESCRIPTION
Requires the Sqlserver PowerShell module to be installed, connects and writes RSC evevents into the MS SQL server and DB specified as the user running the script (ensure you have sufficient SQL permissions), creates the required table structure if required. Ensure the DB already exists but the table does not on first run (so it can create it). It uses permanent tables in tempdb for scale (as each Invoke-SQLCmd is a unique connection), this can be disabled with the DontUseTempDB switch.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SQLInstance
The SQL server and instance name (if required) to connect to your MS SQL server. Ensure the user running the script has permission to connect, recommended to check using MS SQL Mgmt Studio first.
.PARAMETER SQLDB
The SQL database in which to create the required table to write the events. This must already exist, it will not create the database for you.
.PARAMETER SQLTable
Not required, it will create a table called RSCEventsAudit for you, but you can customize the name (not the structure). Has to not already exist on 1st run unless you already used the correct structure. 
.PARAMETER DontUseTempDB
Switch to disable use of TempDB for scale. Use if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.
.PARAMETER DaysToCapture
The number of days to get events from, overrides all others, recommended to not go back too far without also specifying filters on LastActivityType, LastActivityStatus etc due to number of events.
.PARAMETER HoursToCapture
The number of hours to get events from, use instead of days if you want to be more granular.
.PARAMETER MinutesToCapture
The number of minutes to get events from, use instead of hours if you want to be even more granular.

.OUTPUTS
None, all the events are written into the MS SQL DB specified.

.EXAMPLE
Write-RSCEventsAudit -SQLInstance "localhost" -SQLDB "YourDBName"
This example collects all events from the default last 24 hours and writes them into a table named RSCEventsAudit that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEventsAudit -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30
This example collects all events from the default last 30 days and writes them into a table named RSCEventsAudit that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEventsAudit -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30 -SQLTable "YourTableName"
This example collects all events from the default last 30 days and writes them into a table named MyTableName that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEventsAudit -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30 -SQLTable "YourTableName" -DontUseTempDB
As above, but doesn't use regular tables in TempDB if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]$SQLInstance,
        [Parameter(Mandatory=$true)]$SQLDB,
        [Parameter(Mandatory=$false)]$SQLTable,
        [Parameter(Mandatory=$false)]$DaysToCapture,
        [Parameter(Mandatory=$false)]$HoursToCapture,
        [Parameter(Mandatory=$false)]$MinutesToCapture,
        [switch]$DontUseTempDB,
		[switch]$LogProgress
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
IF($SQLTable -eq $null){$SQLTable = "RSCEventsAudit"}
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
CreatingSQLTable: $SQLTable
----------------------------------"
Start-Sleep 3
# SQL query
$SQLCreateTable = "USE $SQLDB;
CREATE TABLE [dbo].[$SQLTable](
	[RowID] [int] IDENTITY(1,1) NOT NULL,
    [RSCInstance] [varchar](max) NULL,
	[DateUTC] [datetime] NULL,
	[Status] [varchar](50) NULL,
	[Severity] [varchar](50) NULL,
	[Username] [varchar](max) NULL,
    [Message] [varchar](max) NULL,
	[Source] [varchar](max) NULL,
	[RubrikCluster] [varchar](max) NULL,
	[EventID] [varchar](max) NULL,
	[RubrikClusterID] [varchar](max) NULL,
	[Failures] [int] NULL,
	[Exported] [varchar](50) NULL,
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
################################################
# Getting times required
################################################
$ScriptStart = Get-Date
$MachineDateTime = Get-Date
$UTCDateTime = [System.DateTime]::UtcNow
# If null, setting to 24 hours
IF(($MinutesToCapture -eq $null) -and ($HoursToCapture -eq $null))
{
$HoursToCapture = 24
}
# Calculating time range if hours specified
IF($HoursToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddHours(-$HoursToCapture)
$TimeRange = $MachineDateTime.AddHours(-$HoursToCapture)
}
# Calculating time range if minutes specified
IF($MinutesToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddMinutes(-$MinutesToCapture)
$TimeRange = $MachineDateTime.AddMinutes(-$MinutesToCapture)
# Overring hours if minutes specified
$HoursToCapture = 60 / $MinutesToCapture
$HoursToCapture = [Math]::Round($HoursToCapture,2)
}
# Overriding both if days to capture specified
IF($DaysToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddDays(-$DaysToCapture)
$TimeRange = $MachineDateTime.AddDays(-$DaysToCapture)	
}
# Converting to UNIX time format
$TimeRangeUNIX = $TimeRangeUTC.ToString("yyyy-MM-ddTHH:mm:ss.000Z")
# Logging
Write-Host "----------------------------------
HoursToCapture: $HoursToCapture
CollectingEventsFrom: $TimeRange
SQLDB: $SQLDB
SQLTable: $SQLTable
----------------------------------
Querying RSC API..."
Start-Sleep 1
################################################
# Getting RSC Events
################################################
# Creating array for events
$RSCEventsList = @()
# Building GraphQL query
$RSCEventsGraphQL = @{"operationName"="AuditLogListQuery";

"variables" = @{
"filters" = @{
    "timeGt" = "$TimeRangeUNIX"
  }
"first" = 1000
"sortOrder" = "DESC"
};

"query"="query AuditLogListQuery(`$after: String, `$first: Int, `$filters: UserAuditFilter, `$sortOrder: SortOrder) 

{userAuditConnection(after: `$after, first: `$first, filters: `$filters, sortOrder: `$sortOrder) 

{
    edges {
        node {
            userNote
            userName
            id
            message
            time
            severity
            status
            cluster {
                id
                name
                __typename       
                }        
            __typename
            }
            cursor
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
"}
# Converting to JSON
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsGraphQL | ConvertTo-JSON -Depth 32) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.userAuditConnection.edges.node
# Getting all results from paginations
While ($RSCEventsResponse.data.userAuditConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCEventsGraphQL.variables.after = $RSCEventsResponse.data.userAuditConnection.pageInfo.endCursor
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.userAuditConnection.edges.node
}
# Counting
$RSCEventsCount = $RSCEventsList | Measure-Object | Select-Object -ExpandProperty Count
# Logging
Write-Host "----------------------------------
EventsReturnedByAPI: $RSCEventsCount
----------------------------------
Processing events..."
################################################
# Processing Events
################################################
$RSCEvents = [System.Collections.ArrayList]@()
# For Each Getting info
ForEach ($Event in $RSCEventsList)
{
# Setting variables
$EventID = $Event.id
$EventUserName = $Event.userName
$EventUserNote = $Event.userNote
$EventMessage = $Event.message
$EventTimeUNIX = $Event.time
$EventStatus = $Event.status
$EventSeverity = $Event.severity
# Counting failed login attemps
IF($EventStatus -eq "Failure"){$EventFailedAttempts = $RSCEventsList | Where-Object {(($_.userName -eq $EventUserName) -and ($_.status -eq "Failure"))} | Measure-Object | Select-Object -ExpandProperty Count}ELSE{$EventFailedAttempts = 0}
# Converting event times
$EventDate = Convert-RSCUNIXTime $EventTimeUNIX
# Removing illegal SQL characters from user or message
IF($EventUserName -ne $null){$EventUserName = $EventUserName.Replace("'","");$EventUserName = $EventUserName.Replace(",","")}
IF($EventMessage -ne $null){$EventMessage = $EventMessage.Replace("'","");$EventMessage = $EventMessage.Replace(",","")
$EventMessage = $EventMessage.Replace("(","");$EventMessage = $EventMessage.Replace(")","")
$EventMessage = $EventMessage.Replace(":","");$EventMessage = $EventMessage -Replace ".$"}
# Parsing source
# IF($EventMessage -match "logged in from"){$EventSource = ($EventMessage -split 'from ',2)[-1]}ELSE{$EventSource = $null}
# Getting cluster
$EventCluster = $Event.cluster
$EventClusterID = $EventCluster.id
$EventClusterName = $EventCluster.name
# Overriding Polaris in cluster name
IF($EventClusterName -eq "Polaris"){$EventClusterName = "RSC";$EventSource = "RSC"}ELSE{$EventSource = "RubrikCluster"}
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCURL
$Object | Add-Member -MemberType NoteProperty -Name "DateUTC" -Value $EventDate
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $EventStatus
$Object | Add-Member -MemberType NoteProperty -Name "Severity" -Value $EventSeverity
$Object | Add-Member -MemberType NoteProperty -Name "UserName" -Value $EventUserName
$Object | Add-Member -MemberType NoteProperty -Name "Source" -Value $EventSource
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $EventClusterName
$Object | Add-Member -MemberType NoteProperty -Name "Message" -Value $EventMessage
# Always null so leaving out for now 08/29/22 # $Object | Add-Member -MemberType NoteProperty -Name "UserNote" -Value $EventUserNote
$Object | Add-Member -MemberType NoteProperty -Name "Failures" -Value $EventFailedAttempts
# IDs 
$Object | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $EventClusterID
# Adding to array (optional, not needed)
$RSCEvents.Add($Object) | Out-Null
############################
# Adding To SQL Table directly if no tempDB
############################
IF($DontUseTempDB)
{
$SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
-- Instance, Date & Status
RSCInstance, DateUTC, Status, Severity,

-- User, message, source, cluster
Username, Message, Source, RubrikCluster, Failures,

-- IDs
EventID, RubrikClusterID, Exported)
VALUES(
-- Instance, Date & Status
'$RSCInstance', '$EventDate', '$EventStatus', '$EventSeverity',

-- User, message, source, cluster, attempts
'$EventUserName', '$EventMessage', '$EventSource', '$EventClusterName', '$EventFailedAttempts',

-- IDs
'$EventID', '$EventClusterID','FALSE');"
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
-- Instance, Date & Status
RSCInstance, DateUTC, Status, Severity,

-- User, message, source, cluster
Username, Message, Source, RubrikCluster, Failures,

-- IDs
EventID, RubrikClusterID, Exported)
VALUES(
-- Instance, Date & Status
'$RSCInstance', '$EventDate', '$EventStatus', '$EventSeverity',

-- User, message, source, cluster, attempts
'$EventUserName', '$EventMessage', '$EventSource', '$EventClusterName', '$EventFailedAttempts',

-- IDs
'$EventID', '$EventClusterID','FALSE');"
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
# End of for each event below
}
# End of for each event above
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
$SQLQuery = "WITH cte AS (SELECT EventID, ROW_NUMBER() OVER (PARTITION BY EventID ORDER BY EventID) rownum FROM $SQLDB.dbo.$SQLTable )
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
ON (Target.EventID = Source.EventID)
WHEN MATCHED 
     THEN UPDATE
     SET    Target.DateUTC = Source.DateUTC,
            Target.Status = Source.Status,
            Target.Username = Source.Username,
            Target.Severity = Source.Severity, 
			Target.Message = Source.Message,
            Target.Source = Source.Source,
            Target.RubrikCluster = Source.RubrikCluster,
            Target.Failures = Source.Failures,
            Target.Exported = Source.Exported
WHEN NOT MATCHED BY TARGET
THEN INSERT (RSCInstance, DateUTC, Status, Severity,
			Username, Message, Source, RubrikCluster, Failures,
			EventID, RubrikClusterID, Exported)
     VALUES (Source.RSCInstance, Source.DateUTC, Source.Status, Source.Severity,
			Source.Username, Source.Message, Source.Source, Source.RubrikCluster, Source.Failures,
			Source.EventID, Source.RubrikClusterID, Source.Exported);"
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

