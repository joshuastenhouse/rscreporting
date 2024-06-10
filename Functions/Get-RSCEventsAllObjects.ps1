################################################
# Function - Get-RSCEventsAllObjects - Getting all RSC events for all objects
################################################
Function Get-RSCEventsAllObjects {

<#
.SYNOPSIS
Returns all RSC events for all protected objects for all time unless a date range is specified - warning this could take a long time!

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference
The ActivitySeriesConnection type: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference/activityseriesconnection.doc.html

.PARAMETER FromDate
Alternative to Days/Hours/Minutes, specicy a from date in the format 08/14/2023 23:00:00 to only collect events from AFTER this date.
.PARAMETER ToDate
Alternative to Days/Hours/Minutes, specicy a To date in the format 08/14/2023 23:00:00 to only collect events from BEFORE this date. Will always be UTCNow if null.
.PARAMETER LastActivityType
Set the required type of events, has to be from the schema link, you can also try not specifying this, then use EventType on the array to get a valid list of LastActivityTypes.
.PARAMETER LastActivityStatus
Set the required status of events, has to be from the schema link, you can also try not specifying this, then use EventStatus on the array to get a valid list of LastActivityStatus.
.PARAMETER ObjectType
Set the required object type of the events, has to be be a valid object type from the schema link, you can also try not specifying this, then use ObjectType on the array to get a valid list of ObjectType.
.PARAMETER ObjectName
Set the required object name of the events, has to be be a valid object name, you can also try not specifying this, then use Object on the array to get a valid list of ObjectName.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCEvents
This example returns all events within a 24 hour period as no paramters were set.

.EXAMPLE
Get-RSCEvents -DaysToCapture 30
This example returns all events within a 30 day period.

.EXAMPLE
Get-RSCEvents -DaysToCapture 30 -LastActivityType "BACKUP" -LastActivityStatus "FAILED" -ObjectType "VMwareVirtualMachine"
This example returns all failed backup events within 30 days for VMwareVirtualMachines.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
	Param
    (
        $LastActivityType,$LastActivityStatus,$ObjectType,[switch]$SampleFirst10Objects
    )
	
################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Logging
Write-Host "This is a very intensive API call, it is building a list of clusters and objects, wait a minute for it to start processing events per object..."
# Getting RSC clusters
$RSCClusters = Get-RSCClusters
# Getting RSC protected objects
$ProtectedObjects = Get-RSCObjects | Where-Object {$_.ReportOnCompliance -eq $TRUE}
# Overriding if wanting sample if switch used
IF($SampleFirst10Objects){$ProtectedObjects = $ProtectedObjects | Select-Object -First 10}
# Counting
$ProtectedObjectsCount = $ProtectedObjects | Measure-Object | Select-Object -ExpandProperty Count
$ProtectedObjectsCounter = 0
################################################
# Getting times required
################################################
$ScriptStart = Get-Date
$MachineDateTime = Get-Date
$UTCDateTime = [System.DateTime]::UtcNow
################################################
# Getting RSC Events Per Object
################################################
# Creating array for events
$RSCEvents = [System.Collections.ArrayList]@()
# For each object
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
################################################
# Removing Duplicates (as no ability to query events API by ObjectID as of 08/14/23, so using name and filtering)
################################################
$RSCEventsList = $RSCEventsList | Where-Object {$_.fid -eq $ProtectedObjectID}
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
# Overriding object type and name to be more descriptive, it labels a Rubrik cluster as just Cluster which could be anything with no object name
IF($EventObjectType -eq "Cluster")
{
$EventObjectType = "RubrikCluster"
$EventObject = $EventClusterName
$EventObjectID = $EventClusterID
$EventObjectCDMID = $EventClusterID
$EventLocation = $RSCClusters | Where-Object {$_.ClusterID -eq $EventClusterID} | Select-Object -ExpandProperty Location -First 1
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
$RSCEvents.Add($Object) | Out-Null
# End of for each event below
}
# End of for each event above

# Counting total list after addition
$RSCEventsCount = $RSCEvents | Measure-Object | Select-Object -ExpandProperty Count
# Logging
Write-Host "ProcessedObject:$ProtectedObjectsCounter/$ProtectedObjectsCount EventsReturnedByAPI:$RSCEventsListCount TotalEvents:$RSCEventsCount"

# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCEvents
# End of function
}
