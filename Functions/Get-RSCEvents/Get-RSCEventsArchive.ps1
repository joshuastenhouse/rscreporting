################################################
# Function - Get-RSCEventsArchive - Getting all RSC Archive events
################################################
function Get-RSCEventsArchive {

    <#
.SYNOPSIS
Returns all RSC archive events within the time frame specified, default is 24 hours with no parameters.

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
Get-RSCEventsArchive
This example returns all events within a 24 hour period as no paramters were set.

.EXAMPLE
Get-RSCEventsArchive -DaysToCapture 30
This example returns all events within a 30 day period.

.EXAMPLE
Get-RSCEventsArchive -DaysToCapture 30 -LastActivityStatus "FAILED" -ObjectType "VMwareVirtualMachine"
This example returns all failed events within 30 days for VMwareVirtualMachines.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

    ################################################
    # Paramater Config
    ################################################
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]$DaysToCapture,
        [Parameter(Mandatory = $false)]$HoursToCapture,
        [Parameter(Mandatory = $false)]$MinutesToCapture,
        [Parameter(Mandatory = $false)]$LastActivityStatus,
        [Parameter(Mandatory = $false)]$ObjectType,
        [Parameter(Mandatory = $false)]$ObjectName,
        [Parameter(Mandatory = $false)]$FromDate,
        [Parameter(Mandatory = $false)]$ToDate
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
    if (($MinutesToCapture -eq $null) -and ($HoursToCapture -eq $null)) {
        $HoursToCapture = 24
    }
    # Calculating time range if hours specified
    if ($HoursToCapture -ne $null) {
        $TimeRangeFromUTC = $UTCDateTime.AddHours(-$HoursToCapture)
        $TimeRange = $MachineDateTime.AddHours(-$HoursToCapture)
    }
    # Calculating time range if minutes specified
    if ($MinutesToCapture -ne $null) {
        $TimeRangeFromUTC = $UTCDateTime.AddMinutes(-$MinutesToCapture)
        $TimeRange = $MachineDateTime.AddMinutes(-$MinutesToCapture)
        # Overring hours if minutes specified
        $HoursToCapture = 60 / $MinutesToCapture
        $HoursToCapture = [Math]::Round($HoursToCapture, 2)
    }
    # Overriding both if days to capture specified
    if ($DaysToCapture -ne $null) {
        $TimeRangeFromUTC = $UTCDateTime.AddDays(-$DaysToCapture)
        $TimeRange = $MachineDateTime.AddDays(-$DaysToCapture)	
    }
    ######################
    # Overriding if FromDate Used
    ######################
    if ($FromDate -ne $null) {
        # Checking valid date object
        $ParamType = $FromDate.GetType().Name
        # If not valid date time, trying to convert
        if ($ParamType -ne "DateTime") { $FromDate = [datetime]$FromDate; $ParamType = $FromDate.GetType().Name }
        # If still not a valid datetime object, breaking
        if ($ParamType -ne "DateTime") {
            Write-Error "ERROR: FromDate specified is not a valid DateTime object. Use this format instead: 08/14/2023 23:00:00"
            Start-Sleep 2
            break
        }
        # Setting TimeRangeUTC to be FromDate specified
        $TimeRangeFromUTC = $FromDate
    }
    ######################
    # Overriding if ToDate Used, setting to UTCDateTime if null
    ######################
    if ($ToDate -ne $null) {
        # Checking valid date object
        $ParamType = $ToDate.GetType().Name
        # If not valid date time, trying to convert
        if ($ParamType -ne "DateTime") { $ToDate = [datetime]$ToDate; $ParamType = $ToDate.GetType().Name }
        # If still not a valid datetime object, breaking
        if ($ParamType -ne "DateTime") {
            Write-Error "ERROR: ToDate specified is not a valid DateTime object. Use this format instead: 08/14/2023 23:00:00"
            Start-Sleep 2
            break
        }
        # Setting TimeRangeUTC to be ToDate specified
        $TimeRangeToUTC = $ToDate
    }
    else {
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
    $lastActivityType = "ARCHIVE"
    # Creating array for events
    $RSCEventsList = @()
    # Building GraphQL query
    $RSCGraphQL = @{"operationName" = "EventSeriesListQuery";

        "variables"                 = @{
            "filters"   = @{
                "lastUpdatedTimeGt" = "$TimeRangeFromUNIX"
                "lastUpdatedTimeLt" = "$TimeRangeToUNIX"
            }
            "first"     = 50
            "sortOrder" = "DESC"
        };

        "query"                     = "query EventSeriesListQuery(`$after: String, `$filters: ActivitySeriesFilter, `$first: Int, `$sortOrder: SortOrder) {
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
    if ($lastActivityType -ne $null) { $RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "lastActivityType" -Value $LastActivityType }
    if ($lastActivityStatus -ne $null) { $RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "lastActivityStatus" -Value $LastActivityStatus }
    if ($objectType -ne $null) { $RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "objectType" -Value $ObjectType }
    if ($objectName -ne $null) { $RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "objectName" -Value $ObjectName }
    ################################################
    # API Call To RSC GraphQL URI
    ################################################
    # Querying API
    $RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-Json -Depth 32) -Headers $RSCSessionHeader
    $RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges.node
    # Getting all results from paginations
    while ($RSCEventsResponse.data.activitySeriesConnection.pageInfo.hasNextPage) {
        # Setting after variable, querying API again, adding to array
        $RSCEventsJSONObject.variables | Add-Member -MemberType NoteProperty "after" -Value $RSCEventsResponse.data.activitySeriesConnection.pageInfo.endCursor -Force
        $RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
        $RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges.node
    }
    # Removing queued events
    # $RSCEventsList = $RSCEventsList | Where-Object {$_.lastActivityStatus -ne "Queued"}
    # Removing Rubrik cluster events
    # $RSCEventsList = $RSCEventsList | Where-Object {$_.objectType -ne "Cluster"}
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
    foreach ($Event in $RSCEventsList) {
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
        if ($EventCluster -ne $null) {
            # Setting variables
            $EventClusterID = $EventCluster.id
            $EventClusterVersion = $EventCluster.version
            $EventClusterName = $EventCluster.name
        }
        # Overriding Polaris in cluster name
        if ($EventClusterName -eq "Polaris") { $EventClusterName = "RSC-Native" }
        # Getting message
        $EventInfo = $Event | Select-Object -ExpandProperty activityConnection -First 1 | Select-Object -ExpandProperty nodes 
        $EventMessage = $EventInfo.message
        # Getting CDM detail
        $EventDetail = $Event | Select-Object -ExpandProperty activityConnection -First 1 | Select-Object -ExpandProperty nodes | Select-Object -ExpandProperty activityInfo | ConvertFrom-Json
        $EventCDMInfo = $EventDetail.CdmInfo 
        if ($EventCDMInfo -ne $null) { $EventCDMInfo = $EventCDMInfo | ConvertFrom-Json }
        # Getting params
        $EventParams = $EventCDMInfo.params
        $EventSnapshot = $EventParams.'${timestamp}'
        $EventTarget = $EventParams.'${locationName}'
        # Converting event times
        $EventDateUTC = Convert-RSCUNIXTime $EventDateUNIX
        if ($EventStartUNIX -ne $null) { $EventStartUTC = Convert-RSCUNIXTime $EventStartUNIX }else { $EventStartUTC = $null }
        if ($EventEndUNIX -ne $null) { $EventEndUTC = Convert-RSCUNIXTime $EventEndUNIX }else { $EventEndUTC = $null }
        # Calculating timespan if not null
        if (($EventStartUTC -ne $null) -and ($EventEndUTC -ne $null)) {
            $EventRuntime = New-TimeSpan -Start $EventStartUTC -End $EventEndUTC
            $EventMinutes = $EventRuntime | Select-Object -ExpandProperty TotalMinutes
            $EventSeconds = $EventRuntime | Select-Object -ExpandProperty TotalSeconds
            $EventDuration = "{0:g}" -f $EventRuntime
            if ($EventDuration -match ".") { $EventDuration = $EventDuration.split('.')[0] }
        }
        else {
            $EventMinutes = $null
            $EventSeconds = $null
            $EventDuration = $null
        }
        # Removing illegal SQL characters from object or message
        if ($EventSnapshot -ne $null) { $EventSnapshot = $EventSnapshot.Replace("'", "") }
        if ($EventObject -ne $null) { $EventObject = $EventObject.Replace("'", "") }
        if ($EventLocation -ne $null) { $EventLocation = $EventLocation.Replace("'", "") }
        if ($EventMessage -ne $null) { $EventMessage = $EventMessage.Replace("'", "") }
        if ($EventErrorMessage -ne $null) { $EventErrorMessage = $EventErrorMessage.Replace("'", "") }
        if ($EventErrorReason -ne $null) { $EventErrorReason = $EventErrorReason.Replace("'", "") }
        # Deciding if on-demand or not
        if ($EventMessage -match "on demand") { $IsOnDemand = $TRUE }else { $IsOnDemand = $FALSE }
        # Resetting to default not, only changing to yes if term matches the 2 variations
        $IsLogBackup = $FALSE 
        # Deciding if log backup or not
        if ($EventMessage -match "transaction log") { $IsLogBackup = $TRUE }
        # Deciding if log backup or not
        if ($EventMessage -match "log backup") { $IsLogBackup = $TRUE }
        # If object type is AzureVM we have to parse the information required from the message,as it's not stored on the activityConnection like the CDM jobs are (dumb)
        if ($EventObjectType -eq "AzureNativeVm") {
            # Getting the snapshot date
            $Pattern = "taken at (.*?) UTC of the"
            $Match = [regex]::Match($EventMessage, $Pattern).Groups[1].Value
            if ($Match -ne $null) {
                try {
                    $EventSnapshot = [datetime]::ParseExact($Match, "dd MMM yy hh:mm tt", $null)# Matching date format of the other snapshots (might fix later as this isn't a usable date time format in PowerShell)
                    $EventSnapshot = $EventSnapshot.ToString("ddd MMM dd HH:mm:00 UTC yyyy")
                }
                catch {
                    $EventSnapshot = $null
                }
            }
            else { $EventSnapshot = $null }
            # Getting the arhive target
            $Pattern = "storage account of (.*?) location."
            $EventTarget = [regex]::Match($EventMessage, $Pattern).Groups[1].Value
        }
        ############################
        # Adding To Array
        ############################
        $Object = New-Object PSObject
        $Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCURL
        $Object | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
        # Object info
        $Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $EventObject
        $Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $EventObjectID
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
        $Object | Add-Member -MemberType NoteProperty -Name "StarUTC" -Value $EventStartUTC
        $Object | Add-Member -MemberType NoteProperty -Name "EndUTC" -Value $EventEndUTC
        $Object | Add-Member -MemberType NoteProperty -Name "Duration" -Value $EventDuration
        $Object | Add-Member -MemberType NoteProperty -Name "DurationSeconds" -Value $EventSeconds
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
    return $RSCEvents
    # End of function
}

