################################################
# Function - Get-RSCEventsHardware - Getting all RSC Hardware events
################################################
Function Get-RSCEventsHardware {

<#
.SYNOPSIS
Returns all RSC cluster hardware events within the time frame specified, default is 24 hours with no parameters.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER DaysToCapture
The number of days to get events from, overrides all others, recommended to not go back too far without also specifying filters on LastActivityType, LastActivityStatus etc due to number of events.
.PARAMETER HoursToCapture
The number of hours to get events from, use instead of days if you want to be more granular.
.PARAMETER MinutesToCapture
The number of minutes to get events from, use instead of hours if you want to be even more granular.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCEventsHardware
This example returns all events within a 24 hour period as no paramters were set.

.EXAMPLE
Get-RSCEventsHardware -DaysToCapture 30
This example returns all events within a 30 day period.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
	Param
    (
        $DaysToCapture,$HoursToCapture,$MinutesToCapture,[switch]$Silent
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
IF($Silent -eq $null)
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
$LastActivityType = "HARDWARE"
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
IF($LastActivityType -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "lastActivityType" -Value $LastActivityType}
################################################
# API Call To RSC GraphQL URI
################################################
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
# Counting
$RSCEventsCount = $RSCEventsList | Measure-Object | Select-Object -ExpandProperty Count
$RSCObjectsList = $RSCEventsList | Select-Object ObjectId -Unique
# Logging
IF($Silent -eq $null)
{
Write-Host "EventsReturnedByAPI: $RSCEventsCount"
}
################################################
# Processing Events
################################################
$RSCEvents = [System.Collections.ArrayList]@()
# For Each Getting info
ForEach ($Event in $RSCEventsList)
{
# Setting variables
$EventID = $Event.activitySeriesId
$EventObjectFID = $Event.fid
$EventObjectID = $Event.objectId
$EventObject = $Event.objectName
$EventObjectType = $Event.objectType
$EventType = $Event.lastActivityType
$EventLocation = $Event.location
$EventSeverity = $Event.severity
$EventStatus = $Event.lastActivityStatus
$EventDateUNIX = $Event.lastUpdated
$EventStartUNIX = $Event.startTime
$EventEndUNIX = $EventDateUNIX
# Getting hardware error detail
$EventActivity = $Event.activityConnection.nodes
$EventErrorMessage = $EventActivity.message
$EventActivityInfo = $EventActivity.activityInfo | ConvertFrom-Json | Select -ExpandProperty CdmInfo | ConvertFrom-Json
$EventErrorCode = $EventActivityInfo.cause.errorCode
$EventMessage = $EventActivityInfo.cause.message
$EventErrorRemedy = $EventActivityInfo.cause.remedy
$EventErrorNode = $EventActivityInfo.params | Select -ExpandProperty '${nodeId}'
# Getting cluster info
$EventCluster = $Event.cluster
# Overriding Polaris in cluster name
IF($EventCluster -eq "Polaris"){$EventCluster = "RSC-Native"}
# Only processing if not null, could be cloud native
IF ($EventCluster -ne $null)
{
# Setting variables
$EventClusterID = $EventCluster.id
$EventClusterVersion = $EventCluster.version
$EventClusterName = $EventCluster.name
}
# Must be cloud snappable using UTC
IF ($EventCluster -eq $null)
{
$EventClusterTimeZone = "UTC"
$EventClusterHoursToAdd = 0
$EventMinutesHoursToAdd = 0
$EventLocation = $null
$EventClusterStatus = $null
}
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
IF($EventErrorRemedy -ne $null){$EventErrorRemedy = $EventErrorRemedy.Replace("'","")}
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
$Object | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $EventClusterName
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $EventClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Version" -Value $EventClusterVersion
$Object | Add-Member -MemberType NoteProperty -Name "Node" -Value $EventErrorNode
$Object | Add-Member -MemberType NoteProperty -Name "Message" -Value $EventMessage
$Object | Add-Member -MemberType NoteProperty -Name "DateUTC" -Value $EventDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $EventType
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $EventStatus
$Object | Add-Member -MemberType NoteProperty -Name "ErrorCode" -Value $EventErrorCode
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $EventErrorMessage
$Object | Add-Member -MemberType NoteProperty -Name "ErrorRemedy" -Value $EventErrorRemedy
# Adding to array (optional, not needed)
$RSCEvents.Add($Object) | Out-Null
# End of for each event below
}
# End of for each event above

# Returning array
Return $RSCEvents
# End of function
}
