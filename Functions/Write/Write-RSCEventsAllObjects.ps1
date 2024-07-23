################################################
# Function - Write-RSCEventsAllObjects - Inserting all RSC Archive events into SQL
################################################
Function Write-RSCEventsAllObjects {

<#
.SYNOPSIS
Collects the event type specified for all protected objects and writes them to an existing MS SQL databse of your choosing, if not specified the default table name RSCEvents will created (so you don't need to know the required structure).

.DESCRIPTION
Requires the Sqlserver PowerShell module to be installed, connects and writes RSC evevents into the MS SQL server and DB specified as the user running the script (ensure you have sufficient SQL permissions), creates the required table structure if required. Ensure the DB already exists but the table does not on first run (so it can create it). It uses permanent tables in tempdb for scale (as each Invoke-SQLCmd is a unique connection), this can be disabled with the DontUseTempDB switch.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SQLInstance
The SQL server and instance name (if required) to connect to your MS SQL server. Ensure the user running the script has permission to connect, recommended to check using MS SQL Mgmt Studio first.
.PARAMETER SQLDB
The SQL database in which to create the required table to write the events. This must already exist, it will not create the database for you.
.PARAMETER SQLTable
Not required, it will create a table called RSCEvents for you, but you can customize the name (not the structure). Has to not already exist on 1st run unless you already used the correct structure. 
.PARAMETER DontUseTempDB
Switch to disable use of TempDB for scale. Use if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.
.PARAMETER LastActivityType
Set the required type of events, has to be from the schema link, you can also try not specifying this, then use EventType on the array to get a valid list of LastActivityTypes.
.PARAMETER LastActivityStatus
Set the required status of events, has to be from the schema link, you can also try not specifying this, then use EventStatus on the array to get a valid list of LastActivityStatus.
.PARAMETER ObjectType
Set the required object type of the events, has to be be a valid object type from the schema link, you can also try not specifying this, then use ObjectType on the array to get a valid list of ObjectType.

.OUTPUTS
None, all the events are written into the MS SQL DB specified.

.EXAMPLE
Write-RSCEvents -SQLInstance "localhost" -SQLDB "YourDBName"
This example collects all events from the default last 24 hours and writes them into a table named RSCEvents that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEvents -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30 -LastActivityType "BACKUP"
This example collects all backup events from the default last 30 days and writes them into a table named RSCEvents that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEvents -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30 -SQLTable "YourTableName"
This example collects all events from the default last 30 days and writes them into a table named MyTableName that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEvents -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30 -SQLTable "YourTableName" -DontUseTempDB
As above, but doesn't use regular tables in TempDB if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.

.EXAMPLE
Write-RSCEvents -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30 -SQLTable "YourTableName" -LastActivityStatus "FAILED"
This example collects all failed events from the default last 30 days and writes them into a table named MyTableName that it will create on first run with the required structure in the database RSCReprting.

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
        [Parameter(Mandatory=$false)]$LastActivityStatus,
        [Parameter(Mandatory=$false)]$ObjectType,
        [Parameter(Mandatory=$false)]$ObjectName,
        [Parameter(Mandatory=$false)]$FromDate,
        [Parameter(Mandatory=$false)]$ToDate,
        [switch]$SampleFirst10Objects,
        [switch]$ExcludeLogBackups,
        [switch]$ExcludeRunningJobs,
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
IF($SQLTable -eq $null){$SQLTable = "RSCEventsArchive"}
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
	[EventID] [varchar](max) NULL,
	[RubrikCluster] [varchar](max) NULL,
	[RubrikClusterID] [varchar](max) NULL,
	[Object] [varchar](max) NULL,
	[ObjectID] [varchar](max) NULL,
	[ObjectCDMID] [varchar](max) NULL,
	[ObjectType] [varchar](max) NULL,
    [Snapshot] [varchar](50) NULL,
	[Target] [varchar](max) NULL,
	[DateUTC] [datetime] NULL,
	[Type] [varchar](max) NULL,
	[Status] [varchar](50) NULL,
	[Result] [varchar](max) NULL,
	[JobStartUTC] [datetime] NULL,
	[JobEndUTC] [datetime] NULL,
	[Duration] [varchar](50) NULL,
	[DurationSeconds] [varchar](50) NULL,
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
################################################
# Getting RSC Events
################################################
# Getting RSC protected objects
$ProtectedObjects = Get-RSCObjects | Where-Object {$_.ReportOnCompliance -eq $TRUE}
# Overriding if wanting sample if switch used
IF($SampleFirst10Objects){$ProtectedObjects = $ProtectedObjects | Select-Object -First 10}
# Counting
$ProtectedObjectsCount = $ProtectedObjects | Measure-Object | Select-Object -ExpandProperty Count
$ProtectedObjectsCounter = 0
# Creating array for events
$RSCEvents = [System.Collections.ArrayList]@()
ForEach ($ProtectedObject in $ProtectedObjects)
{
# Setting variables
$ProtectedObjectName = $ProtectedObject.Object
$ProtectedObjectID = $ProtectedObject.ObjectID
# Incrementing
$ProtectedObjectsCounter++
# Creating list array per object
$RSCEventsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "EventSeriesListQuery";

"variables" = @{
"filters" = @{
  }
"first" = 1000
"sortOrder" = "DESC"
};

"query" = "query EventSeriesListQuery(`$after: String, `$filters: ActivitySeriesFilter, `$first: Int, `$sortOrder: SortOrder) {
  activitySeriesConnection(after: `$after, first: `$first, filters: `$filters, sortOrder: `$sortOrder) {
    edges {
      node {
        ...EventSeriesFragment
        cluster {
          id
          name
          version
        }
        activityConnection(first: 1) {
          nodes {
            id
            message
            __typename
            activityInfo
          }
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
fragment EventSeriesFragment on ActivitySeries {
  id
  fid
  activitySeriesId
  lastUpdated
  lastActivityType
  lastActivityStatus
  objectId
  objectName
  location
  objectType
  severity
  progress
  isCancelable
  isPolarisEventSeries
  startTime
  location
  effectiveThroughput
  dataTransferred
  logicalSize
  organizations {
    id
    name
    __typename
  }
  __typename
}"
}
################################################
# Adding Variables to GraphQL Query
################################################
# Converting to JSON
$RSCEventsJSON = $RSCGraphQL | ConvertTo-Json -Depth 32
# Converting back to PS object for editing of variables
$RSCEventsJSONObject = $RSCEventsJSON | ConvertFrom-Json
# Adding variables specified
IF($lastActivityType -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "lastActivityType" -Value $LastActivityType}
IF($lastActivityStatus -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "lastActivityStatus" -Value $LastActivityStatus}
IF($objectType -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "objectType" -Value $ObjectType}
IF($ProtectedObjectName -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "objectName" -Value $ProtectedObjectName}
# Querying API
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-JSON -Depth 32) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges
# Getting all results from paginations
While($RSCEventsResponse.data.activitySeriesConnection.pageInfo.hasNextPage) 
{
# Setting after variable, querying API again, adding to array
$RSCEventsJSONObject.variables | Add-Member -MemberType NoteProperty "after" -Value $RSCEventsResponse.data.activitySeriesConnection.pageInfo.endCursor -Force
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges
}
# Selecting data
$RSCEventsList = $RSCEventsList.node
################################################
# Removing EVents
################################################
$RSCEventsList = $RSCEventsList | Where-Object {$_.fid -eq $ProtectedObjectID}
# Removing queued events
$RSCEventsList = $RSCEventsList | Where-Object {$_.lastActivityStatus -ne "Queued"}
# Removing running jobs if switch used
IF($ExcludeRunningJobs)
{
$RSCEventsList = $RSCEventsList | Where-Object {$_.lastActivityStatus -ne "Running"}
}
# Counting object list
$RSCEventsListCount = $RSCEventsList | Measure-Object | Select-Object -ExpandProperty Count
################################################
# Processing Events
################################################
# For Each Getting info
ForEach ($Event in $RSCEventsList)
{
# Setting variables
$EventID = $Event.activitySeriesId
$EventObjectID = $Event.fid
$EventObjectCDMID = $Event.objectId
$EventObject = $Event.objectName
$EventObjectType = $Event.objectType
$EventType = $Event.lastActivityType
$EventLocation = $Event.location
$EventSeverity = $Event.severity
$EventStatus = $Event.lastActivityStatus
$EventDateUNIX = $Event.lastUpdated
$EventStartUNIX = $Event.startTime
$EventEndUNIX = $EventDateUNIX
# Getting cluster info
$EventCluster = $Event.cluster
# Only processing if not null, could be cloud native
IF ($EventCluster -ne $null)
{
# Setting variables
$EventClusterID = $EventCluster.id
$EventClusterVersion = $EventCluster.version
$EventClusterName = $EventCluster.name
}
# Overriding Polaris in cluster name
IF($EventClusterName -eq "Polaris"){$EventClusterName = "RSC-Native"}
# Getting message
$EventInfo = $Event | Select-Object -ExpandProperty activityConnection -First 1 | Select-Object -ExpandProperty nodes 
$EventMessage = $EventInfo.message
# Getting detail
$EventDetail = $Event | Select-Object -ExpandProperty activityConnection -First 1 | Select-Object -ExpandProperty nodes | Select-Object -ExpandProperty activityInfo | ConvertFrom-JSON
$EventCDMInfo = $EventDetail.CdmInfo 
IF ($EventCDMInfo -ne $null){$EventCDMInfo = $EventCDMInfo | ConvertFrom-JSON}
# Getting params
$EventParams = $EventCDMInfo.params
$EventSnapshot = $EventParams.'${timestamp}'
$EventTarget = $EventParams.'${locationName}'
# Converting event times
$EventDateUTC = Convert-RSCUNIXTime $EventDateUNIX
IF($EventStartUNIX -ne $null){$EventStartUTC = Convert-RSCUNIXTime $EventStartUNIX}ELSE{$EventStartUTC = $null}
IF($EventEndUNIX -ne $null){$EventEndUTC = Convert-RSCUNIXTime $EventEndUNIX}ELSE{$EventEndUTC = $null}
# Calculating timespan if not null
IF (($EventStartUTC -ne $null) -and ($EventEndUTC -ne $null))
{
$EventRuntime = New-TimeSpan -Start $EventStartUTC -End $EventEndUTC
$EventMinutes = $EventRuntime | Select-Object -ExpandProperty TotalMinutes
$EventSeconds = $EventRuntime | Select-Object -ExpandProperty TotalSeconds
$EventDuration = "{0:g}" -f $EventRuntime
IF ($EventDuration -match "."){$EventDuration = $EventDuration.split('.')[0]}
}
ELSE
{
$EventMinutes = $null
$EventSeconds = $null
$EventDuration = $null
}
# Removing illegal SQL characters from object or message
IF($EventSnapshot -ne $null){$EventSnapshot = $EventSnapshot.Replace("'","")}
IF($EventObject -ne $null){$EventObject = $EventObject.Replace("'","")}
IF($EventLocation -ne $null){$EventLocation = $EventLocation.Replace("'","")}
IF($EventMessage -ne $null){$EventMessage = $EventMessage.Replace("'","")}
IF($EventErrorMessage -ne $null){$EventErrorMessage = $EventErrorMessage.Replace("'","")}
IF($EventErrorReason -ne $null){$EventErrorReason = $EventErrorReason.Replace("'","")}
# Deciding if on-demand or not
IF($EventMessage -match "on demand"){$IsOnDemand = $TRUE}ELSE{$IsOnDemand = $FALSE}
# Resetting to default not, only changing to yes if term matches the 2 variations
$IsLogBackup = $FALSE 
# Deciding if log backup or not
IF($EventMessage -match "transaction log"){$IsLogBackup = $TRUE}
# Deciding if log backup or not
IF($EventMessage -match "log backup"){$IsLogBackup = $TRUE}
# Excluding the below if logs disabled
IF(($ExcludeLogBackups) -and ($IsLogBackup -eq $TRUE)){$InsertRow = $FALSE}ELSE{$InsertRow = $TRUE}
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCURL
$Object | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $EventClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $EventClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Version" -Value $EventClusterVersion
# Object info
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $EventObject
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $EventObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $EventObjectCDMID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $EventObjectType
# Archive detail
$Object | Add-Member -MemberType NoteProperty -Name "Snapshot" -Value $EventSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "Target" -Value $EventTarget
# Summary of event
$Object | Add-Member -MemberType NoteProperty -Name "DateUTC" -Value $EventDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $EventType
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $EventStatus
$Object | Add-Member -MemberType NoteProperty -Name "Result" -Value $EventMessage
# Timing
$Object | Add-Member -MemberType NoteProperty -Name "StartUTC" -Value $EventStartUTC
$Object | Add-Member -MemberType NoteProperty -Name "EndUTC" -Value $EventEndUTC
$Object | Add-Member -MemberType NoteProperty -Name "Duration" -Value $EventDuration
$Object | Add-Member -MemberType NoteProperty -Name "DurationSeconds" -Value $EventSeconds
# Adding to array (optional, not needed)
# $RSCEvents.Add($Object) | Out-Null
############################
# Adding To SQL Table directly if no tempDB
############################
IF($DontUseTempDB)
{
$SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
-- Event & cluster IDs
RSCInstance, EventID, RubrikCluster, RubrikClusterID,

-- Object IDs & type
Object, ObjectID, ObjectCDMID, ObjectType,

-- Job info
Snapshot, Target,

-- Job timzone, date and summary
DateUTC, Type, Status, Result,

-- Job timing
JobStartUTC, JobEndUTC, Duration, DurationSeconds, Exported)
VALUES(
-- Event & cluster IDs
'$RSCInstance', '$EventID', '$EventClusterName', '$EventClusterID',

-- Object IDs & type
'$EventObject', '$EventObjectID', '$EventObjectCDMID', '$EventObjectType',

-- Job info
'$EventSnapshot', '$EventTarget',

-- Job timzone, date and summary
'$EventDateUTC', '$EventType', '$EventStatus', '$EventMessage',

-- Job timing
'$EventStartUTC', '$EventEndUTC', '$EventDuration', '$EventSeconds','FALSE');"
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
-- Event & cluster IDs
RSCInstance, EventID, RubrikCluster, RubrikClusterID,

-- Object IDs & type
Object, ObjectID, ObjectCDMID, ObjectType,

-- Job info
Snapshot, Target,

-- Job timzone, date and summary
DateUTC, Type, Status, Result,

-- Job timing
JobStartUTC, JobEndUTC, Duration, DurationSeconds, Exported)
VALUES(
-- Event & cluster IDs
'$RSCInstance', '$EventID', '$EventClusterName', '$EventClusterID',

-- Object IDs & type
'$EventObject', '$EventObjectID', '$EventObjectCDMID', '$EventObjectType',

-- Job info
'$EventSnapshot', '$EventTarget',

-- Job timzone, date and summary
'$EventDateUTC', '$EventType', '$EventStatus', '$EventMessage',

-- Job timing
'$EventStartUTC', '$EventEndUTC', '$EventDuration', '$EventSeconds','FALSE');"
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
#
# Logging
Write-Host "ProcessedObject:$ProtectedObjectsCounter/$ProtectedObjectsCount EventsReturnedByAPI:$RSCEventsListCount"
# End of for each object below
}
# End of for each object above
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
            Target.Result = Source.Result, 
			Target.JobStartUTC = Source.JobStartUTC,
            Target.JobEndUTC = Source.JobEndUTC, 
            Target.Duration = Source.Duration,
            Target.DurationSeconds = Source.DurationSeconds
            Target.Exported = Source.Exported
WHEN NOT MATCHED BY TARGET
THEN INSERT (RSCInstance, EventID, RubrikCluster, RubrikClusterID,
            Object, ObjectID, ObjectCDMID, ObjectType,
            Snapshot, Target,
            DateUTC, Type, Status, Result,
            JobStartUTC, JobEndUTC, Duration, DurationSeconds,Exported)
     VALUES (Source.RSCInstance, Source.EventID, Source.RubrikCluster, Source.RubrikClusterID,
            Source.Object, Source.ObjectID, Source.ObjectCDMID, Source.ObjectType,
            Source.Snapshot, Source.Target,
            Source.DateUTC, Source.Type, Source.Status, Source.Result,
            Source.JobStartUTC, Source.JobEndUTC, Source.Duration, Source.DurationSeconds,Source.Exported);"
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