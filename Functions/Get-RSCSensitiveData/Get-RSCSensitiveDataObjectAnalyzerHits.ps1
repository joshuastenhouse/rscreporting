################################################
# Function - Get-RSCSensitiveDataObjectAnalyzerHits - Getting All Objects Scanned for Sensitive data in RSC
################################################
Function Get-RSCSensitiveDataObjectAnalyzerHits {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of sensitive data discovery analyzer hits across all objects.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSensitiveDataObjectAnalyzerHits
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Querying RSC GraphQL API
################################################
# Creating array for objects
$RSCList = @()
# Getting date in correct format
$UTCDate = [System.DateTime]::UtcNow.ToString("yyyy-MM-dd")
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "ObjectsListTableQuery";

"variables" = @{
    "day" = "$UTCDate"
    "timezone" = "America/New_York"
    "objectTypes" = "CDM","VSPHERE_VIRTUAL_MACHINE","LINUX_FILESET","SHARE_FILESET","WINDOWS_FILESET","NUTANIX_VIRTUAL_MACHINE","HYPERV_VIRTUAL_MACHINE","VOLUME_GROUP","NAS_FILESET"
    "searchObjectName" = ""
    "sortBy" = "NAME"
    "sortOrder" = "DESC"
    "includeWhitelistedResults" = $false
    "first" = 50}

"query" = "query ObjectsListTableQuery(`$day: String!, `$timezone: String!, `$objectTypes: [DataGovObjectType!]!, `$searchObjectName: String, `$sortBy: String, `$sortOrder: SortOrder, `$includeWhitelistedResults: Boolean, `$first: Int!, `$after: String) {
  policyObjs(day: `$day, timezone: `$timezone, workloadTypes: `$objectTypes, searchObjectName: `$searchObjectName, sortBy: `$sortBy, sortOrder: `$sortOrder, includeWhitelistedResults: `$includeWhitelistedResults, first: `$first, after: `$after) {
    edges {
      cursor
      node {
        ...PolicyObjOptimizedFragment
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
    __typename
  }
}

fragment PolicyObjOptimizedFragment on PolicyObj {
  id
  snapshotFid
  snapshotTimestamp
  osType
  shareType
  analysisStatus
  rootFileResult {
    hits {
      totalHits
      violations
      permittedHits
      violationsDelta
      totalHitsDelta
      __typename
    }
    analyzerGroupResults {
      ...AnalyzerGroupResultFragment
      __typename
    }
    filesWithHits {
      totalHits
      violations
      permittedHits
      violationsDelta
      totalHitsDelta
      __typename
    }
    openAccessFiles {
      totalHits
      violations
      permittedHits
      violationsDelta
      totalHitsDelta
      __typename
    }
    openAccessFolders {
      totalHits
      violations
      permittedHits
      violationsDelta
      totalHitsDelta
      __typename
    }
    openAccessFilesWithHits {
      totalHits
      violations
      permittedHits
      violationsDelta
      totalHitsDelta
      __typename
    }
    staleFiles {
      totalHits
      violations
      permittedHits
      violationsDelta
      totalHitsDelta
      __typename
    }
    staleFilesWithHits {
      totalHits
      violations
      permittedHits
      violationsDelta
      totalHitsDelta
      __typename
    }
    openAccessStaleFiles {
      totalHits
      violations
      permittedHits
      violationsDelta
      totalHitsDelta
      __typename
    }
    numActivities
    numActivitiesDelta
    __typename
  }
  snappable {
    ...SnappableFragment
    __typename
  }
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
      permittedHits
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
    permittedHits
    violationsDelta
    totalHitsDelta
    __typename
  }
  __typename
}

fragment SnappableFragment on HierarchyObject {
  id
  name
  objectType
  slaAssignment
  logicalPath {
    fid
    name
    objectType
    __typename
  }
  physicalPath {
    fid
    name
    objectType
    __typename
  }
  effectiveSlaDomain {
    id
    name
    __typename
  }
  ... on VsphereVm {
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  ... on LinuxFileset {
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  ... on ShareFileset {
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  ... on WindowsFileset {
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  ... on NutanixVm {
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  ... on HyperVVirtualMachine {
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  ... on VolumeGroup {
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  ... on O365Onedrive {
    userPrincipalName
    __typename
  }
  ... on O365SharepointDrive {
    url
    __typename
  }
  ... on AzureNativeVirtualMachine {
    region
    resourceGroup {
      subscription {
        id
        name
        __typename
      }
      __typename
    }
    __typename
  }
  ... on AzureNativeManagedDisk {
    region
    resourceGroup {
      subscription {
        id
        name
        __typename
      }
      __typename
    }
    __typename
  }
  ... on CloudDirectNasExport {
    exportPath
    __typename
  }
  ... on CloudDirectHierarchyObject {
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListResponse.data.policyObjs.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.policyObjs.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.policyObjs.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.policyObjs.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCSDDObjects = [System.Collections.ArrayList]@()
$RSCSDDObjectAnalyzerHits = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($SDDObject in $RSCObjectList)
{
# Setting variables
$ObjectName = $SDDObject.snappable.name
$ObjectID = $SDDObject.snappable.id
$ObjectType = $SDDObject.snappable.objectType
$ObjectSLAAssignment = $SDDObject.snappable.slaAssignment
$RootFileResult = $SDDObject.rootFileResult
$AnalysisStatus = $SDDObject.analysisStatus
$SnapshotID = $SDDObject.snapshotFid
# Creating URL
$ObjectURL = $RSCURL + "/sonar/objects/detail/" + $ObjectID + "/" + $SnapshotID + "/files"
# Last snapshot analyzed
$LastSnapshotMS = $SDDObject.snapshotTimestamp
$LastSnapshotUTC = [datetimeoffset]::FromUnixTimeMilliseconds($LastSnapshotMS).DateTime
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($LastSnapshotUTC -ne $null){$LastSnapshotTimespan = New-TimeSpan -Start $LastSnapshotUTC -End $UTCDateTime;$LastSnapshotHoursSince = $LastSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$LastSnapshotHoursSince = [Math]::Round($LastSnapshotHoursSince,1)}ELSE{$LastSnapshotHoursSince = $null}
# Analyzer Group results
$AnalyzerGroupResults = $RootFileResult.analyzerGroupResults
# Iterating through analyzer hits
ForEach($Result in $AnalyzerGroupResults)
{
$Analyzer = $Result.analyzerGroup.name
$AnalyzerID = $Result.analyzerGroup.id
$TotalHits = $Result.hits.totalHits
$TotalViolations = $Result.hits.violations
$TotalPermittedHits = $Result.hits.permittedHits
$TotalViolationsDelta = $Result.hits.violationsDelta
$TotalHitsDelta = $Result.hits.totalHitsDelta
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
# Snapshot info
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $LastSnapshotUTC
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
# Analyzer hits
$Object | Add-Member -MemberType NoteProperty -Name "Analyzer" -Value $Analyzer
$Object | Add-Member -MemberType NoteProperty -Name "AnalyzerID" -Value $AnalyzerID
$Object | Add-Member -MemberType NoteProperty -Name "TotalHits" -Value $TotalHits
$Object | Add-Member -MemberType NoteProperty -Name "TotalViolations" -Value $TotalViolations
$Object | Add-Member -MemberType NoteProperty -Name "TotalPermittedHits" -Value $TotalPermittedHits
$Object | Add-Member -MemberType NoteProperty -Name "TotalViolationsDelta" -Value $TotalViolationsDelta
$Object | Add-Member -MemberType NoteProperty -Name "TotalHitsDelta" -Value $TotalHitsDelta
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCSDDObjectAnalyzerHits.Add($Object) | Out-Null
}
# Total hits
$TotalHits = $RootFileResult.hits.totalHits
$TotalViolations = $RootFileResult.hits.violations
$TotalPermittedHits = $RootFileResult.hits.permittedHits
$TotalViolationsDelta = $RootFileResult.hits.violationsDelta
$TotalHitsDelta = $RootFileResult.hits.totalHitsDelta
# FilesWithHits
$FilesWithHits = $RootFileResult.filesWithHits.totalHits
$FilesWithHitsViolations = $RootFileResult.filesWithHits.violations
$FilesWithHitsPermittedHits = $RootFileResult.filesWithHits.permittedHits
$FilesWithHitsViolationsDelta = $RootFileResult.filesWithHits.violationsDelta
$FilesWithHitsDelta = $RootFileResult.filesWithHits.totalHitsDelta
# OpenAccessFiles
$OpenAccessFilesHits = $RootFileResult.openAccessFiles.totalHits
$OpenAccessFilesViolations = $RootFileResult.openAccessFiles.violations
$OpenAccessFilesPermittedHits = $RootFileResult.openAccessFiles.permittedHits
$OpenAccessFilesViolationsDelta = $RootFileResult.openAccessFiles.violationsDelta
$OpenAccessFilesHitsDelta = $RootFileResult.openAccessFiles.totalHitsDelta
# OpenAccessFolders
$OpenAccessFoldersHits = $RootFileResult.openAccessFolders.totalHits
$OpenAccessFoldersViolations = $RootFileResult.openAccessFolders.violations
$OpenAccessFoldersPermittedHits = $RootFileResult.openAccessFolders.permittedHits
$OpenAccessFoldersViolationsDelta = $RootFileResult.openAccessFolders.violationsDelta
$OpenAccessFoldersHitsDelta = $RootFileResult.openAccessFolders.totalHitsDelta
# OpenAccessFilesWithHits
$OpenAccessFilesWithHits = $RootFileResult.openAccessFilesWithHits.totalHits
$OpenAccessFilesWithHitsViolations = $RootFileResult.openAccessFilesWithHits.violations
$OpenAccessFilesWithHitsPermittedHits = $RootFileResult.openAccessFilesWithHits.permittedHits
$OpenAccessFilesWithHitsViolationsDelta = $RootFileResult.openAccessFilesWithHits.violationsDelta
$OpenAccessFilesWithHitsDelta = $RootFileResult.openAccessFilesWithHits.totalHitsDelta
# StaleFilesWithHits
$StaleFilesWithHits = $RootFileResult.staleFilesWithHits.totalHits
$StaleFilesWithHitsViolations = $RootFileResult.staleFilesWithHits.violations
$StaleFilesWithHitsPermittedHits = $RootFileResult.staleFilesWithHits.permittedHits
$StaleFilesWithHitsViolationsDelta = $RootFileResult.staleFilesWithHits.violationsDelta
$StaleFilesWithHitsDelta = $RootFileResult.staleFilesWithHits.totalHitsDelta
# OpenAccessStaleFiles
$OpenAccessStaleFilesHits = $RootFileResult.openAccessStaleFiles.totalHits
$OpenAccessStaleFilesViolations = $RootFileResult.openAccessStaleFiles.violations
$OpenAccessStaleFilesPermittedHits = $RootFileResult.openAccessStaleFiles.permittedHits
$OpenAccessStaleFilesViolationsDelta = $RootFileResult.openAccessStaleFiles.violationsDelta
$OpenAccessStaleFilesDelta = $RootFileResult.openAccessStaleFiles.totalHitsDelta
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $ObjectSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "AnalysisStatus" -Value $AnalysisStatus
$Object | Add-Member -MemberType NoteProperty -Name "LastAnalyzedSnapshotUTC" -Value $LastSnapshotUTC
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $LastSnapshotHoursSince
# Snapshot info
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $LastSnapshotUTC
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
# TotalHits
$Object | Add-Member -MemberType NoteProperty -Name "TotalHits" -Value $TotalHits
$Object | Add-Member -MemberType NoteProperty -Name "TotalViolations" -Value $TotalViolations
$Object | Add-Member -MemberType NoteProperty -Name "TotalPermittedHits" -Value $TotalPermittedHits
$Object | Add-Member -MemberType NoteProperty -Name "TotalViolationsDelta" -Value $TotalViolationsDelta
$Object | Add-Member -MemberType NoteProperty -Name "TotalHitsDelta" -Value $TotalHitsDelta
# FilesWithHits
$Object | Add-Member -MemberType NoteProperty -Name "FilesWithHits" -Value $FilesWithHits
$Object | Add-Member -MemberType NoteProperty -Name "FilesWithHitsViolations" -Value $FilesWithHitsViolations
$Object | Add-Member -MemberType NoteProperty -Name "FilesWithHitsPermittedHits" -Value $FilesWithHitsPermittedHits
$Object | Add-Member -MemberType NoteProperty -Name "FilesWithHitsViolationsDelta" -Value $FilesWithHitsViolationsDelta
$Object | Add-Member -MemberType NoteProperty -Name "FilesWithHitsDelta" -Value $FilesWithHitsDelta
# OpenAccessFiles
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesHits" -Value $OpenAccessFilesHits
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesViolations" -Value $OpenAccessFilesViolations
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesPermittedHits" -Value $OpenAccessFilesPermittedHits
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesViolationsDelta" -Value $OpenAccessFilesViolationsDelta
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesHitsDelta" -Value $OpenAccessFilesHitsDelta
# OpenAccessFolders
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFoldersHits" -Value $OpenAccessFoldersHits
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFoldersViolations" -Value $OpenAccessFoldersViolations
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFoldersPermittedHits" -Value $OpenAccessFoldersPermittedHits
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFoldersViolationsDelta" -Value $OpenAccessFoldersViolationsDelta
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFoldersHitsDelta" -Value $OpenAccessFoldersHitsDelta
# OpenAccessFilesWithHits
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesWithHits" -Value $OpenAccessFilesWithHits
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesWithHitsViolations" -Value $OpenAccessFilesWithHitsViolations
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesWithHitsPermittedHits" -Value $OpenAccessFilesWithHitsPermittedHits
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesWithHitsViolationsDelta" -Value $OpenAccessFilesWithHitsViolationsDelta
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessFilesWithHitsDelta" -Value $OpenAccessFilesWithHitsDelta
# StaleFilesWithHits
$Object | Add-Member -MemberType NoteProperty -Name "StaleFilesWithHits" -Value $StaleFilesWithHits
$Object | Add-Member -MemberType NoteProperty -Name "StaleFilesWithHitsViolations" -Value $StaleFilesWithHitsViolations
$Object | Add-Member -MemberType NoteProperty -Name "StaleFilesWithHitsPermittedHits" -Value $StaleFilesWithHitsPermittedHits
$Object | Add-Member -MemberType NoteProperty -Name "StaleFilesWithHitsViolationsDelta" -Value $StaleFilesWithHitsViolationsDelta
$Object | Add-Member -MemberType NoteProperty -Name "StaleFilesWithHitsDelta" -Value $StaleFilesWithHitsDelta
# OpenAccessStaleFiles
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessStaleFilesHits" -Value $OpenAccessStaleFilesHits
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessStaleFilesViolations" -Value $OpenAccessStaleFilesViolations
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessStaleFilesPermittedHits" -Value $OpenAccessStaleFilesPermittedHits
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessStaleFilesViolationsDelta" -Value $OpenAccessStaleFilesViolationsDelta
$Object | Add-Member -MemberType NoteProperty -Name "OpenAccessStaleFilesDelta" -Value $OpenAccessStaleFilesDelta
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCSDDObjects.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Sorting by total hits by default
$RSCSDDObjectAnalyzerHits = $RSCSDDObjectAnalyzerHits | Sort-Object TotalHits -Descending
# Returning array
Return $RSCSDDObjectAnalyzerHits
# End of function
}