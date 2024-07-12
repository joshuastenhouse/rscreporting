################################################
# Creating the Get-RSCSensitiveDataFiles function
################################################
Function Get-RSCSensitiveDataFiles {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of files with sensitive data for the ObjectID specified.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.
.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
A valid ObjectID with sensitive data discovery configured, use Get-RSCSensitiveDataObjects to obtain.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSensitiveDataFiles -ObjectID "403403449-434534-435345-345345"
This example returns a list of all the sensitive files found on the ObjectID specified.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$ObjectID
    )

# Example: $ObjectSnapshots= Get-RSCObjectSnapshots -ObjectID "$ObjectID"

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting objects
$RSCSensitiveDataObjects = Get-RSCSensitiveDataObjectAnalyzerHits
# Selecting object based on ID
$RSCSensitiveDataObject = $RSCSensitiveDataObjects | Where-Object {$_.ObjectID -eq $ObjectID} | Select -First 1
# Selecting snapshot & object info
$ObjectURL = $RSCSensitiveDataObject.URL
$ObjectName = $RSCSensitiveDataObject.Object
$ObjectType = $RSCSensitiveDataObject.ObjectType
$SnapshotID = $RSCSensitiveDataObject.SnapshotID
# If nulls, breaking
IF($RSCSensitiveDataObjects -eq $null)
{
Write-Error "ERROR: Object not found on Get-RSCSensitiveDataObjects, check the ObjectID and try again.."
Start-Sleep 2
Break
}
IF($SnapshotID -eq $null)
{
Write-Error "ERROR: SnapshotID not found on Get-RSCSensitiveDataObjects, check the Object has a SnapshotID and try again.."
Start-Sleep 2
Break
}
Write-Host "SnapshotID: $SnapshotID"
################################################
# Running Main Function
################################################
$ObjectFileList = @() 
# Creating array for path
$snappablePaths = [System.Collections.ArrayList]@()
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "snappableFid" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "stdPath" -Value ""
$snappablePaths.Add($Object) | Out-Null
# Creating graphQL
$RSCGraphQL = @{"operationName" = "ObjectFilesQuery";

"variables" = @{
"snappableFid" = "$ObjectID"
"snapshotFid" = "$SnapshotID"
"first" = 50
"timezone" = "America/New_York"
"filters" = @{
        "fileType" = "HITS"
        "searchText" = ""
        "whitelistEnabled" = $true
        }
"sort" = @{
        "sortOrder" = "DESC"
        "sortBy" = "HITS"
}
};

"query" = "query ObjectFilesQuery(`$first: Int!, `$after: String, `$snappableFid: String!, `$snapshotFid: String!, `$filters: ListFileResultFiltersInput, `$sort: FileResultSortInput, `$timezone: String!) {
  policyObj(snappableFid: `$snappableFid, snapshotFid: `$snapshotFid) {
  id: snapshotFid
  fileResultConnection(first: `$first, after: `$after, filter: `$filters, sort: `$sort, timezone: `$timezone) {
      edges {
        cursor
        node {
          ...DiscoveryFileFragment
          __typename
        }
        __typename
      }
      pageInfo {
        startCursor
        endCursor
        hasNextPage
        hasPreviousPage
        __typename
      }
      hasLatestData
      __typename
    }
    __typename
  }
}

fragment DiscoveryFileFragment on FileResult {
  nativePath
  stdPath
  filename
  mode
  size
  lastAccessTime
  lastModifiedTime
  directory
  numDescendantFiles
  numDescendantErrorFiles
  numDescendantSkippedExtFiles
  numDescendantSkippedSizeFiles
  errorCode
  hits {
    totalHits
    violations
    violationsDelta
    totalHitsDelta
    __typename
  }
  filesWithHits {
    totalHits
    violations
    __typename
  }
  openAccessFilesWithHits {
    totalHits
    violations
    __typename
  }
  staleFilesWithHits {
    totalHits
    violations
    __typename
  }
  analyzerGroupResults {
    ...AnalyzerGroupResultFragment
    __typename
  }
  sensitiveFiles {
    highRiskFileCount {
      totalCount
      violatedCount
      __typename
    }
    mediumRiskFileCount {
      totalCount
      violatedCount
      __typename
    }
    lowRiskFileCount {
      totalCount
      violatedCount
      __typename
    }
    __typename
  }
  openAccessType
  stalenessType
  numActivities
  numActivitiesDelta
  __typename
}

fragment AnalyzerGroupResultFragment on AnalyzerGroupResult {
  analyzerGroup {
    groupType
    id
    name
    __typename
  }
  analyzerResults {
    hits {
      totalHits
      violations
      __typename
    }
    analyzer {
      id
      name
      analyzerType
      __typename
    }
    __typename
  }
  hits {
    totalHits
    violations
    violationsDelta
    totalHitsDelta
    __typename
  }
  __typename
}"
}
# Converting to JSON
$RSCGraphQLJSON = $RSCGraphQL | ConvertTo-Json -Depth 32
# Converting back to PS object for editing of variables
$RSCGraphQLJSONObject = $RSCGraphQLJSON | ConvertFrom-Json
# Adding variables specified
$RSCGraphQLJSONObject.variables.filters | Add-Member -MemberType NoteProperty "snappablePaths" -Value $snappablePaths
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$ObjectFilesResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQLJSONObject | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$ObjectFileList += $ObjectFilesResponse.data.policyObj.fileResultConnection.edges.node
# Logging iterations (as it may take a while)
$FileCount = 0
Write-host "GettingFiles: 0-50"
# Getting all results from paginations
While ($ObjectFilesResponse.data.policyObj.fileResultConnection.pageInfo.hasNextPage) 
{
# Logging
$FileCount = $FileCount + 50; $FileCountNext = $FileCount + 50
Write-host "GettingFiles: $FileCount-$FileCountNext"
# Getting next set
$RSCGraphQLJSONObject.variables | Add-Member -MemberType NoteProperty "after" -Value $ObjectFilesResponse.data.policyObj.fileResultConnection.pageInfo.endCursor -Force
$ObjectFilesResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQLJSONObject | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$ObjectFileList += $ObjectFilesResponse.data.policyObj.fileResultConnection.edges.node
}
# Logging
$ObjectFileListCount = $ObjectFileList | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "--------------------------
FilesWithHits: $ObjectFileListCount
Processing, this may take a few minutes..."
################################################
# Processing List
################################################
# Creating array
$ObjectFiles = [System.Collections.ArrayList]@()
# Processing snapshots
ForEach ($ObjectFile in $ObjectFileList)
{
# Setting variables
$FilePath = $ObjectFile.nativePath
$FileName = $ObjectFile.filename
$FileSizeBytes = $ObjectFile.size
$LastAccessTimeEPOCH = $ObjectFile.lastAccessTime
$LastModifiedTimeEPOCH = $ObjectFile.lastModifiedTime
$TotalHits = $ObjectFile.hits.totalHits
$Violations = $ObjectFile.hits.violations
$PermittedHits = $ObjectFile.hits.permittedHits
$ViolationsDelta = $ObjectFile.hits.violationsDelta
$TotalHitsDelta = $ObjectFile.hits.totalHitsDelta
$OpenAccessType = $ObjectFile.openAccessType
$StalenessType = $ObjectFile.stalenessType
# Converting times
IF($LastAccessTimeEPOCH -ne $null){$LastAccessTime = (Get-Date -Date "01-01-1970") + ([System.TimeSpan]::FromSeconds(($LastAccessTimeEPOCH)))}ELSE{$LastAccessTime = $null}
IF($LastModifiedTimeEPOCH -ne $null){$LastModifiedTime = (Get-Date -Date "01-01-1970") + ([System.TimeSpan]::FromSeconds(($LastModifiedTimeEPOCH)))}ELSE{$LastModifiedTime = $null}
# Converting size
$FileSizeKB = $FileSizeBytes / 1000
$FileSizeKB = [Math]::Round($FileSizeKB)
$FileSizeMB = $FileSizeBytes / 1000 / 1000
$FileSizeMB = [Math]::Round($FileSizeMB,2)
# Analyzers
$AnalyzerGroupResults = $ObjectFile.analyzerGroupResults
$TotalAnalyzersCount = $AnalyzerGroupResults | Measure-Object | Select-Object -ExpandProperty Count
$AnalyzersWithHits = $AnalyzerGroupResults | Where-Object {$_.hits.totalhits -gt 0}
$AnalyzersWithNoHits = $AnalyzerGroupResults | Where-Object {$_.hits.totalhits -eq 0}
$AnalyzersWithHitsCount = $AnalyzersWithHits | Measure-Object | Select-Object -ExpandProperty Count
$AnalyzersWithNoHitsCount = $AnalyzersWithNoHits | Measure-Object | Select-Object -ExpandProperty Count
# Getting analyzer names with hits
$AnalyzersWithHitsNames = $AnalyzersWithHits | Select-Object -ExpandProperty analyzerGroup | Select-Object -ExpandProperty Name
$AnalyzersWithHitsIDs = $AnalyzersWithHits | Select-Object -ExpandProperty analyzerGroup | Select-Object -ExpandProperty id
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "FilePath" -Value $FilePath
$Object | Add-Member -MemberType NoteProperty -Name "FileName" -Value $FileName
$Object | Add-Member -MemberType NoteProperty -Name "SizeBytes" -Value $FileSizeBytes
$Object | Add-Member -MemberType NoteProperty -Name "SizeKB" -Value $FileSizeKB
$Object | Add-Member -MemberType NoteProperty -Name "SizeMB" -Value $FileSizeMB
$Object | Add-Member -MemberType NoteProperty -Name "TotalHits" -Value $TotalHits
$Object | Add-Member -MemberType NoteProperty -Name "Violations" -Value $Violations
$Object | Add-Member -MemberType NoteProperty -Name "PermittedHits" -Value $PermittedHits
$Object | Add-Member -MemberType NoteProperty -Name "TotalHitsDelta" -Value $TotalHitsDelta
$Object | Add-Member -MemberType NoteProperty -Name "ViolationsDelta" -Value $ViolationsDelta
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessType" -Value $OpenAccessType
$Object | Add-Member -MemberType NoteProperty -Name "StalenessType" -Value $StalenessType
$Object | Add-Member -MemberType NoteProperty -Name "LastModified" -Value $LastModifiedTime
$Object | Add-Member -MemberType NoteProperty -Name "LastAccessed" -Value $LastAccessTime
$Object | Add-Member -MemberType NoteProperty -Name "TotalAnalyzers" -Value $TotalAnalyzersCount
$Object | Add-Member -MemberType NoteProperty -Name "AnalyzersWithHits" -Value $AnalyzersWithHitsCount
$Object | Add-Member -MemberType NoteProperty -Name "AnalyzersWithoutHits" -Value $AnalyzersWithNoHitsCount
$Object | Add-Member -MemberType NoteProperty -Name "AnalyzersWithHitsNames" -Value $AnalyzersWithHitsNames
$Object | Add-Member -MemberType NoteProperty -Name "AnalyzersWithHitsIDs" -Value $AnalyzersWithHitsIDs
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
$ObjectFiles.Add($Object) | Out-Null
# End of for each file below
}
# End of for each file above

# Sorting by hits
$ObjectFiles = $ObjectFiles | Sort-Object TotalHits -Descending

# Found a bug whereby it doesn't let me export to CSV unless I select them again by the count
$ObjectFiles = $ObjectFiles | Select-Object -First $ObjectFileListCount

# Returning Result
Return $ObjectFiles
}