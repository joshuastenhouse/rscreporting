################################################
# Function - Get-RSCFilesets - Getting all Filesets on the RSC instance
################################################
Function Get-RSCFilesets {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning all filesets.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCFilesets
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
# Getting RSC hosts & their objects
$RSCHostList = Get-RSCHostFilesetObjects
################################################
# Processing Hosts
################################################
# Creating array
$RSCObjects = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCHost in $RSCHostList)
{
# Setting variables
$HostName = $RSCHost.Host
$HostID = $RSCHost.HostID
$HostCDMID = $RSCHost.HostCDMID
$HostType = $RSCHost.HostType
$HostOSType = $RSCHost.OSType
$HostOSName = $RSCHost.OSName
$HostRubrikCluster = $RSCHost.RubrikCluster
$HostRubrikClusterID = $RSCHost.RubrikClusterID
# Getting objects on host
$HostObjects = $RSCHost.ObjectData
# For each object adding to array
ForEach($HostObject in $HostObjects)
{
# Setting variables
$ObjectType = $HostObject.objectType
$ObjectName = $HostObject.name
$ObjectID = $HostObject.id
$ObjectCDMID = $HostObject.cdmId
$ObjectIsRelic = $HostObject.isRelic
# SLA info
$ObjectSLADomainInfo = $HostObject.effectiveSlaDomain
$ObjectSLADomain = $ObjectSLADomainInfo.name
$ObjectSLADomainID = $ObjectSLADomainInfo.id
$ObjectSLAAssignment = $HostObject.slaAssignment
$ObjectSLAPaused = $HostObject.slaPauseStatus
# Paths
$ObjectPathsIncluded = $HostObject.pathIncluded
$ObjectPathsExcluded = $HostObject.pathExcluded
$ObjectPathsExceptions = $HostObject.pathExceptions
# Snapshot info
$ObjectOnDemandSnapshots = $HostObject.onDemandSnapshotCount
$ObjectSnapshotDateUNIX = $HostObject.newestSnapshot.date
$ObjectSnapshotDateID = $HostObject.newestSnapshot.id
$ObjectReplicatedSnapshotDateUNIX = $HostObject.newestReplicatedSnapshot.date
$ObjectReplicatedSnapshotDateID = $HostObject.newestReplicatedSnapshot.id
$ObjectArchiveSnapshotDateUNIX = $HostObject.newestArchivedSnapshot.date
$ObjectArchiveSnapshotDateID = $HostObject.newestArchivedSnapshot.id
$ObjectOldestSnapshotDateUNIX = $HostObject.oldestSnapshot.date
$ObjectOldestSnapshotDateID = $HostObject.oldestSnapshot.id
# Converting snapshot dates
IF($ObjectSnapshotDateUNIX -ne $null){$ObjectSnapshotDateUTC = Convert-RSCUNIXTime $ObjectSnapshotDateUNIX}ELSE{$ObjectSnapshotDateUTC = $null}
IF($ObjectReplicatedSnapshotDateUNIX -ne $null){$ObjectReplicatedSnapshotDateUTC = Convert-RSCUNIXTime $ObjectReplicatedSnapshotDateUNIX}ELSE{$ObjectSnObjectReplicatedSnapshotDateUTCapshotDateUTC = $null}
IF($ObjectArchiveSnapshotDateUNIX -ne $null){$ObjectArchiveSnapshotDateUTC = Convert-RSCUNIXTime $ObjectArchiveSnapshotDateUNIX}ELSE{$ObjectArchiveSnapshotDateUTC = $null}
IF($ObjectOldestSnapshotDateUNIX -ne $null){$ObjectOldestSnapshotDateUTC = Convert-RSCUNIXTime $ObjectOldestSnapshotDateUNIX}ELSE{$ObjectOldestSnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($ObjectSnapshotDateUTC -ne $null){$ObjectSnapshotTimespan = New-TimeSpan -Start $ObjectSnapshotDateUTC -End $UTCDateTime;$ObjectSnapshotHoursSince = $ObjectSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$ObjectSnapshotHoursSince = [Math]::Round($ObjectSnapshotHoursSince,1)}ELSE{$ObjectSnapshotHoursSince = $null}
IF($ObjectReplicatedSnapshotDateUTC -ne $null){$ObjectReplicatedSnapshotTimespan = New-TimeSpan -Start $ObjectReplicatedSnapshotDateUTC -End $UTCDateTime;$ObjectReplicatedSnapshotHoursSince = $ObjectReplicatedSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$ObjectReplicatedSnapshotHoursSince = [Math]::Round($ObjectReplicatedSnapshotHoursSince,1)}ELSE{$ObjectReplicatedSnapshotHoursSince = $null}
IF($ObjectArchiveSnapshotDateUTC -ne $null){$ObjectArchiveSnapshotTimespan = New-TimeSpan -Start $ObjectArchiveSnapshotDateUTC -End $UTCDateTime;$ObjectArchiveSnapshotHoursSince = $ObjectArchiveSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$ObjectArchiveSnapshotHoursSince = [Math]::Round($ObjectArchiveSnapshotHoursSince,1)}ELSE{$ObjectArchiveSnapshotHoursSince = $null}
IF($ObjectOldestSnapshotDateUTC -ne $null){$ObjectOldestSnapshotTimespan = New-TimeSpan -Start $ObjectOldestSnapshotDateUTC -End $UTCDateTime;$ObjectOldestSnapshotDaysSince = $ObjectOldestSnapshotTimespan | Select-Object -ExpandProperty TotalDays;$ObjectOldestSnapshotDaysSince = [Math]::Round($ObjectOldestSnapshotDaysSince,1)}ELSE{$ObjectOldestSnapshotDaysSince = $null}
# Misc
$ObjectSymlinkEnabled = $HostObject.symlinkResolutionEnabled
$ObjectIsPassThrough = $HostObject.isPassThrough
$ObjectHardlinkEnabled = $HostObject.hardlinkSupportEnabled
# Template
$ObjectPhysicalPaths = $HostObject.physicalPath
$objectTemplateInfo = $ObjectPhysicalPaths | Where-Object {$_.ObjectType -eq "FilesetTemplate"}
$objectTemplate = $objectTemplateInfo.name
$objectTemplateID = $objectTemplateInfo.fid
# User note info
$ObjectNoteInfo = $HostObject.latestUserNote
$ObjectNote = $ObjectNoteInfo.userNote
$ObjectNoteCreator = $ObjectNoteInfo.userName
$ObjectNoteCreatedUNIX = $ObjectNoteInfo.time
IF($ObjectNoteCreatedUNIX -ne $null){$ObjectNoteCreatedUTC = Convert-RSCUNIXTime $ObjectNoteCreatedUNIX}ELSE{$ObjectNoteCreatedUTC = $null}
# Getting URL
$ObjectURL = Get-RSCObjectURL -ObjectType $ObjectType -ObjectID $ObjectID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "FilesetType" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Fileset" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "FilesetID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "FilesetCDMID" -Value $ObjectCDMID
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $HostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $HostID
$Object | Add-Member -MemberType NoteProperty -Name "HostCDMID" -Value $HostCDMID
$Object | Add-Member -MemberType NoteProperty -Name "HostType" -Value $HostType
$Object | Add-Member -MemberType NoteProperty -Name "OSType" -Value $HostOSType
$Object | Add-Member -MemberType NoteProperty -Name "OSName" -Value $HostOSName
# Path info
$Object | Add-Member -MemberType NoteProperty -Name "PathsIncluded" -Value $ObjectPathsIncluded
$Object | Add-Member -MemberType NoteProperty -Name "PathsExcluded" -Value $ObjectPathsExcluded
$Object | Add-Member -MemberType NoteProperty -Name "PathsExceptions" -Value $ObjectPathsExceptions
# SLA info
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ObjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $ObjectSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $ObjectSLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $ObjectIsRelic
# Snapshot dates
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTC" -Value $ObjectSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTCAgeHours" -Value $ObjectSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshotUTC" -Value $ObjectReplicatedSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnapshotUTCAgeHours" -Value $ObjectReplicatedSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshotUTC" -Value $ObjectArchiveSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshotUTCAgeHours" -Value $ObjectArchiveSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTC" -Value $ObjectOldestSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTCAgeDays" -Value $ObjectOldestSnapshotDaysSince
# Note info
$Object | Add-Member -MemberType NoteProperty -Name "LatestRSCNote" -Value $ObjectNote
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteCreator" -Value $ObjectNoteCreator
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteDateUTC" -Value $ObjectNoteCreatedUTC
# Misc
$Object | Add-Member -MemberType NoteProperty -Name "SymlinkEnabled" -Value $ObjectSymlinkEnabled
$Object | Add-Member -MemberType NoteProperty -Name "IsPassThrough" -Value $ObjectIsPassThrough
$Object | Add-Member -MemberType NoteProperty -Name "HardlinkEnabled" -Value $ObjectHardlinkEnabled
# Rubrik cluster info
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $HostRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $HostRubrikClusterID
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCObjects.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# End of for each host below
}
# End of for each host above

# Removing null entries
$RSCObjectsFiltered = $RSCObjects | Where-Object {$_.Fileset -ne $null}

# Returning array
Return $RSCObjectsFiltered
# End of function
}