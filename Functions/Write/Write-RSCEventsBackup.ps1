################################################
# Function - Write-RSCEventsBackup - Inserting all RSC Backup events into SQL
################################################
Function Write-RSCEventsBackup {

<#
.SYNOPSIS
Collects the event type specified and writes them to an existing MS SQL databse of your choosing, if not specified the default table name RSCEventsBackup will created (so you don't need to know the required structure).

.DESCRIPTION
Requires the Sqlserver PowerShell module to be installed, connects and writes RSC evevents into the MS SQL server and DB specified as the user running the script (ensure you have sufficient SQL permissions), creates the required table structure if required. Ensure the DB already exists but the table does not on first run (so it can create it). It uses permanent tables in tempdb for scale (as each Invoke-SQLCmd is a unique connection), this can be disabled with the DontUseTempDB switch.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SQLInstance
The SQL server and instance name (if required) to connect to your MS SQL server. Ensure the user running the script has permission to connect, recommended to check using MS SQL Mgmt Studio first.
.PARAMETER SQLDB
The SQL database in which to create the required table to write the events. This must already exist, it will not create the database for you.
.PARAMETER SQLTable
Not required, it will create a table called RSCEventsBackup for you, but you can customize the name (not the structure). Has to not already exist on 1st run unless you already used the correct structure. 
.PARAMETER DontUseTempDB
Switch to disable use of TempDB for scale. Use if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.
.PARAMETER DaysToCapture
The number of days to get events from, overrides all others, recommended to not go back too far without also specifying filters on LastActivityType, LastActivityStatus etc due to number of events.
.PARAMETER HoursToCapture
The number of hours to get events from, use instead of days if you want to be more granular.
.PARAMETER MinutesToCapture
The number of minutes to get events from, use instead of hours if you want to be even more granular.
.PARAMETER FromDate
Alternative to Days/Hours/Minutes, specicy a from date in the format 08/14/2023 23:00:00 to only collect events from AFTER this date.
.PARAMETER ToDate
Alternative to Days/Hours/Minutes, specicy a To date in the format 08/14/2023 23:00:00 to only collect events from BEFORE this date. Will always be UTCNow if null.
.PARAMETER LastActivityStatus
Set the required status of events, has to be from the schema link, you can also try not specifying this, then use EventStatus on the array to get a valid list of LastActivityStatus.
.PARAMETER ObjectType
Set the required object type of the events, has to be be a valid object type from the schema link, you can also try not specifying this, then use ObjectType on the array to get a valid list of ObjectType.
.PARAMETER ObjectName
Set the required object name of the events, has to be be a valid object name, you can also try not specifying this, then use Object on the array to get a valid list of ObjectName.

.OUTPUTS
None, all the events are written into the MS SQL DB specified.

.EXAMPLE
Write-RSCEventsBackup -SQLInstance "localhost" -SQLDB "YourDBName"
This example collects all events from the default last 24 hours and writes them into a table named RSCEventsBackup that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEventsBackup -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30
This example collects all events from the default last 30 days and writes them into a table named RSCEventsBackup that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEventsBackup -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30 -SQLTable "YourTableName"
This example collects all events from the default last 30 days and writes them into a table named MyTableName that it will create on first run with the required structure in the database RSCReprting.

.EXAMPLE
Write-RSCEventsBackup -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30 -SQLTable "YourTableName" -DontUseTempDB
As above, but doesn't use regular tables in TempDB if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.

.EXAMPLE
Write-RSCEventsBackup -SQLInstance "localhost" -SQLDB "YourDBName" -DaysToCapture 30 -SQLTable "YourTableName" -LastActivityStatus "FAILED"
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
        [Parameter(Mandatory=$false)]$EventLimit,
        [Switch]$ExcludeLogBackups,
        [Switch]$ExcludeRunningJobs,
        [Switch]$DontUseTempDB
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Checking SQL module
Test-RSCSQLModule
# If event limit null, setting to value
IF($EventLimit -eq $null){$EventLimit = 999}ELSE{$EventLimit = [int]$EventLimit}
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
IF($SQLTable -eq $null){$SQLTable = "RSCEventsBackup"}
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
$Date = Get-Date
Write-Host "----------------------------------
$Date - SQLTableNotFound
$Date - CreatingSQLTable: $SQLTable"
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
    [Location] [varchar](max) NULL,
	[DateUTC] [datetime] NULL,
	[Type] [varchar](max) NULL,
	[Status] [varchar](50) NULL,
	[Message] [varchar](max) NULL,
	[JobStartUTC] [datetime] NULL,
	[JobEndUTC] [datetime] NULL,
	[Duration] [varchar](50) NULL,
	[DurationSeconds] [varchar](50) NULL,
    [LogicalSizeMB] [int] NULL,
	[TransferredMB] [int] NULL,
	[ThroughputMB] [int] NULL,
    [LogicalSizeBytes] [bigint] NULL,
    [TransferredBytes] [bigint] NULL,
	[ThroughputBytes] [bigint] NULL,
	[ErrorCode] [varchar](50) NULL,
	[ErrorMessage] [varchar](max) NULL,
	[ErrorReason] [varchar](max) NULL,
    [IsOnDemand] [varchar](5) NULL,
    [IsLogBackup] [varchar](5) NULL,
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
$Date = Get-Date
Write-Host "----------------------------------
$Date - CreatingTableInTempDB: $TempTableName"
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
$TimeRangeFromUTC = $UTCDateTime.AddHours(-$HoursToCapture)
$TimeRange = $MachineDateTime.AddHours(-$HoursToCapture)
}
# Calculating time range if minutes specified
IF($MinutesToCapture -ne $null)
{
$TimeRangeFromUTC = $UTCDateTime.AddMinutes(-$MinutesToCapture)
$TimeRange = $MachineDateTime.AddMinutes(-$MinutesToCapture)
# Overring hours if minutes specified
$HoursToCapture = 60 / $MinutesToCapture
$HoursToCapture = [Math]::Round($HoursToCapture,2)
}
# Overriding both if days to capture specified
IF($DaysToCapture -ne $null)
{
$TimeRangeFromUTC = $UTCDateTime.AddDays(-$DaysToCapture)
$TimeRange = $MachineDateTime.AddDays(-$DaysToCapture)	
}
######################
# Overriding if FromDate Used
######################
IF($FromDate -ne $null)
{
# Checking valid date object
$ParamType = $FromDate.GetType().Name
# If not valid date time, trying to convert
IF($ParamType -ne "DateTime"){$FromDate = [datetime]$FromDate;$ParamType = $FromDate.GetType().Name}
# If still not a valid datetime object, breaking
IF($ParamType -ne "DateTime")
{
Write-Error "$Date - ERROR: FromDate specified is not a valid DateTime object. Use this format instead: 08/14/2023 23:00:00"
Start-Sleep 2
Break
}
# Setting TimeRangeUTC to be FromDate specified
$TimeRangeFromUTC = $FromDate
}
######################
# Overriding if ToDate Used, setting to UTCDateTime if null
######################
IF($ToDate -ne $null)
{
# Checking valid date object
$ParamType = $ToDate.GetType().Name
# If not valid date time, trying to convert
IF($ParamType -ne "DateTime"){$ToDate = [datetime]$ToDate;$ParamType = $ToDate.GetType().Name}
# If still not a valid datetime object, breaking
IF($ParamType -ne "DateTime")
{
Write-Error "$Date - ERROR: ToDate specified is not a valid DateTime object. Use this format instead: 08/14/2023 23:00:00"
Start-Sleep 2
Break
}
# Setting TimeRangeUTC to be ToDate specified
$TimeRangeToUTC = $ToDate
}
ELSE
{
$TimeRangeToUTC = $UTCDateTime
}
######################
# Converting DateTime to Required Formats & Logging
######################
# Converting to UNIX time format
$TimeRangeFromUNIX = $TimeRangeFromUTC.ToString("yyyy-MM-ddTHH:mm:ss.000Z")
$TimeRangeToUNIX = $TimeRangeToUTC.ToString("yyyy-MM-ddTHH:mm:ss.000Z")
# Logging
$Date = Get-Date
Write-Host "----------------------------------
HoursToCapture: $HoursToCapture
CollectingEventsFrom(UTC): $TimeRangeFromUTC
CollectingEventsTo(UTC): $TimeRangeToUTC
SQLDB: $SQLDB
SQLTable: $SQLTable
ObjectType: $ObjectType
----------------------------------
$Date - Querying RSC API..."
Start-Sleep 1
################################################
# Getting RSC Events
################################################
# Hard coding event type 
$lastActivityType = "BACKUP"
# Creating array for events
$RSCEventsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "EventSeriesListQuery";

"variables" = @{
"filters" = @{
    "lastUpdatedTimeGt" = "$TimeRangeFromUNIX"
	"lastUpdatedTimeLt" = "$TimeRangeToUNIX"
  }
"first" = $EventLimit
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
  effectiveThroughput
  dataTransferred
  logicalSize
  objectType
  severity
  progress
  isCancelable
  isPolarisEventSeries
  startTime
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
IF($lastActivityType -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "lastActivityType" -Value $lastActivityType}
IF($lastActivityStatus -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "lastActivityStatus" -Value $lastActivityStatus}
IF($objectType -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "objectType" -Value $objectType}
IF($objectName -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "objectName" -Value $objectName}
################################################
# API Call To RSC GraphQL URI
################################################
# Counters
$RSCEventsListCountStart = 0
$RSCEventsListCountEnd = $EventLimit
# Logging
$Date = Get-Date; Write-Host "$Date - CollectingEvents: $RSCEventsListCountStart-$RSCEventsListCountEnd"
# Querying API
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-JSON -Depth 32) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges.node
# Getting all results from paginations
While($RSCEventsResponse.data.activitySeriesConnection.pageInfo.hasNextPage) 
{
# Counting
$RSCEventsListCountStart = $RSCEventsListCountStart + $EventLimit
$RSCEventsListCountEnd = $RSCEventsListCountEnd + $EventLimit
# Logging
$Date = Get-Date; Write-Host "$Date - CollectingEvents: $RSCEventsListCountStart-$RSCEventsListCountEnd"
# Setting after variable, querying API again, adding to array
$RSCEventsJSONObject.variables | Add-Member -MemberType NoteProperty "after" -Value $RSCEventsResponse.data.activitySeriesConnection.pageInfo.endCursor -Force
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges.node
}
# Removing queued events
$RSCEventsList = $RSCEventsList | Where-Object {$_.lastActivityStatus -ne "Queued"}
# Removing running jobs if switch used
IF($ExcludeRunningJobs)
{
$RSCEventsList = $RSCEventsList | Where-Object {$_.lastActivityStatus -ne "Running"}
}
# Counting
$RSCEventsCount = $RSCEventsList | Measure-Object | Select-Object -ExpandProperty Count
$RSCObjectsList = $RSCEventsList | Select-Object ObjectId -Unique
# Logging
$Date = Get-Date
Write-Host "----------------------------------
$Date - EventsReturnedByAPI: $RSCEventsCount
----------------------------------
$Date - Processing..."
################################################
# Processing Events
################################################
$RSCEvents = [System.Collections.ArrayList]@()
$RSCEventsCounter = 0
# For Each Getting info
ForEach ($Event in $RSCEventsList)
{
# Incrementing
$RSCEventsCounter ++
# Logging
$Date = Get-Date; Write-Host "$Date - ProcessingEvents: $RSCEventsCounter/$RSCEventsCount"
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
# Job metrics
$EventTransferredBytes = $Event.dataTransferred
$EventThroughputBytes = $Event.effectiveThroughput
$EventLogicalSizeBytes = $Event.logicalSize
# Converting bytes to MB
IF($EventTransferredBytes -ne $null){$EventTransferredMB = $EventTransferredBytes / 1000 / 1000; $EventTransferredMB = [Math]::Round($EventTransferredMB)}ELSE{$EventTransferredMB = $null}
IF($EventThroughputBytes -ne $null){$EventThroughputMB = $EventThroughputBytes / 1000 / 1000; $EventThroughputMB = [Math]::Round($EventThroughputMB)}ELSE{$EventThroughputMB = $null}
IF($EventLogicalSizeBytes -ne $null){$EventLogicalSizeMB = $EventLogicalSizeBytes / 1000 / 1000; $EventLogicalSizeMB = [Math]::Round($EventLogicalSizeMB)}ELSE{$EventLogicalSizeMB = $null}
# Getting cluster info
$EventCluster = $Event.cluster
# Only processing if not null, could be cloud native
IF($EventCluster -ne $null)
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
# Getting error detail
$EventDetail = $Event | Select-Object -ExpandProperty activityConnection -First 1 | Select-Object -ExpandProperty nodes | Select-Object -ExpandProperty activityInfo | ConvertFrom-JSON
$EventCDMInfo = $EventDetail.CdmInfo 
IF($EventCDMInfo -ne $null){$EventCDMInfo = $EventCDMInfo | ConvertFrom-JSON}
$EventErrorCause = $EventCDMInfo.cause
$EventErrorCode = $EventErrorCause.errorCode
$EventErrorMessage = $EventErrorCause.message
$EventErrorReason = $EventErrorCause.reason
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
# Enabling insert
$InsertRow = $TRUE
# If exclude log backups disabling insert
IF(($ExcludeLogBackups) -and ($IsLogBackup -eq $TRUE)){$InsertRow = $FALSE}
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $EventClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $EventClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Version" -Value $EventClusterVersion
# Object info
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $EventObject
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $EventObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $EventObjectCDMID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $EventObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $EventLocation
# Summary of event
$Object | Add-Member -MemberType NoteProperty -Name "DateUTC" -Value $EventDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $EventType
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $EventStatus
$Object | Add-Member -MemberType NoteProperty -Name "Message" -Value $EventMessage
# Timing
$Object | Add-Member -MemberType NoteProperty -Name "StarUTC" -Value $EventStartUTC
$Object | Add-Member -MemberType NoteProperty -Name "EndUTC" -Value $EventEndUTC
$Object | Add-Member -MemberType NoteProperty -Name "Duration" -Value $EventDuration
$Object | Add-Member -MemberType NoteProperty -Name "DurationSeconds" -Value $EventSeconds
# Job metrics
$Object | Add-Member -MemberType NoteProperty -Name "LogicalSizeMB" -Value $EventLogicalSizeMB
$Object | Add-Member -MemberType NoteProperty -Name "TransferredMB" -Value $EventTransferredMB
$Object | Add-Member -MemberType NoteProperty -Name "ThroughputMB" -Value $EventThroughputMB
$Object | Add-Member -MemberType NoteProperty -Name "LogicalSizeBytes" -Value $EventLogicalSizeBytes
$Object | Add-Member -MemberType NoteProperty -Name "TransferredBytes" -Value $EventTransferredBytes
$Object | Add-Member -MemberType NoteProperty -Name "ThroughputBytes" -Value $EventThroughputBytes
# Failure detail
$Object | Add-Member -MemberType NoteProperty -Name "ErrorCode" -Value $EventErrorCode
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $EventErrorMessage
$Object | Add-Member -MemberType NoteProperty -Name "ErrorReason" -Value $EventErrorReason
# Misc info
$Object | Add-Member -MemberType NoteProperty -Name "IsOnDemand" -Value $IsOnDemand
$Object | Add-Member -MemberType NoteProperty -Name "IsLogBackup" -Value $IsLogBackup
# Adding to array (optional, not needed)
IF($InsertRow -eq $TRUE){$RSCEvents.Add($Object) | Out-Null}
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
Object, ObjectID, ObjectCDMID, ObjectType, Location,

-- Job timzone, date and summary
DateUTC, Type, Status, Message,

-- Job timing
JobStartUTC, JobEndUTC, Duration, DurationSeconds,

-- Job metrics
LogicalSizeMB, TransferredMB, ThroughputMB, LogicalSizeBytes, TransferredBytes, ThroughputBytes,

-- Job error info, if failure, on-demand 
ErrorCode, ErrorMessage, ErrorReason, IsOnDemand, IsLogBackup, Exported)
VALUES(
-- Event & cluster IDs
'$RSCInstance', '$EventID', '$EventClusterName', '$EventClusterID',

-- Object IDs & type
'$EventObject', '$EventObjectID', '$EventObjectCDMID', '$EventObjectType', '$EventLocation',

-- Job timzone, date and summary
'$EventDateUTC', '$EventType', '$EventStatus', '$EventMessage',

-- Job timing
'$EventStartUTC', '$EventEndUTC', '$EventDuration', '$EventSeconds',

-- Job metrics
'$EventLogicalSizeMB', '$EventTransferredMB', '$EventThroughputMB', '$EventLogicalSizeBytes', '$EventTransferredBytes', '$EventThroughputBytes',

-- Job error info, if failure
'$EventErrorCode', '$EventErrorMessage', '$EventErrorReason', '$IsOnDemand', '$IsLogBackup', 'FALSE');"
# Inserting
Try
{
IF($InsertRow -eq $TRUE){Invoke-SQLCmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null}
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
Object, ObjectID, ObjectCDMID, ObjectType, Location,

-- Job timzone, date and summary
DateUTC, Type, Status, Message,

-- Job timing
JobStartUTC, JobEndUTC, Duration, DurationSeconds,

-- Job metrics
LogicalSizeMB, TransferredMB, ThroughputMB, LogicalSizeBytes, TransferredBytes, ThroughputBytes,

-- Job error info, if failure, on-demand 
ErrorCode, ErrorMessage, ErrorReason, IsOnDemand, IsLogBackup, Exported)
VALUES(
-- Event & cluster IDs
'$RSCInstance', '$EventID', '$EventClusterName', '$EventClusterID',

-- Object IDs & type
'$EventObject', '$EventObjectID', '$EventObjectCDMID', '$EventObjectType', '$EventLocation',

-- Job timzone, date and summary
'$EventDateUTC', '$EventType', '$EventStatus', '$EventMessage',

-- Job timing
'$EventStartUTC', '$EventEndUTC', '$EventDuration', '$EventSeconds',

-- Job metrics
'$EventLogicalSizeMB', '$EventTransferredMB', '$EventThroughputMB', '$EventLogicalSizeBytes', '$EventTransferredBytes', '$EventThroughputBytes',

-- Job error info, if failure
'$EventErrorCode', '$EventErrorMessage', '$EventErrorReason', '$IsOnDemand', '$IsLogBackup', 'FALSE');"
# Inserting
Try
{
IF($InsertRow -eq $TRUE){Invoke-SQLCmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null}
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
$Date = Get-Date
Write-Host "----------------------------------
$Date - Finished Processing RSC Events
----------------------------------"
############################
# Removing Duplicates if not using TempDB
############################
IF($DontUseTempDB)
{
# Logging
$Date = Get-Date
Write-Host "$Date - RemovingDuplicatEventsFrom: $SQLTable
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
$Date = Get-Date
Write-Host "$Date - MergingTableInTempDB: $TempTableName"
Start-Sleep 3
# Creating SQL query
$SQLMergeTable = "MERGE $SQLDB.dbo.$SQLTable Target
USING tempdb.dbo.$TempTableName Source
ON (Target.EventID = Source.EventID)
WHEN MATCHED 
     THEN UPDATE
     SET    Target.DateUTC = Source.DateUTC,
            Target.Status = Source.Status,
            Target.Message = Source.Message, 
			Target.JobStartUTC = Source.JobStartUTC,
            Target.JobEndUTC = Source.JobEndUTC, 
            Target.Duration = Source.Duration,
            Target.DurationSeconds = Source.DurationSeconds,
            Target.LogicalSizeMB = Source.LogicalSizeMB,
            Target.TransferredMB = Source.TransferredMB,
            Target.ThroughputMB = Source.ThroughputMB,
            Target.LogicalSizeBytes = Source.LogicalSizeBytes,
            Target.TransferredBytes = Source.TransferredBytes,
            Target.ThroughputBytes = Source.DurationSeconds,
            Target.ErrorCode = Source.ErrorCode, 
            Target.ErrorMessage = Source.ErrorMessage,
            Target.ErrorReason = Source.ErrorReason, 
            Target.Exported = Source.Exported
WHEN NOT MATCHED BY TARGET
THEN INSERT (RSCInstance, EventID, RubrikCluster, RubrikClusterID,
            Object, ObjectID, ObjectCDMID, ObjectType, Location,
            DateUTC, Type, Status, Message,
            JobStartUTC, JobEndUTC, Duration, DurationSeconds,
            LogicalSizeMB, TransferredMB, ThroughputMB, LogicalSizeBytes, TransferredBytes, ThroughputBytes,
            ErrorCode, ErrorMessage, ErrorReason, IsOnDemand, IsLogBackup, Exported)
     VALUES (Source.RSCInstance, Source.EventID, Source.RubrikCluster, Source.RubrikClusterID,
            Source.Object, Source.ObjectID, Source.ObjectCDMID, Source.ObjectType, Source.Location,
            Source.DateUTC, Source.Type, Source.Status, Source.Message,
            Source.JobStartUTC, Source.JobEndUTC, Source.Duration, Source.DurationSeconds,
            Source.LogicalSizeMB, Source.TransferredMB, Source.ThroughputMB, Source.LogicalSizeBytes, Source.TransferredBytes, Source.ThroughputBytes,
            Source.ErrorCode, Source.ErrorMessage, Source.ErrorReason, Source.IsOnDemand, Source.IsLogBackup, Source.Exported);"
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
$Date = Get-Date
Write-Host "----------------------------------
$Date - DroppedTableInTempDB: $TempTableName
----------------------------------"
}
ELSE
{
# Logging
$Date = Get-Date
Write-Host "----------------------------------
$Date - NotDroppedTableInTempDB: $TempTableName
$Date - SQLMergeSuccess: $SQLMergeSuccess
----------------------------------"	
}
Start-Sleep 2
# End of bypass for using tempDB below
}
# End of bypass for using tempDB above
##########################
# Benching
##########################
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
Runtime: $ScriptDuration"
# Returning null
Return $null
# End of function
}

