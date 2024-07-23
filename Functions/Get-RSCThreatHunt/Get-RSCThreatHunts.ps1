################################################
# Function - Get-RSCThreatHunts - Getting all RSC Threat hunts
################################################
Function Get-RSCThreatHunts {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that returns a list of all threat hunts created within the time frame specified, searches back 30 days unless configured otherwise

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER HoursToCapture
The number of hours back to search for threat hunts, use one or the other.
.PARAMETER DaysToCapture
The number of days back to search for threat hunts, use one or the other.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCThreatHunts

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
	Param
    (
        $HoursToCapture,$DaysToCapture
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
# Nulling any set as 0, to avoid mistakes from user presuming they have to enter 0
IF($DaysToCapture -eq 0){$DaysToCapture = $Null}
IF($HoursToCapture -eq 0){$HoursToCapture = $Null}
# If null, setting to 30 days
IF(($DaysToCapture -eq $null) -and ($HoursToCapture -eq $null))
{
$DaysToCapture = 30
}
# Calculating time range if hours specified
IF($HoursToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddHours(-$HoursToCapture)
$TimeRange = $MachineDateTime.AddHours(-$HoursToCapture)
}
# Calculating time range if days specified
IF($DaysToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddDays(-$DaysToCapture)
$TimeRange = $MachineDateTime.AddDays(-$DaysToCapture)
}
# Converting to UNIX time format
$TimeRangeUNIX = $TimeRangeUTC.ToString("yyyy-MM-ddTHH:mm:ss.000Z")
# Logging
# Write-Host "CollectingEventsFrom: $TimeRange"
################################################
# Getting RSC Threat Hunts
################################################
# Creating array for events
$RSCThreatHuntsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "ListThreatHuntsQuery";

"variables" = @{
"first" = 100
"beginTime" = "$TimeRangeUNIX"
};

"query" = "query ListThreatHuntsQuery(`$beginTime: DateTime, `$first: Int) {
  threatHunts(beginTime: `$beginTime, first: `$first) {
    edges {
      node {
        huntId
        status
        stats {
          totalUniqueMatchedPaths
          totalAffectedSnapshots
          totalAffectedObjects
          totalSnapshotsScanned
          totalSucceededScans
          totalUniqueQuarantinedPaths
        }
        huntDetails {
          startTime
          endTime
          snapshots {
            objectId
            snapshotIds
            snapshotTimestamps
          }
          cdmId
          config {
            fileScanCriteria {
              fileSizeLimits {
                maximumSizeInBytes
                minimumSizeInBytes
              }
              fileTimeLimits {
                earliestCreationTime
                earliestModificationTime
                latestCreationTime
                latestModificationTime
              }
              pathFilter {
                exceptions
                excludes
                includes
              }
            }
            indicatorsOfCompromise {
              iocKind
              iocValue
            }
            maxMatchesPerSnapshot
            name
            notes
            requestedMatchDetails {
              requestedHashTypes
            }
            shouldTrustFilesystemTimeInfo
            snapshotScanLimit {
              endTime
              maxSnapshotsPerObject
              snapshotsToScanPerObject {
                id
                snapshots
              }
              startTime
            }
            clusterUuid
            objects {
              id
              name
              cdmId
              cluster {
                id
                name
              }
              objectType
              }
            }
          cluster {
            id
            name
          }
        }
        }
      }
    pageInfo {
      startCursor
      endCursor
      hasPreviousPage
      hasNextPage
    }
  }
  }"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCThreatHuntsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 32) -Headers $RSCSessionHeader
$RSCThreatHuntsList += $RSCThreatHuntsResponse.data.threathunts.edges.node
# Getting all results from paginations
While ($RSCThreatHuntsResponse.data.threathunts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCThreatHuntsResponse.data.threathunts.pageInfo.endCursor
$RSCThreatHuntsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCThreatHuntsList += $RSCThreatHuntsResponse.data.threathunts.edges.node
}
# Counting
$RSCThreatHuntsCount = $RSCThreatHuntsList | Measure-Object | Select-Object -ExpandProperty Count
################################################
# Processing Threat Hunts
################################################
$RSCThreatHunts = [System.Collections.ArrayList]@()
# For Each Getting info
ForEach ($ThreatHunt in $RSCThreatHuntsList)
{
# Setting variables
$HuntID = $ThreatHunt.huntId
$HuntStatus = $ThreatHunt.Status
$HuntStats = $ThreatHunt.stats
$HuntDetails = $ThreatHunt.huntDetails
# Hunt stats
$HuntMatchedObjects = $HuntStats.totalAffectedObjects
$HuntMatchedSnapshots = $HuntStats.totalAffectedSnapshots
$HuntSnapshotsScanned = $HuntStats.totalSnapshotsScanned
$HuntMatchedPaths = $HuntStats.totalUniqueMatchedPaths
$HuntSnapshotsWithNoMatches = $HuntSnapshotsScanned - $HuntMatchedSnapshots
# Hunt details
$HuntStartUNIX = $HuntDetails.startTime
$HuntEndUNIX = $HuntDetails.endTime
$HuntSnapshots = $HuntDetails.snapshots
$HuntConfig = $HuntDetails.config
$HuntCluster = $HuntDetails.cluster
# Cluster info
$HuntClusterID = $HuntCluster.id
$HuntClusterName = $HuntCluster.name
# Converting times
IF($HuntStartUNIX -ne $null){$HuntStartUTC = Convert-RSCUNIXTime $HuntStartUNIX}ELSE{$HuntStartUTC = $null}
IF($HuntEndUNIX -ne $null){$HuntEndUTC = Convert-RSCUNIXTime $HuntEndUNIX}ELSE{$HuntEndUTC = $null}
# Getting hunt file criteria
$HuntFileScanCriteria = $HuntConfig.fileScanCriteria
$HuntFileSizeLimits = $HuntFileScanCriteria.fileSizeLimits
$HuntFileSizeMax = $HuntFileSizeLimits.maximumSizeInBytes
$HuntFileSizeMin = $HuntFileSizeLimits.minimumSizeInBytes
$HuntFilepathFilter = $HuntFileScanCriteria.pathFilter
$HuntFileExceptions = $HuntFilepathFilter.exceptions
$HuntFileExcludes = $HuntFilepathFilter.excludes
$HuntFileIncludes = $HuntFilepathFilter.includes
# Getting hunt IOC info
$HuntIOCConfig = $HuntConfig.indicatorsOfCompromise
$HuntIOCType = $HuntIOCConfig.iocKind
$HuntIOCValue = $HuntIOCConfig.iocValue
# Other detail
$HuntMaxMatchesPerSnapshot = $HuntConfig.maxMatchesPerSnapshot
$HuntName = $HuntConfig.name
$HuntNotes = $HuntConfig.notes
# Snapshot scan limits
$HuntSnapshotScanLimit = $HuntConfig.snapshotScanLimit
$HuntMaxSnapShotsPerObject = $HuntSnapshotScanLimit.maxSnapshotsPerObject
# Scan objects
$HuntObjects = $HuntConfig.objects
$HuntObjectCount = $HuntObjects | Measure-Object | Select-Object -ExpandProperty Count
$HuntObjectsWithNoMatches = $HuntObjectCount - $HuntMatchedObjects
# Calculating timespans if not null
IF (($HuntStartUTC -ne $null) -and ($HuntEndUTC -ne $null))
{
$HuntRuntime = New-TimeSpan -Start $HuntStartUTC -End $HuntEndUTC
$HuntMinutes = $HuntRuntime | Select-Object -ExpandProperty TotalMinutes
$HuntSeconds = $HuntRuntime | Select-Object -ExpandProperty TotalSeconds
$HuntDuration = "{0:g}" -f $HuntRuntime
IF ($HuntDuration -match "."){$HuntDuration = $HuntDuration.split('.')[0]}
# Calculating seconds per object and snapshot
$HuntSecondsPerObject = $HuntSeconds / $HuntObjectCount
$HuntSecondsPerSnapshot = $HuntSeconds / $HuntSnapshotsScanned
# Rounding
$HuntSecondsPerObject = [Math]::Round($HuntSecondsPerObject)
$HuntSecondsPerSnapshot = [Math]::Round($HuntSecondsPerSnapshot)
# Calculating minutes per object and snapshot
$HuntMinutesPerObject = $HuntSecondsPerObject / 60
$HuntMinutesPerSnapshot = $HuntSecondsPerSnapshot / 60
# Rounding
$HuntMinutesPerObject = [Math]::Round($HuntMinutesPerObject)
$HuntMinutesPerSnapshot = [Math]::Round($HuntMinutesPerSnapshot)
}
ELSE
{
$HuntMinutes = $null
$HuntSeconds = $null
$HuntDuration = $null
$HuntSecondsPerObject = $null
$HuntSecondsPerSnapshot = $null
$HuntMinutesPerObject = $null
$HuntMinutesPerSnapshot = $null
}
# Creating URL to view/manage threat hunt
# Example: https://rubrik-gaia.my.rubrik.com/radar/investigations/threat_hunts/a57dd4d3-2d1a-5fca-8dab-e0403235a8a6/details
# Basic URL if not known: https://rubrik-gaia.my.rubrik.com/radar/investigations/threat_hunts
# Creating URL
$RSCThreatHuntURL = $RSCURL + "/radar/investigations/threat_hunts/" + $HuntID + "/details"
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHunt" -Value $HuntName
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHuntID" -Value $HuntID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $HuntStatus
$Object | Add-Member -MemberType NoteProperty -Name "Notes" -Value $HuntNotes
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $HuntIOCType
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $HuntClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $HuntClusterID
# Hunt results
$Object | Add-Member -MemberType NoteProperty -Name "Objects" -Value $HuntObjectCount
$Object | Add-Member -MemberType NoteProperty -Name "ObjectsWithMatches" -Value $HuntMatchedObjects
$Object | Add-Member -MemberType NoteProperty -Name "ObjectsWithoutMatches" -Value $HuntObjectsWithNoMatches
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotsScanned" -Value $HuntSnapshotsScanned
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotsWithMatches" -Value $HuntMatchedSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotsWithoutMatches" -Value $HuntSnapshotsWithNoMatches
$Object | Add-Member -MemberType NoteProperty -Name "MatchedFiles" -Value $HuntMatchedPaths
# Timing
$Object | Add-Member -MemberType NoteProperty -Name "StartUTC" -Value $HuntStartUTC
$Object | Add-Member -MemberType NoteProperty -Name "EndUTC" -Value $HuntEndUTC
$Object | Add-Member -MemberType NoteProperty -Name "Duration" -Value $HuntDuration
$Object | Add-Member -MemberType NoteProperty -Name "DurationSeconds" -Value $HuntSeconds
# $Object | Add-Member -MemberType NoteProperty -Name "SecondsPerObject" -Value $HuntSecondsPerObject
$Object | Add-Member -MemberType NoteProperty -Name "SecondsPerSnapshot" -Value $HuntSecondsPerSnapshot
# $Object | Add-Member -MemberType NoteProperty -Name "MinutesPerObject" -Value $HuntMinutesPerObject
$Object | Add-Member -MemberType NoteProperty -Name "MinutesPerSnapshot" -Value $HuntMinutesPerSnapshot
# Hunt config detail
$Object | Add-Member -MemberType NoteProperty -Name "MaxMatchesPerSnapshot" -Value $HuntMaxMatchesPerSnapshot
$Object | Add-Member -MemberType NoteProperty -Name "MaxSnapShotsPerObject" -Value $HuntMaxSnapShotsPerObject
$Object | Add-Member -MemberType NoteProperty -Name "FileSizeMax" -Value $HuntFileSizeMax
$Object | Add-Member -MemberType NoteProperty -Name "FileSizeMin" -Value $HuntFileSizeMin
$Object | Add-Member -MemberType NoteProperty -Name "FileExceptions" -Value $HuntFileExceptions
$Object | Add-Member -MemberType NoteProperty -Name "FileExcludes" -Value $HuntFileExcludes
$Object | Add-Member -MemberType NoteProperty -Name "FileIncludes" -Value $HuntFileIncludes
# IOC definition
$Object | Add-Member -MemberType NoteProperty -Name "IOCConfig" -Value $HuntIOCValue
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $RSCThreatHuntURL
# Adding to array
$RSCThreatHunts.Add($Object) | Out-Null
#
# End of for each hunt below
}
# End of for each hunt above

# Returning array
Return $RSCThreatHunts
# End of function
}
