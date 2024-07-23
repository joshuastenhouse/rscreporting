################################################
# Function - Get-RSCObjectLastBackup - Getting last backup event for the specified object
################################################
Function Get-RSCObjectLastBackup {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for returning the last backup event for the specified ObjectID.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
A valid ObjectID in RSC, use Get-RSCObjects to obtain.
.PARAMETER ObjectName
If you have a unique object name use this, but not recommended, as the larger environment the more unlikely this is.
.PARAMETER ExcludeLogBackups
Useful for obtaining the last full backup of a database object, excluding all log backups.
.PARAMETER OnlyLogBackups
Useful for obtaining the last log backup of a database object, excluding full backups.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectLastBackup -ObjectID "3443ffwf-fwefwff-wfwfwf" -OnlyLogBackups
This example returns the last log backup of the ObjectID specified (presuming it's a database!)

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################	
	Param
    (
    [Parameter(Mandatory=$true)]
    [String]$ObjectID,$ObjectName,[switch]$ExcludeLogBackups,[switch]$OnlyLogBackups
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting All Objects 
################################################
# Creating array for objects
$RSCObjectsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "snappableConnection";

"variables" = @{
"first" = 1000
};

"query" = "query snappableConnection(`$after: String) {
  snappableConnection(after: `$after, first: 1000) {
    edges {
      node {
        fid
        id
        name
        slaDomain {
          id
          name
          version
        }
        cluster {
          id
          name
        }
      }
    }
        pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      __typename
    }
  }
}
"
}
################################################
# RSCReporting SDK
################################################
# Querying API
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
# Getting all results from paginations
While ($RSCObjectsResponse.data.snappableConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectsResponse.data.snappableConnection.pageInfo.endCursor
$RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
}
################################################
# Validating ID and/or object name
################################################
IF($ObjectID -ne $null)
{
# Finding entry in list by ID
$ObjectListEntry = $RSCObjectsList | Where-Object {$_.fid -eq $ObjectID}
IF($ObjectListEntry -ne $null){$ObjectFound = $TRUE}ELSE{$ObjectFound = $FALSE}
$ObjectName = $ObjectListEntry.name
}
IF($ObjectName -ne $null)
{
# Finding entry in list by name
$ObjectListEntry = $RSCObjectsList | Where-Object {$_.name -eq $ObjectName} | Select-Object -First 1
IF($ObjectListEntry -ne $null){$ObjectFound = $TRUE}ELSE{$ObjectFound = $FALSE}
$ObjectID = $ObjectListEntry.fid
}
# API call relies on name (no ID filter, stupid), if no name then exiting
IF($ObjectFound -ne $TRUE)
{
Write-Error "ERROR: ObjectID or ObjectName not found, check Get-RSCObjects for a correct Object or ObjectID and try again.."
Start-Sleep 2
Break
}
################################################
# Getting times required
################################################
$DaysToCapture = 365
$MachineDateTime = Get-Date
$UTCDateTime = [System.DateTime]::UtcNow
# Overriding both if days to capture specified
IF($DaysToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddDays(-$DaysToCapture)
$TimeRange = $MachineDateTime.AddDays(-$DaysToCapture)	
}
# Converting to UNIX time format
$TimeRangeUNIX = $TimeRangeUTC.ToString("yyyy-MM-ddTHH:mm:ss.000Z")
################################################
# Getting RSC Events
################################################
$lastActivityType = "BACKUP"
# Creating array for events
$RSCEventsList = @()
# Building GraphQL query, selecting first 100 so we get a full backup amongst a day of 15 minute log backups (96 per day)
$RSCEventsGraphQL = @{"operationName" = "EventSeriesListQuery";

"variables" = @{
"filters" = @{
    "lastUpdatedTimeGt" = "$TimeRangeUNIX"
  }
"first" = 100
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
  __typename
}"
}
# Converting to JSON
$RSCEventsJSON = $RSCEventsGraphQL | ConvertTo-Json -Depth 32
# Converting back to PS object for editing of variables
$RSCEventsJSONObject = $RSCEventsJSON | ConvertFrom-Json
# Adding variables specified
IF($lastActivityType -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "lastActivityType" -Value $lastActivityType}
IF($lastActivityStatus -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "lastActivityStatus" -Value $lastActivityStatus}
IF($objectName -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "objectName" -Value $ObjectName}
# Querying API
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCEventsJSONObject | ConvertTo-JSON -Depth 32) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.activitySeriesConnection.edges.node
# Not paginating, no need, just wanted most recent with time filter to stop the API hanging
# Filtering to ensure only correct object listed, as names could be duplicate
$RSCEventsListFiltered = $RSCEventsList | Where-Object {$_.fid -eq $ObjectID}
# Removing queued entries
$RSCEventsListFiltered = $RSCEventsListFiltered | Where-Object {$_.lastActivityStatus -ne "Queued"}
# Counting
$RSCEventsCount = $RSCEventsListFiltered | Measure-Object | Select-Object -ExpandProperty Count
$RSCObjectsList = $RSCEventsListFiltered | Select-Object ObjectId -Unique
# Selecting most recent event, unless ExcludeLogBackups switch is used then we have to process them all to get the last full non log backup
IF($ExcludeLogBackups){$RSCMostRecentEvent = $RSCEventsListFiltered}ELSE{$RSCMostRecentEvent = $RSCEventsListFiltered | Select-Object -First 1}
################################################
# Processing RSC Events
################################################
$RSCEvents = [System.Collections.ArrayList]@()
# For Each Getting info
ForEach ($Event in $RSCMostRecentEvent)
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
$Object | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $EventClusterName
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $EventClusterID
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
$Object | Add-Member -MemberType NoteProperty -Name "StartUTC" -Value $EventStartUTC
$Object | Add-Member -MemberType NoteProperty -Name "EndUTC" -Value $EventEndUTC
$Object | Add-Member -MemberType NoteProperty -Name "Duration" -Value $EventDuration
$Object | Add-Member -MemberType NoteProperty -Name "DurationSeconds" -Value $EventSeconds
# Failure detail
$Object | Add-Member -MemberType NoteProperty -Name "ErrorCode" -Value $EventErrorCode
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $EventErrorMessage
$Object | Add-Member -MemberType NoteProperty -Name "ErrorReason" -Value $EventErrorReason
# Misc info
$Object | Add-Member -MemberType NoteProperty -Name "IsOnDemand" -Value $IsOnDemand
$Object | Add-Member -MemberType NoteProperty -Name "IsLogBackup" -Value $IsLogBackup
# Adding to array (optional, not needed)
$RSCEvents.Add($Object) | Out-Null
# End of for each event below
}
# End of for each event above

# Filtering for full backup only if switch used
IF($ExcludeLogBackups){$RSCEvents = $RSCEvents | Where-Object {$_.IsLogBackup -eq $FALSE} | Select-Object -First 1}

# Filtering for log backups if switch used
IF($OnlyLogBackups){$RSCEvents = $RSCEvents | Where-Object {$_.IsLogBackup -eq $TRUE} | Select-Object -First 1}

# Returning array
Return $RSCEvents
# End of function
}
