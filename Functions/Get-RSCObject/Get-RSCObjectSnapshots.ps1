################################################
# Creating the Get-RSCObjectSnapshots function
################################################
Function Get-RSCObjectSnapshots {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that returns an array of snapshots for the ObjectID specified with a configurable max number of snapshots.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.
.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
A valid ObjectID in RSC, use Get-RSCObjects to obtain.
.PARAMETER MaxSnapshots
Uses 30 by default unless specified otherwise with this param.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectSnapshots -ObectID "32ffrferf-erferf-erferfe" -MaxSnapshots 50
This example returns the last 50 snapshots for the ObjectID specified.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
[CmdletBinding(DefaultParameterSetName = "List")]
Param(
      [Parameter(
          ParameterSetName = "ObjectID",
          Mandatory = $true, 
          ValueFromPipelineByPropertyName = $true
      )]
      [String]$ObjectID,$MaxSnapshots,[switch]$Detailed
  )

# Example: $ObjectSnapshots= Get-RSCObjectSnapshots -ObjectID "$ObjectID"

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Setting $MaxSnapshots to default if null
IF($MaxSnapshots -eq $null){$MaxSnapshots = 30}
################################################
# Running Main Function
################################################
# Note: for "sortOrder" = use ASC for oldest snapshots first, DESC for newest snapshots first 
$RSCGraphQL = @{"operationName" = "SnapshotOfASnappableConnection";

"variables" = @{
"workloadId" = "$ObjectID"
"sortOrder" = "DESC"
"first" = $MaxSnapshots
};

"query" = "query SnapshotOfASnappableConnection(`$workloadId: String!, `$first: Int, `$sortOrder: SortOrder) {
  snapshotOfASnappableConnection(workloadId: `$workloadId, first: `$first, sortOrder: `$sortOrder) {
    nodes {
      ... on CdmSnapshot {
        id
        date
        expiryHint
        expirationDate
      }
      ... on PolarisSnapshot {
        id
        date
        expirationDate
        __typename
      }
    }
  }
}"
}
# Override if extended
IF($Detailed)
{
$RSCGraphQL = @{"operationName" = "SnapshotOfASnappableConnection";

"variables" = @{
"workloadId" = "$ObjectID"
"sortOrder" = "DESC"
"first" = $MaxSnapshots
};

"query" = "query SnapshotOfASnappableConnection(`$workloadId: String!, `$first: Int, `$sortOrder: SortOrder) {
  snapshotOfASnappableConnection(workloadId: `$workloadId, first: `$first, sortOrder: `$sortOrder) {
    nodes {
      ... on CdmSnapshot {
        id
        date
        expiryHint
                  snapshotRetentionInfo {
            localInfo {
              expirationTime
              isExpirationDateCalculated
              isExpirationInformationUnavailable
              isSnapshotPresent
              locationId
              name
              snapshotFrequency
            }
            archivalInfos {
              expirationTime
              isExpirationDateCalculated
              isExpirationInformationUnavailable
              isSnapshotPresent
              locationId
              name
              snapshotFrequency
            }
            replicationInfos {
              expirationTime
              isExpirationDateCalculated
              isExpirationInformationUnavailable
              isSnapshotPresent
              snapshotFrequency
              name
              locationId
            }
          }
        localLocations {
            isActive
            id
          }
        expirationDate
        archivalLocations {
            id
            isActive
            name
          }
          replicationLocations {
            id
            isActive
            name
          }
        __typename
      }
      ... on PolarisSnapshot {
        id
        date
        expirationDate
        __typename
      }
    }
  }
}"
}
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
Try
{
$ObjectSnapshotsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Headers $RSCSessionHeader -Body $($RSCGraphQL | ConvertTo-JSON -Depth 10)
$ObjectSnapshotsToProcess = $ObjectSnapshotsResponse.data.snapshotOfASnappableConnection.nodes
}
Catch
{
$ErrorMessage = $_.ErrorDetails; "ERROR: $ErrorMessage"
}
# Creating array
$ObjectSnapshots = [System.Collections.ArrayList]@()
# Processing snapshots
ForEach ($ObjectSnapshot in $ObjectSnapshotsToProcess)
{
# Getting snapshot data
$SnapshotDateUNIX = $ObjectSnapshot.date
$SnapshotID = $ObjectSnapshot.id
# Converting
$SnapshotDateUTC = Convert-RSCUNIXTime $SnapshotDateUNIX
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($SnapshotDateUTC -ne $null)
{
$SnapshotDateTimespan = New-TimeSpan -Start $SnapshotDateUTC -End $UTCDateTime
$SnapshotHoursSince = $SnapshotDateTimespan | Select-Object -ExpandProperty TotalHours
$SnapshotHoursSince = [Math]::Round($SnapshotHoursSince,1)
$SnapshotDaysSince = $SnapshotDateTimespan | Select-Object -ExpandProperty TotalDays
$SnapshotDaysSince = [Math]::Round($SnapshotDaysSince,1)
}
ELSE
{
$SnapshotHoursSince = $null
$SnapshotDaysSince = $null
}
# Adding
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "DateUTC" -Value $SnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $SnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotDaysSince" -Value $SnapshotDaysSince
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
# Detailed section
IF($Detailed)
{
# Getting detailed info
$ArchivalInfo = $ObjectSnapshot.snapshotRetentionInfo.archivalInfos
$ReplicationInfo = $ObjectSnapshot.snapshotRetentionInfo.replicationInfos
$LocalInfo = $ObjectSnapshot.snapshotRetentionInfo.localInfo
# Archival info
$ArchiveName = $ArchivalInfo.Name
$ArchiveExpiration = $ArchivalInfo.expirationTime
IF($ArchiveExpiration -ne $null){$ArchiveExpirationUTC = Convert-RSCUNIXTime $ArchiveExpiration}ELSE{$ArchiveExpirationUTC = $null}
# Replication info
$ReplicaName = $ReplicationInfo.Name
$ReplicaExpiration = $ReplicationInfo.expirationTime
IF($ReplicaExpiration -ne $null){$ReplicaExpirationUTC = Convert-RSCUNIXTime $ReplicaExpiration}ELSE{$ReplicaExpirationUTC = $null}
# Local info
$IsLocal = $LocalInfo.isSnapshotPresent
$RubrikCluster = $LocalInfo.name
$LocalExpiration = $LocalInfo.expirationTime
IF($LocalExpiration -ne $null){$LocalExpirationUTC = Convert-RSCUNIXTime $LocalExpiration}ELSE{$LocalExpirationUTC = $null}
# Setting opposite if null
IF($IsLocal -eq $null){$IsLocal = $False}
# Adding additional fields
$Object | Add-Member -MemberType NoteProperty -Name "OnSourceCluster" -Value $IsLocal
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "LocalExpirationUTC" -Value $LocalExpirationUTC
$Object | Add-Member -MemberType NoteProperty -Name "Replica" -Value $ReplicaName
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaExpirationUTC" -Value $ReplicaExpirationUTC
$Object | Add-Member -MemberType NoteProperty -Name "Archive" -Value $ArchiveName
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveExpirationUTC" -Value $ArchiveExpirationUTC
}
# Adding to the array
$ObjectSnapshots.Add($Object) | Out-Null
}

# Returning Result
Return $ObjectSnapshots
}