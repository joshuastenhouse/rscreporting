################################################
# Creating the Get-RSCObjectSnapshotAnalytics function
################################################
Function Get-RSCObjectSnapshotAnalytics {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that returns an array of data analytics for the number of snapshots specified for the object ID.

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
Get-RSCObjectSnapshotAnalytics -ObectID "32ffrferf-erferf-erferfe" -MaxSnapshots 50
This example returns the data analytics for last 50 snapshots for the ObjectID specified.

.NOTES
Author: Joshua Stenhouse
Date: 11/04/2025
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
      [String]$ObjectID,$MaxSnapshots
  )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Setting $MaxSnapshots to default if null
IF($MaxSnapshots -eq $null){$MaxSnapshots = 30}
# Getting Snapshots for the objectID specified
$ObjectSnapshots = Get-RSCObjectSnapshots -ObjectID $ObjectID -MaxSnapshots $MaxSnapshots
# Removing nulls
$ObjectSnapshots = $ObjectSnapshots | Where-Object {$_.SnapshotID -ne $null}
################################################
# Getting snapshot data analytics per snapshot
################################################
# Counting
$ObjectSnapshotsCount = $ObjectSnapshots | Measure-Object | Select-Object -ExpandProperty Count
$ObjectSnapshotsCounter = 0
# Creating array to store results
$SnapshotArray = [System.Collections.ArrayList]@()
# For each, getting analytics
ForEach ($ObjectSnapshot in $ObjectSnapshots)
{
# Counting
$ObjectSnapshotsCounter = $ObjectSnapshotsCounter+1
# Logging
Write-Host "ProcessingSnapshot:$ObjectSnapshotsCounter/$ObjectSnapshotsCount SnapshotID:$SnapshotID"
# Setting variables
$SnapshotID = $ObjectSnapshot.SnapshotID
$SnapshotDateUTC = $ObjectSnapshot.DateUTC
# Getting data
$SnapshotData = Get-RSCSnapshotAnalytics -SnapshotID $SnapshotID
# Only processing if not null
IF($SnapshotData -ne $null)
{
# Creating object
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotDateUTC" -Value $SnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "Paths" -Value $SnapshotData.Paths
$Object | Add-Member -MemberType NoteProperty -Name "FilesCreated" -Value $SnapshotData.FilesCreated
$Object | Add-Member -MemberType NoteProperty -Name "FilesDeleted" -Value $SnapshotData.FilesDeleted
$Object | Add-Member -MemberType NoteProperty -Name "FilesModified" -Value $SnapshotData.FilesModified
$Object | Add-Member -MemberType NoteProperty -Name "SizeGB" -Value $SnapshotData.SizeGB
$Object | Add-Member -MemberType NoteProperty -Name "CreatedGB" -Value $SnapshotData.CreatedGB
$Object | Add-Member -MemberType NoteProperty -Name "DeletedGB" -Value $SnapshotData.DeletedGB
$Object | Add-Member -MemberType NoteProperty -Name "ModifiedGB" -Value $SnapshotData.ModifiedGB
$Object | Add-Member -MemberType NoteProperty -Name "ChangeRatePC" -Value $SnapshotData.ChangeRatePC
$Object | Add-Member -MemberType NoteProperty -Name "SizeBytes" -Value $SnapshotData.SizeBytes
$Object | Add-Member -MemberType NoteProperty -Name "CreatedBytes" -Value $SnapshotData.CreatedBytes
$Object | Add-Member -MemberType NoteProperty -Name "DeletedBytes" -Value $SnapshotData.DeletedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ModifiedBytes" -Value $SnapshotData.ModifiedBytes
# Adding
$SnapshotArray.Add($Object) | Out-Null
# End of bypass if snapshot data null below
}
# End of bypass if snapshot data null above

# End of for each snapshot below
}
# End of for each snapshot above

# Returning Result
Return $SnapshotArray
}