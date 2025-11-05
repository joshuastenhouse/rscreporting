################################################
# Creating the Get-RSCSnapshotAnalytics function
################################################
Function Get-RSCSnapshotAnalytics {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that returns the data threat analytics for the snapshot ID specified.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.
.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
A valid ObjectID in RSC, use Get-RSCObjects to obtain.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSnapshotAnalytics -SnapshotID "48987e0e-cb80-56f0-ba03-df0aa75ec023" 
This example returns the data threat analytics for the snapshot ID specified.

.NOTES
Author: Joshua Stenhouse
Date: 11/04/2025
#>
################################################
# Paramater Config
################################################
	Param
    (
        [Parameter(Mandatory=$true)]$SnapshotID
    )
################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Running Main Function
################################################
$RSCGraphQL = @{"operationName" = "RadarInvestigationBrowseListQuery";

"variables" = @{
    "snapshotId" = "$SnapshotID"
    "path" = ""
    "filter" = @{
        "deltaType" = "NODES_CREATED","NODES_MODIFIED","NODES_DELETED"
        }
    "first" = 100
};

"query" = "query RadarInvestigationBrowseListQuery(`$after: String, `$filter: SnapshotDeltaFilterInput, `$first: Int, `$path: String!, `$searchPrefix: String, `$snapshotId: UUID!, `$quarantineFilters: [QuarantineFilter!], `$workloadFieldsArg: WorkloadFieldsInput) {
  snapshotFilesDeltaV2(
    after: `$after
    filter: `$filter
    first: `$first
    path: `$path
    searchPrefix: `$searchPrefix
    snapshotFid: `$snapshotId
    quarantineFilters: `$quarantineFilters
    workloadFieldsArg: `$workloadFieldsArg
  ) {
    edges {
      cursor
      node {
        file {
          absolutePath
          displayPath
          filename
          fileMode
          size
          path
          lastModified
          ...WorkloadFieldsFragment
          __typename
        }
        previousSnapshotQuarantineInfo {
          isQuarantined
          containsQuarantinedFiles
          __typename
        }
        childrenDeltas {
          deltaType
          deltaAmount
          __typename
        }
        selfDeltas {
          deltaType
          deltaAmount
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

fragment WorkloadFieldsFragment on SnapshotFile {
  workloadFields {
    o365Item {
      id
      metadata {
        objectType
        snapshotNum
        snappableId
        snappableType
        __typename
      }
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
Try
{
$RSCGraphQLResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Headers $RSCSessionHeader -Body $($RSCGraphQL | ConvertTo-JSON -Depth 10)
$RSCGraphQLData = $RSCGraphQLResponse.data.snapshotFilesDeltaV2.edges.node
}
Catch
{
$ErrorMessage = $_.ErrorDetails; "ERROR: $ErrorMessage"
}
################################################
# Processing GraphQL Data
################################################
# Creating array
$ObjectSnapshotPaths = [System.Collections.ArrayList]@()
# Processing paths
ForEach ($SnapshotPath in $RSCGraphQLData)
{
# Setting variables
$Path = $SnapshotPath.file.displayPath
$PathType = $SnapshotPath.file.fileMode
$LastModifiedUNIX = $SnapshotPath.file.lastModified
$PathSizeBytes = $SnapshotPath.file.size
# Converting date time object 
IF($LastModifiedUNIX -ne $null){$LastModified = Convert-RSCUNIXTime $LastModifiedUNIX}ELSE{$LastModified = $null}
# Getting file analytics
$FilesCreated = $SnapshotPath.childrenDeltas | Where-Object {$_.deltaType -eq "NODES_CREATED"} | Select-Object -ExpandProperty deltaAmount 
$FilesDeleted = $SnapshotPath.childrenDeltas | Where-Object {$_.deltaType -eq "NODES_DELETED"} | Select-Object -ExpandProperty deltaAmount 
$FilesModified = $SnapshotPath.childrenDeltas | Where-Object {$_.deltaType -eq "NODES_MODIFIED"} | Select-Object -ExpandProperty deltaAmount 
# Getting size analytics
$CreatedBytes = $SnapshotPath.childrenDeltas | Where-Object {$_.deltaType -eq "BYTES_CREATED"} | Select-Object -ExpandProperty deltaAmount 
$DeletedBytes = $SnapshotPath.childrenDeltas | Where-Object {$_.deltaType -eq "BYTES_DELETED"} | Select-Object -ExpandProperty deltaAmount 
$ModifiedBytes = $SnapshotPath.childrenDeltas | Where-Object {$_.deltaType -eq "BYTES_MODIFIED"} | Select-Object -ExpandProperty deltaAmount 
# Converting sizes
IF($PathSizeBytes -ne $null){$PathSizeGB = $PathSizeBytes / 1000 / 1000 / 1000}ELSE{$PathSizeGB = $null}
IF($CreatedBytes -ne $null){$CreatedGB = $CreatedBytes / 1000 / 1000 / 1000}ELSE{$CreatedGB = $null}
IF($DeletedBytes -ne $null){$DeletedGB = $DeletedBytes / 1000 / 1000 / 1000}ELSE{$DeletedGB = $null}
IF($ModifiedBytes -ne $null){$ModifiedGB = $ModifiedBytes / 1000 / 1000 / 1000}ELSE{$ModifiedGB = $null}
# Rounding
IF($PathSizeGB -ne $null){$PathSizeGB = [Math]::Round($PathSizeGB,2)}
IF($CreatedGB -ne $null){$CreatedGB = [Math]::Round($CreatedGB,2)}
IF($DeletedGB -ne $null){$DeletedGB = [Math]::Round($DeletedGB,2)}
IF($ModifiedGB -ne $null){$ModifiedGB = [Math]::Round($ModifiedGB,2)}
# Calculating change rate percentage
$TotalChangedBytes = $CreatedBytes + $ModifiedBytes
$ChangeRate = $TotalChangedBytes / $PathSizeBytes * 100
IF($ChangeRate -ne $null){$ChangeRate = [Math]::Round($ChangeRate,2)}
# Creating object
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "Path" -Value $Path
$Object | Add-Member -MemberType NoteProperty -Name "PathType" -Value $PathType
$Object | Add-Member -MemberType NoteProperty -Name "LastModified" -Value $LastModified
$Object | Add-Member -MemberType NoteProperty -Name "FilesCreated" -Value $FilesCreated
$Object | Add-Member -MemberType NoteProperty -Name "FilesDeleted" -Value $FilesDeleted
$Object | Add-Member -MemberType NoteProperty -Name "FilesModified" -Value $FilesModified
$Object | Add-Member -MemberType NoteProperty -Name "PathSizeGB" -Value $PathSizeGB
$Object | Add-Member -MemberType NoteProperty -Name "CreatedGB" -Value $CreatedGB
$Object | Add-Member -MemberType NoteProperty -Name "DeletedGB" -Value $DeletedGB
$Object | Add-Member -MemberType NoteProperty -Name "ModifiedGB" -Value $ModifiedGB
$Object | Add-Member -MemberType NoteProperty -Name "PathSizeBytes" -Value $PathSizeBytes
$Object | Add-Member -MemberType NoteProperty -Name "CreatedBytes" -Value $CreatedBytes
$Object | Add-Member -MemberType NoteProperty -Name "DeletedBytes" -Value $DeletedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ModifiedBytes" -Value $ModifiedBytes
$Object | Add-Member -MemberType NoteProperty -Name "TotalChangedBytes" -Value $TotalChangedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ChangeRatePC" -Value $ChangeRate
# Adding to the array
$ObjectSnapshotPaths.Add($Object) | Out-Null
# End of for each path below
}
# End of for each path above

# Creating array for snapshot result
$ObjectSnapshotAnalytics = [System.Collections.ArrayList]@()
# Summarizing data across all paths
$TotalSnapshotPaths = $ObjectSnapshotPaths | Measure-Object | Select-Object -ExpandProperty Count
# If not paths, snapshot has not been succesfully indexed
IF($TotalSnapshotPaths -gt 0)
{
$TotalFilesCreated = $ObjectSnapshotPaths | Measure-Object -Sum FilesCreated | Select-Object -ExpandProperty Sum
$TotalFilesDeleted = $ObjectSnapshotPaths | Measure-Object -Sum FilesDeleted | Select-Object -ExpandProperty Sum
$TotalFilesModified = $ObjectSnapshotPaths | Measure-Object -Sum FilesModified | Select-Object -ExpandProperty Sum
$TotalSizeBytes = $ObjectSnapshotPaths | Measure-Object -Sum PathSizeBytes | Select-Object -ExpandProperty Sum
$TotalCreatedBytes = $ObjectSnapshotPaths | Measure-Object -Sum CreatedBytes | Select-Object -ExpandProperty Sum
$TotalDeletedBytes = $ObjectSnapshotPaths | Measure-Object -Sum DeletedBytes | Select-Object -ExpandProperty Sum
$TotalModifiedBytes = $ObjectSnapshotPaths | Measure-Object -Sum ModifiedBytes | Select-Object -ExpandProperty Sum 
$TotalChangedBytes = $ObjectSnapshotPaths | Measure-Object -Sum TotalChangedBytes | Select-Object -ExpandProperty Sum 
# Converting sizes
IF($TotalSizeBytes -ne $null){$TotalSizeGB = $TotalSizeBytes / 1000 / 1000 / 1000}ELSE{$TotalSizeGB = $null}
IF($TotalCreatedBytes -ne $null){$TotalCreatedGB = $TotalCreatedBytes / 1000 / 1000 / 1000}ELSE{$TotalCreatedGB = $null}
IF($TotalDeletedBytes -ne $null){$TotalDeletedGB = $TotalDeletedBytes / 1000 / 1000 / 1000}ELSE{$TotalDeletedGB = $null}
IF($TotalModifiedBytes -ne $null){$TotalModifiedGB = $TotalModifiedBytes / 1000 / 1000 / 1000}ELSE{$TotalModifiedGB = $null}
# Rounding
IF($TotalSizeGB -ne $null){$TotalSizeGB = [Math]::Round($TotalSizeGB,2)}
IF($TotalCreatedGB -ne $null){$TotalCreatedGB = [Math]::Round($TotalCreatedGB,2)}
IF($TotalDeletedGB -ne $null){$TotalDeletedGB = [Math]::Round($TotalDeletedGB,2)}
IF($TotalModifiedGB -ne $null){$TotalModifiedGB = [Math]::Round($TotalModifiedGB,2)}
# Calculating change rate percentage
$TotalChangedBytes = $TotalCreatedBytes + $TotalModifiedBytes
$ChangeRate = $TotalChangedBytes / $TotalSizeBytes * 100
IF($ChangeRate -ne $null){$ChangeRate = [Math]::Round($ChangeRate,2)}
}
ELSE
{
# Snapshot has not been indexed, nulling all values
$TotalFilesCreated = $null
$TotalFilesDeleted = $null
$TotalFilesModified = $null
$TotalSizeGB = $null
$TotalCreatedGB = $null
$TotalDeletedGB = $null
$ModifiedGB = $null
$ChangeRate = $null
$TotalSizeBytes = $null
$TotalCreatedBytes = $null
$TotalDeletedBytes = $null
$TotalModifiedBytes = $null
$TotalChangedBytes = $null
}
# Creating object
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "Paths" -Value $TotalSnapshotPaths
$Object | Add-Member -MemberType NoteProperty -Name "FilesCreated" -Value $TotalFilesCreated
$Object | Add-Member -MemberType NoteProperty -Name "FilesDeleted" -Value $TotalFilesDeleted
$Object | Add-Member -MemberType NoteProperty -Name "FilesModified" -Value $TotalFilesModified
$Object | Add-Member -MemberType NoteProperty -Name "SizeGB" -Value $TotalSizeGB
$Object | Add-Member -MemberType NoteProperty -Name "CreatedGB" -Value $TotalCreatedGB
$Object | Add-Member -MemberType NoteProperty -Name "DeletedGB" -Value $TotalDeletedGB
$Object | Add-Member -MemberType NoteProperty -Name "ModifiedGB" -Value $ModifiedGB
$Object | Add-Member -MemberType NoteProperty -Name "ChangeRatePC" -Value $ChangeRate
$Object | Add-Member -MemberType NoteProperty -Name "SizeBytes" -Value $TotalSizeBytes
$Object | Add-Member -MemberType NoteProperty -Name "CreatedBytes" -Value $TotalCreatedBytes
$Object | Add-Member -MemberType NoteProperty -Name "DeletedBytes" -Value $TotalDeletedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ModifiedBytes" -Value $TotalModifiedBytes
$Object | Add-Member -MemberType NoteProperty -Name "TotalChangedBytes" -Value $TotalChangedBytes
# Adding to the array
$ObjectSnapshotAnalytics.Add($Object) | Out-Null

# Returning Result
Return $ObjectSnapshotAnalytics
}