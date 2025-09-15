################################################
# Function - Get-RSCEventsBackup - Getting all RSC Backup events
################################################
Function Get-RSCEventsBackup {

<#
.SYNOPSIS
Returns all RSC backup events within the time frame specified, default is 24 hours with no parameters.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference
The ActivitySeriesConnection type: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference/activityseriesconnection.doc.html

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
.PARAMETER ExcludeLogBackups
Removes all log backup events.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCEventsBackup
This example returns all backup events within a 24 hour period as no paramters were set.

.EXAMPLE
Get-RSCEventsBackup -DaysToCapture 30
This example returns all backup events within a 30 day period.

.EXAMPLE
Get-RSCEventsBackup -DaysToCapture 30 -LastActivityStatus "FAILED" -ObjectType "VMwareVirtualMachine"
This example returns all failed backup events within 30 days for VMwareVirtualMachines.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]$DaysToCapture,
        [Parameter(Mandatory=$false)]$HoursToCapture,
        [Parameter(Mandatory=$false)]$MinutesToCapture,
        [Parameter(Mandatory=$false)]$LastActivityStatus,
        [Parameter(Mandatory=$false)]$ObjectType,
        [Parameter(Mandatory=$false)]$ObjectName,
        [Parameter(Mandatory=$false)]$FromDate,
        [Parameter(Mandatory=$false)]$ToDate,
        [Parameter(Mandatory=$false)]$EventLimit,
        [switch]$AddWarningsToErrorMessage,
        [switch]$ExcludeLogBackups,
        [switch]$Logging
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# If event limit null, setting to value
IF($EventLimit -eq $null){$EventLimit = 999}ELSE{$EventLimit = [int]$EventLimit}
# Overriding to 50 if user wants the warnings otherwise it won't have the event depth required to pull the data
IF($AddWarningsToErrorMessage){$MessageDepth = 50}ELSE{$MessageDepth = 1}
################################################
# Getting times required
################################################
$ScriptStart = Get-Date
$MachineDateTime = Get-Date
$UTCDateTime = [System.DateTime]::UtcNow
# If null, setting to 24 hours
IF(([string]::IsNullOrEmpty($MinutesToCapture)) -and ([string]::IsNullOrEmpty($HoursToCapture)))
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
Write-Error "ERROR: FromDate specified is not a valid DateTime object. Use this format instead: 08/14/2023 23:00:00"
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
Write-Error "ERROR: ToDate specified is not a valid DateTime object. Use this format instead: 08/14/2023 23:00:00"
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
IF($Logging)
{
Write-Host "----------------------------------
CollectingEventsFrom(UTC): $TimeRangeFromUTC
CollectingEventsTo(UTC): $TimeRangeToUTC
----------------------------------
Querying RSC API..."
Start-Sleep 1
}
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
        activityConnection(first: $MessageDepth) {
          nodes {
            id
            message
            __typename
            activityInfo
            status
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
# Querying API
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-JSON -Depth 32) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges.node
# Counters
$RSCEventsListCountStart = 0
$RSCEventsListCountEnd = $EventLimit
# Logging
IF($Logging){Write-Host "CollectingEvents: $RSCEventsListCountStart-$RSCEventsListCountEnd"}
# Getting all results from paginations
While($RSCEventsResponse.data.activitySeriesConnection.pageInfo.hasNextPage) 
{
# Incrementing
$RSCEventsListCountStart = $RSCEventsListCountStart + $EventLimit
$RSCEventsListCountEnd = $RSCEventsListCountEnd + $EventLimit
# Logging
IF($Logging){Write-Host "CollectingEvents: $RSCEventsListCountStart-$RSCEventsListCountEnd"}
# Setting after variable, querying API again, adding to array
$RSCEventsJSONObject.variables | Add-Member -MemberType NoteProperty "after" -Value $RSCEventsResponse.data.activitySeriesConnection.pageInfo.endCursor -Force
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges.node
}
# Removing queued events
$RSCEventsList = $RSCEventsList | Where-Object {$_.lastActivityStatus -ne "Queued"}
# Removing running - logging this to SQL will then fail to update when complete as the event ID is the same
$RSCEventsList = $RSCEventsList | Where-Object {$_.lastActivityStatus -ne "Running"}
# Counting
$RSCEventsCount = $RSCEventsList | Measure-Object | Select-Object -ExpandProperty Count
$RSCObjectsList = $RSCEventsList | Select-Object ObjectId -Unique
# Logging
IF($Logging)
{
Write-Host "----------------------------------
EventsReturnedByAPI: $RSCEventsCount
----------------------------------
Processing.."
}
################################################
# Processing Events
################################################
# Creating array
$RSCEvents = [System.Collections.ArrayList]@()
$RSCEventsCounter = 0
# For Each Getting info
ForEach ($Event in $RSCEventsList)
{
# Incrementing & Logging
$RSCEventsCounter ++
IF($Logging){$Date = Get-Date; Write-Host "$Date - ProcessingEvents: $RSCEventsCounter/$RSCEventsCount"}
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
# Getting error detail
$EventDetail = $Event | Select-Object -ExpandProperty activityConnection -First 1 | Select-Object -ExpandProperty nodes | Select-Object -ExpandProperty activityInfo | ConvertFrom-JSON
$EventCDMInfo = $EventDetail.CdmInfo 
IF ($EventCDMInfo -ne $null){$EventCDMInfo = $EventCDMInfo | ConvertFrom-JSON}
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
IF($EventDuration -match "."){$EventDuration = $EventDuration.split('.')[0]}
}
ELSE
{
$EventMinutes = $null
$EventSeconds = $null
$EventDuration = $null
}
# Override for warning message if configured
IF($AddWarningsToErrorMessage)
{
# Override for partial success to get the top warning
IF([string]::IsNullOrEmpty($EventErrorMessage))
{
$EventErrorMessage = $Event | Select-Object -ExpandProperty activityConnection | Select-Object -ExpandProperty nodes | Where-Object {$_.Status -eq "PARTIAL_SUCCESS"} | Select-Object -ExpandProperty message -First 1
}
# If null, could be an actual partial success warning in the messages
IF([string]::IsNullOrEmpty($EventErrorMessage))
{
$EventErrorMessage = $Event | Select-Object -ExpandProperty activityConnection | Select-Object -ExpandProperty nodes | Where-Object {$_.Status -eq "Warning"} | Select-Object -ExpandProperty message -First 1
}
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
# Location override if null and Get-RSCOracleDatabases has been run
IF(($EventLocation -eq "") -and ($RSCOracleDatabases -ne $null))
{
$EventLocation = $RSCOracleDatabases | Where-Object {(($_.DataGuardGroupID -eq $EventObjectID) -and ($_.DB -eq $EventObject))} | Select-Object -ExpandProperty Host -First 1
}
# Overriding canceled spelling error on API
IF($EventStatus -eq "Canceled")
{
$EventStatus = "Cancelled"
$EventMessage = $EventMessage.Replace('Canceled','Cancelled')
}
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
# Object info
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $EventObject
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $EventObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $EventObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $EventLocation
# Summary of event
$Object | Add-Member -MemberType NoteProperty -Name "DateUTC" -Value $EventDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $EventType
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $EventStatus
$Object | Add-Member -MemberType NoteProperty -Name "Message" -Value $EventMessage
# Timing
$Object | Add-Member -MemberType NoteProperty -Name "StartUTC" -Value $EventStartUTC
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
# Cluster info
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $EventClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $EventClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Version" -Value $EventClusterVersion
$Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $EventObjectCDMID
# Adding to array
IF($InsertRow -eq $TRUE){$RSCEvents.Add($Object) | Out-Null}
# $RSCEvents.Add($Object) | Out-Null
# End of for each event below
}
# End of for each event above

# Returning array
Return $RSCEvents
# End of function
}
