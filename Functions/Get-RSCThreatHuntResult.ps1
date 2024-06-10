################################################
# Function - Get-RSCThreatHuntResult - Getting RSC Threat hunt detail
################################################
Function Get-RSCThreatHuntResult {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a detailed result of the specified threat hunt.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.
.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ThreatHuntID
Requires ID of a valid threat hunt, use Get-RSCThreatHunts to obtain.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCThreatHuntResult -ThreatHuntID "cccswdc-dsfsdsdf-sdsdfsf"
This example returns a detailed result for the threat hunt ID specified.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
	Param
    (
        [Parameter(Mandatory=$true)][String]$ThreatHuntID
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting RSC Threat Hunts
################################################
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "ThreatHuntMalwareResultQuery";

"variables" = @{
"huntId" = "$ThreatHuntID"
};

"query" = "query ThreatHuntMalwareResultQuery(`$huntId: String!) {
  threatHuntResult(huntId: `$huntId) {
    huntId
    config {
      name
      indicatorsOfCompromise {
        iocValue
        iocKind
        __typename
      }
      __typename
    }
    results {
      location
      object {
        id
        name
        objectType
        __typename
      }
      snapshotResults {
        snapshotId
        snapshotDate
        isSnapshotExpired
        status
        lastJobId
        matches {
          indicatorIndex
          paths {
            requestedHashDetails {
              hashValue
              hashType
              __typename
            }
            yaraMatchDetails {
              name
              tags
              __typename
            }
            aclDetails
            creationTime
            modificationTime
            path
            __typename
          }
          __typename
        }
        quarantineDetails {
          filesDetails {
            fileName
            __typename
          }
          __typename
        }
        scanStats {
          numFiles
          numFilesScanned
          totalFilesScannedSizeBytes
          __typename
        }
        __typename
      }
      __typename
    }
    __typename
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCThreatHuntsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 32) -Headers $RSCSessionHeader
# Getting data
$HuntConfig = $RSCThreatHuntsResponse.data.threatHuntResult.config
$HuntResults = $RSCThreatHuntsResponse.data.threatHuntResult.results
################################################
# Processing Threat Hunt Result 
################################################
$RSCThreatHuntResult = [System.Collections.ArrayList]@()
$RSCThreatHuntObjects = [System.Collections.ArrayList]@()
$RSCThreatHuntSnapshots = [System.Collections.ArrayList]@()
$RSCThreatHuntMatches = [System.Collections.ArrayList]@()
# Config
$HUntName = $HuntConfig.name
$HuntIOCConfig = $HuntConfig.indicatorsOfCompromise.iocValue
# Processing results per object
ForEach($HuntObject in $HuntResults)
{
# Object info
$ObjectName = $HuntObject.object.Name
$ObjectID = $HuntObject.object.id
$ObjectType = $HuntObject.object.objectType
# Result info
$Snapshots = $HuntObject.snapshotResults
# For each snapshot in snapshots
ForEach($Snapshot in $Snapshots)
{
# Getting snapshot info
$SnapshotID = $Snapshot.snapshotid
$SnapshotDateUNIX = $Snapshot.snapshotDate
$SnapshotExpired = $Snapshot.isSnapshotExpired
$SnapshotScanStatus = $Snapshot.status
$SnapshotScanStats = $Snapshot.scanStats
$SnapshotFileCount = $SnapshotScanStats.numFiles
$SnapshotFilesScanned = $SnapshotScanStats.numFilesScanned
$SnapshotFilesScannedBytes = $SnapshotScanStats.totalFilesScannedSizeBytes
# Converting to GB
IF($SnapshotFilesScannedBytes -ne $null){$SnapshotFilesScannedGB = $SnapshotFilesScannedBytes / 1000 / 1000 / 1000;$SnapshotFilesScannedGB = [Math]::Round($SnapshotFilesScannedGB,2)}ELSE{$SnapshotFilesScannedGB = $null}
# Converting snapshot date
$SnapshotDateUTC = Convert-RSCUNIXTime $SnapshotDateUNIX
# Snapshot quarentine filelist
$SnapshotQuarantineFiles = $Snapshot.quarantineDetails.filesDetails
# Snapshot match info
$SnapshotMatches = $Snapshot.matches.paths
# Total matches counter
$TotalMatchesCounter = 0
####################################################
# Summarizing Per Match
####################################################
ForEach($SnapshotMatch in $SnapshotMatches)
{
$MatchPath = $SnapshotMatch.path
$CreatedTimeUNIX = $SnapshotMatch.creationTime
$ModifiedTimeUNIX = $SnapshotMatch.modificationTime
$YARAMatchName = $SnapshotMatch.yaraMatchDetails.name
$YARAMatchTags = $SnapshotMatch.yaraMatchDetails.tags
$HashMatchValue = $SnapshotMatch.requestedHashDetails.hashValue
$HashMatchType = $SnapshotMatch.requestedHashDetails.hashType
$ACLDetails = $SnapshotMatch.aclDetails
IF($ACLDetails -ne $null){$ACLDetails = $ACLDetails | ConvertFrom-Json}
# Converting times
$CreatedTime = Convert-RSCUNIXTime $CreatedTimeUNIX
$ModifiedTime = Convert-RSCUNIXTime $ModifiedTimeUNIX
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHunt" -Value $HuntName
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHuntID" -Value $ThreatHuntID
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotUTC" -Value $SnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "MatchPath" -Value $MatchPath
$Object | Add-Member -MemberType NoteProperty -Name "FileCreated" -Value $CreatedTime
$Object | Add-Member -MemberType NoteProperty -Name "FileModified" -Value $ModifiedTime
$Object | Add-Member -MemberType NoteProperty -Name "YARAMatchName" -Value $YARAMatchName
$Object | Add-Member -MemberType NoteProperty -Name "YARAMatchTags" -Value $YARAMatchTags
$Object | Add-Member -MemberType NoteProperty -Name "HashMatchType" -Value $HashMatchType
$Object | Add-Member -MemberType NoteProperty -Name "HashMatchValue" -Value $HashMatchValue
$RSCThreatHuntMatches.Add($Object) | Out-Null
# End of for each match in the snapshot below
}
# End of for each match in the snapshot above
####################################################
# Summarizing Per Snapshot
####################################################
$SnapshotMatchesCount = $SnapshotMatches | Measure-Object | Select-Object -ExpandProperty Count
# Adding to total
$TotalMatchesCounter += $SnapshotMatchesCount
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHunt" -Value $HuntName
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHuntID" -Value $ThreatHuntID
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotUTC" -Value $SnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "Matches" -Value $SnapshotMatchesCount
$Object | Add-Member -MemberType NoteProperty -Name "ScanStatus" -Value $SnapshotScanStatus
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotFiles" -Value $SnapshotFileCount
$Object | Add-Member -MemberType NoteProperty -Name "ScannedFiles" -Value $SnapshotFilesScanned
$Object | Add-Member -MemberType NoteProperty -Name "ScannedFilesTotalGB" -Value $SnapshotFilesScannedGB
$Object | Add-Member -MemberType NoteProperty -Name "IsExpired" -Value $SnapshotExpired
$RSCThreatHuntSnapshots.Add($Object) | Out-Null 
# End of for each snapshot below
}
# End of for each snapshot above
####################################################
# Summarizing Per Object
####################################################
$SnapshotsScannedCount = $Snapshots | Measure-Object | Select-Object -ExpandProperty Count
# Snapshots
$SnaphostsWithMatches = $Snapshots | Where-Object {$_.matches -ne $null} 
$SnaphostsWithMatchesCount = $SnaphostsWithMatches | Measure-Object | Select-Object -ExpandProperty Count
$SnaphostsWithoutMatchesCount = $SnapshotsScannedCount - $SnaphostsWithMatchesCount
IF($SnaphostsWithMatchesCount -gt 0){$ObjectHasMatches = $TRUE}ELSE{$ObjectHasMatches = $FALSE}
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHunt" -Value $HuntName
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHuntID" -Value $ThreatHuntID
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "HasMatches" -Value $ObjectHasMatches
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotsScanned" -Value $SnapshotsScannedCount
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotsWithMatches" -Value $SnaphostsWithMatchesCount
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotsWithoutMatches" -Value $SnaphostsWithoutMatchesCount
$RSCThreatHuntObjects.Add($Object) | Out-Null 
# End of for each object below
}
# End of for each object above
####################################################
# Summarizing Threat Hunt Results
####################################################
# Objects
$ObjectsScanned = $RSCThreatHuntObjects | Measure-Object | Select-Object -ExpandProperty Count
$ObjectsWithMatches = $RSCThreatHuntObjects | Where-Object {$_.HasMatches -eq $TRUE} | Measure-Object | Select-Object -ExpandProperty Count
$ObjectsWithoutMatches = $RSCThreatHuntObjects | Where-Object {$_.HasMatches -eq $FALSE} | Measure-Object | Select-Object -ExpandProperty Count
# Snapshots
$SnapshotsScanned = $RSCThreatHuntObjects | Select-Object -ExpandProperty SnapshotsScanned | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$SnapshotsWithMatches = $RSCThreatHuntObjects | Select-Object -ExpandProperty SnapshotsWithMatches | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$SnapshotsWithoutMatches = $RSCThreatHuntObjects | Select-Object -ExpandProperty SnapshotsWithoutMatches | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Matches
$TotalMatches = $RSCThreatHuntMatches | Measure-Object | Select-Object -ExpandProperty Count
# Files
$TotalFilesScanned = $RSCThreatHuntSnapshots | Select-Object -ExpandProperty ScannedFiles | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$TotalFilesScannedGB = $RSCThreatHuntSnapshots | Select-Object -ExpandProperty ScannedFilesTotalGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Creating URL
$RSCThreatHuntURL = $RSCURL + "/radar/investigations/threat_hunts/" + $ThreatHuntID + "/details"
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHunt" -Value $HuntName
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHuntID" -Value $ThreatHuntID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectsScanned" -Value $ObjectsScanned
$Object | Add-Member -MemberType NoteProperty -Name "ObjectsWithMatches" -Value $ObjectsWithMatches
$Object | Add-Member -MemberType NoteProperty -Name "ObjectsWithoutMatches" -Value $ObjectsWithoutMatches
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotsScanned" -Value $SnapshotsScanned
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotsWithMatches" -Value $SnapshotsWithMatches
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotsWithoutMatches" -Value $SnapshotsWithoutMatches
$Object | Add-Member -MemberType NoteProperty -Name "TotalMatches" -Value $TotalMatches
$Object | Add-Member -MemberType NoteProperty -Name "TotalFilesScanned" -Value $TotalFilesScanned
$Object | Add-Member -MemberType NoteProperty -Name "TotalFilesScannedGB" -Value $TotalFilesScannedGB
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $RSCThreatHuntURL
$RSCThreatHuntResult.Add($Object) | Out-Null

# Returning array
Return $RSCThreatHuntResult
# End of function
}
