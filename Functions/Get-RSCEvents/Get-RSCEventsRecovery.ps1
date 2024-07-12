################################################
# Function - Get-RSCEventsRecovery - Getting all RSC Recovery events
################################################
Function Get-RSCEventsRecovery {

<#
.SYNOPSIS
Returns all RSC recovery events within the time frame specified, default is 24 hours with no parameters.

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

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCEventsRecovery
This example returns all recovery events within a 24 hour period as no paramters were set.

.EXAMPLE
Get-RSCEventsRecovery -DaysToCapture 30
This example returns all recovery events within a 30 day period.

.EXAMPLE
Get-RSCEventsRecovery -DaysToCapture 30 -LastActivityStatus "FAILED" -ObjectType "VMwareVirtualMachine"
This example returns all failed recovery events within 30 days for VMwareVirtualMachines.

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
        [Parameter(Mandatory=$false)]$ToDate
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
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
Write-Host "----------------------------------
CollectingEventsFrom(UTC): $TimeRangeFromUTC
CollectingEventsTo(UTC): $TimeRangeToUTC
----------------------------------
Querying RSC API..."
Start-Sleep 1
################################################
# Getting RSC Events
################################################
$lastActivityType = "RECOVERY"
# Creating array for events
$RSCEventsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "EventSeriesListQuery";

"variables" = @{
"filters" = @{
    "lastUpdatedTimeGt" = "$TimeRangeFromUNIX"
	"lastUpdatedTimeLt" = "$TimeRangeToUNIX"
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
# Getting all results from paginations
While($RSCEventsResponse.data.activitySeriesConnection.pageInfo.hasNextPage) 
{
# Setting after variable, querying API again, adding to array
$RSCEventsJSONObject.variables | Add-Member -MemberType NoteProperty "after" -Value $RSCEventsResponse.data.activitySeriesConnection.pageInfo.endCursor -Force
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges.node
}
# Counting
$RSCEventsCount = $RSCEventsList | Measure-Object | Select-Object -ExpandProperty Count
$RSCObjectsList = $RSCEventsList | Select-Object ObjectId -Unique
# Logging
Write-Host "EventsReturnedByAPI: $RSCEventsCount"
################################################
# Processing Events
################################################
$RSCEvents = [System.Collections.ArrayList]@()
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
# Getting transfer info
$EventThroughputBytes = $Event.effectiveThroughput
$EventDataTransferredBytes = $Event.dataTransferred
# If not null converting to MB
IF($EventThroughputBytes -ne $null)
{
$EventThroughputMB = $EventThroughputBytes / 1000 / 1000
IF($EventThroughputMB -lt 10){$EventThroughputMB = [Math]::Round($EventThroughputMB,2)}ELSE{$EventThroughputMB = [Math]::Round($EventThroughputMB)}
}
ELSE{$EventThroughputMB = $null}
IF($EventDataTransferredBytes -ne $null)
{
$EventDataTransferredMB = $EventDataTransferredBytes / 1000 / 1000
IF($EventDataTransferredMB -lt 10){$EventDataTransferredMB = [Math]::Round($EventDataTransferredMB,2)}ELSE{$EventDataTransferredMB = [Math]::Round($EventDataTransferredMB)}
}
ELSE{$EventDataTransferredMB = $null}
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
$Object | Add-Member -MemberType NoteProperty -Name "StarUTC" -Value $EventStartUTC
$Object | Add-Member -MemberType NoteProperty -Name "EndUTC" -Value $EventEndUTC
$Object | Add-Member -MemberType NoteProperty -Name "Duration" -Value $EventDuration
$Object | Add-Member -MemberType NoteProperty -Name "DurationSeconds" -Value $EventSeconds
# Data transferred
$Object | Add-Member -MemberType NoteProperty -Name "ThroughputMB" -Value $EventThroughputMB
$Object | Add-Member -MemberType NoteProperty -Name "TransferredMB" -Value $EventDataTransferredMB
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
# Adding to array (optional, not needed)
$RSCEvents.Add($Object) | Out-Null
# End of for each event below
}
# End of for each event above

# Returning array
Return $RSCEvents
# End of function
}
