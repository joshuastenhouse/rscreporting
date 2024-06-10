################################################
# Function - Get-RSCEventsAnomalies - Getting all RSC Anomaly events
################################################
Function Get-RSCEventsAnomalies {

<#
.SYNOPSIS
Returns an array of all anomalies within the time frame specified.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference
The ActivitySeriesConnection type: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference/activityseriesconnection.doc.html

.PARAMETER HoursToCapture
Optional, use only 1 paramter, specify the number of hours to collect events from. 
.PARAMETER MinutesToCapture
Optional, use only 1 paramter, specify the number of minutes to collect events from. 
.PARAMETER DaysToCapture
Optional, use only 1 paramter, specify the number of days to collect events from. 

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAnomalies
This returns an array of all anomalies within the last 24 hours, unless you specify a time frame with the HoursToCapture, MinutesToCapture or DaysToCapture paramters.

.EXAMPLE
Get-RSCAnomalies -DaysToCapture 30
This example returns all anomaly events within a 30 day period.

.EXAMPLE
Get-RSCAnomalies -DaysToCapture 30 -ObjectType "VMwareVirtualMachine"
This example returns all anomaly events within 30 days for VMwareVirtualMachines.

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
        [Parameter(Mandatory=$false)]$ObjectType,
        [Parameter(Mandatory=$false)]$ObjectName
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
$MachineDateTime = Get-Date
$UTCDateTime = [System.DateTime]::UtcNow
# If null, setting to 24 hours
IF(($MinutesToCapture -eq $null) -and ($HoursToCapture -eq $null))
{
$HoursToCapture = 24
}
# Calculating time range if minutes specified
IF($MinutesToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddMinutes(-$MinutesToCapture)
$TimeRange = $MachineDateTime.AddMinutes(-$MinutesToCapture)
}
# Calculating time range if hours specified
IF($HoursToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddHours(-$HoursToCapture)
$TimeRange = $MachineDateTime.AddHours(-$HoursToCapture)
}
# Overriding both if days to capture specified
IF($DaysToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddDays(-$DaysToCapture)
$TimeRange = $MachineDateTime.AddDays(-$DaysToCapture)	
}
# Converting to UNIX time format
$TimeRangeUNIX = $TimeRangeUTC.ToString("yyyy-MM-ddTHH:mm:ss.000Z")
# Getting PS version for time conversion later
$PSVersion = $PSVersionTable.values | Sort-Object Major -Desc | Where-Object {$_.Major -ne 10} | Select-Object -ExpandProperty Major -First 1
# Logging
Write-Host "CollectingEventsFrom: $TimeRange"
################################################
# Getting RSC Events
################################################
$lastActivityType = "ANOMALY"
# Creating array for events
$RSCEventsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "EventSeriesListQuery";

"variables" = @{
"filters" = @{
    "lastUpdatedTimeGt" = "$TimeRangeUNIX"
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
IF($objectType -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "objectType" -Value $ObjectType}
IF($objectName -ne $null){$RSCEventsJSONObject.variables.filters | Add-Member -MemberType NoteProperty "objectName" -Value $ObjectName}
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
################################################
# Processing RSC Events
################################################
# Getting list of objects as the location is always null on the API call as of 08/16/23
$RSCObjectList = Get-RSCObjects
# Creating array
$RSCEvents = [System.Collections.ArrayList]@()
# For Each Getting info
ForEach ($Event in $RSCEventsList)
{
# Setting variables
$EventID = $Event.activitySeriesId
$EventObjectID = $Event.objectId
$EventObjectName = $Event.objectName
$EventObjectLocation = $Event.location
$EventObjectType = $Event.objectType
$EventSeverity = $Event.severity
$EventDateUNIX = $Event.lastUpdated
$EventStartUNIX = $Event.startTime
$EventCluster = $Event.cluster
$EventClusterID = $EventCluster.id
$EventClusterName = $EventCluster.name
# Overriding Polaris in cluster name
IF($EventClusterName -eq "Polaris"){$EventClusterName = "RSC-Native"}
# Overriding location and object ID if not RSC native, as it actually returns the Object CDM ID for these events
IF($EventClusterID -ne "00000000-0000-0000-0000-000000000000")
{
$EventObjectInfo = $RSCObjectList | Where-Object {$_.ObjectCDMID -eq $EventObjectID} | Select-Object -First 1
$EventObjectLocation = $EventObjectInfo.Location
$EventObjectID = $EventObjectInfo.ObjectID
}
# Converting event times
$EventDateUTC = Convert-RSCUNIXTime $EventDateUNIX
IF($EventStartUNIX -ne $null){$EventStartUTC = Convert-RSCUNIXTime $EventStartUNIX}ELSE{$EventStartUTC = $null}
# Calculating timespan if not null
IF (($EventStartUTC -ne $null) -and ($EventDateUTC -ne $null))
{
$EventRuntime = New-TimeSpan -Start $EventStartUTC -End $EventDateUTC
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
# Getting activity series info
$EventActivity = $Event.activityConnection.nodes
$EventMessage = $EventActivity.message
$EventInfo = $EventActivity.activityInfo
# If not null, converting & setting variables
IF($EventInfo -ne $null)
{
$EventInfo = $EventInfo | ConvertFrom-JSON
# Getting anomaly detail
$EventSnapshotID = $EventInfo.SnapshotFID
$EventSnapshotDateEPOCH = $EventInfo.SnapshotDate
$EventSnapshotDate = (Get-Date -Date "01/01/1970").AddMilliseconds($EventSnapshotDateEPOCH)
# Snapshot results
$EventAnomalyConfidence = $EventInfo.AnomalyConfidence
$EventAnomalyProbability = $EventInfo.AnomalyProbability
$EventEncryptionConfidence = $EventInfo.EncryptionConfidence
$EventEncryptionProbability = $EventInfo.EncryptionProbability
$EventFilesAdded = $EventInfo.FilesAdded
$EventFilesModified = $EventInfo.FilesModified
$EventFilesDeleted = $EventInfo.FilesDeleted
$EventFilesSuspicious = $EventInfo.SuspiciousFilesAdded
# Data change info
$EventBytesAdded = $EventInfo.BytesAdded
$EventBytesModified = $EventInfo.BytesModified
$EventBytesDeleted = $EventInfo.BytesDeleted
$EventBytesChanged = $EventInfo.BytesNetChanged
}
ELSE
{
# No event detail, nulling values
$EventSnapshotID = $null
$EventSnapshotDate = $null
$EventAnomalyConfidence = $null
$EventAnomalyProbability = $null
$EventEncryptionConfidence = $null
$EventEncryptionProbability = $null
$EventFilesAdded = $null
$EventFilesModified = $null
$EventFilesDeleted = $null
$EventFilesSuspicious = $null
$EventBytesAdded = $null
$EventBytesModified = $null
$EventBytesDeleted = $null
$EventBytesChanged = $null
}
############################
# Creating Investigation URL
############################
# $RSCInvestigationURL = $RSCURL + "/clusters/" + $ObjectID + "/overview"
# 1st ID = ObjectID + 2nd ID = SnapshotID
# Nulling
$EventObjectTypeURL = $null
# Creating link name per object type as it usually doesn't match, smart!

# https://rubrik-gaia.my.rubrik.com/radar/investigations/vsphere/a8fd8809-bbdb-5a03-8663-1c1feb19791c/snapshot/718aec34-c869-57e0-a835-cb6392e4b5f3/summary
IF($EventObjectType -eq "VmwareVm"){$EventObjectTypeURL = "vsphere"}

# https://rubrik-gaia.my.rubrik.com/radar/investigations/nutanix/6c8a8cb0-2974-507c-a21c-50b0684bcfc3/snapshot/1f87b55b-3a4a-5031-89b0-9aba0336f4dc/summary
IF($EventObjectType -eq "NutanixVm"){$EventObjectTypeURL = "nutanix"}

# https://rubrik-gaia.my.rubrik.com/radar/investigations/fileset/06270f8d-ca73-50b0-af90-e537f5c87e8b/snapshot/d5cbcae0-ca32-5366-b4fa-f25024eeb9e0/summary
IF($EventObjectType -match "Fileset"){$EventObjectTypeURL = "fileset"}

# https://rubrik-gaia.my.rubrik.com/radar/investigations/hyperV/f34c4810-1da6-5551-8e8a-0654971eaba2/snapshot/870a2d72-74ff-57e6-981d-329dcb64036d/summary
IF($EventObjectType -eq "HypervVm"){$EventObjectTypeURL = "hyperV"}

# https://rubrik-gaia.my.rubrik.com/radar/investigations/AzureNativeVm/4239abe2-6174-4a5d-ab38-79092a712afb/snapshot/3f43139c-9a5a-48cf-9a86-b075a2f675a7/summary
IF($EventObjectType -eq "AzureNativeVm"){$EventObjectTypeURL = "AzureNativeVm"}

# https://rubrik-gaia.my.rubrik.com/radar/investigations/CLOUD_DIRECT_NAS_EXPORT/30a16f56-233a-5722-a5ea-3f423f5d885d/snapshot/fe1a2108-20d3-5864-bd71-37407d68c9f7/summary
IF($EventObjectType -eq "CLOUD_DIRECT_NAS_EXPORT"){$EventObjectTypeURL = "CLOUD_DIRECT_NAS_EXPORT"}

# Creating investigation URL
$RSCInvestigationURL = $RSCURL + "/radar/investigations/" + $EventObjectTypeURL + "/" + $EventObjectID + "/snapshot/" + $EventSnapshotID + "/summary"
# If unknown link (as not in labs), linking to anomalies page instead
IF($EventObjectTypeURL -eq $null)
{
$RSCInvestigationURL = $RSCURL + "/radar/investigations/anomalies"
}
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $EventClusterName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $EventObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $EventObjectName
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $EventObjectLocation
$Object | Add-Member -MemberType NoteProperty -Name "Severity" -Value $EventSeverity
# Timing
$Object | Add-Member -MemberType NoteProperty -Name "DateUTC" -Value $EventDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "StartUTC" -Value $EventStartUTC
$Object | Add-Member -MemberType NoteProperty -Name "EndUTC" -Value $EventDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "Duration" -Value $EventDuration
$Object | Add-Member -MemberType NoteProperty -Name "DurationSeconds" -Value $EventSeconds
# Anomaly results
$Object | Add-Member -MemberType NoteProperty -Name "AnomalyConfidence" -Value $EventAnomalyConfidence
$Object | Add-Member -MemberType NoteProperty -Name "EncryptionConfidence" -Value $EventEncryptionConfidence
$Object | Add-Member -MemberType NoteProperty -Name "FilesAdded" -Value $EventFilesAdded
$Object | Add-Member -MemberType NoteProperty -Name "FilesModified" -Value $EventFilesModified
$Object | Add-Member -MemberType NoteProperty -Name "FilesDeleted" -Value $EventFilesDeleted
$Object | Add-Member -MemberType NoteProperty -Name "FilesSuspicious" -Value $EventFilesSuspicious
# Anomaly size, returning null on all events in RSC labs 05/16/23 so leaving out for now
# $Object | Add-Member -MemberType NoteProperty -Name "BytesAdded" -Value $EventBytesAdded
# $Object | Add-Member -MemberType NoteProperty -Name "BytesModified" -Value $EventBytesModified
# $Object | Add-Member -MemberType NoteProperty -Name "BytesDeleted" -Value $EventBytesDeleted
# $Object | Add-Member -MemberType NoteProperty -Name "BytesChanged" -Value $EventBytesChanged
# Snapshot info
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotDate" -Value $EventSnapshotDate
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $EventSnapshotID
# Other IDs
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $EventObjectID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $EventClusterID
$Object | Add-Member -MemberType NoteProperty -Name "InvestigationURL" -Value $RSCInvestigationURL
# Adding to array (optional, not needed)
$RSCEvents.Add($Object) | Out-Null
# End of for each event below
}
# End of for each event above

# Returning array
Return $RSCEvents
# End of function
}
