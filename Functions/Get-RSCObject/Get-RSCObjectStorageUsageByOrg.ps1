################################################
# Function - Get-RSCObjectStorageUsageByOrg - Getting all RSC Object Storage Usage by Org
################################################
Function Get-RSCObjectStorageUsageByOrg {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of every Org in RSC and it's current storage usage stats.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectStorageUsageByOrg
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
# Getting object storage usage if global variable not already exists containing it
IF($RSCObjectStorageUsage -eq $null){$RSCObjectStorageUsage = Get-RSCObjectStorageUsage}
############################
# Processing Object Storage Usage by Orgs
############################
$RSCOrgStorageUsage = [System.Collections.ArrayList]@()
# Getting unique orgs
$RSCOrgs = $RSCObjectStorageUsage | Select-Object -ExpandProperty Org -Unique
# Processing each tag
ForEach($RSCOrg in $RSCOrgs)
{
# Getting Objects
$OrgObjects = $RSCObjectStorageUsage | Where-Object {$_.Org -eq $RSCOrg}
$OrgObjectsCount = $OrgObjects | Measure-Object | Select-Object -ExpandProperty Count
# Totalling GB storage stats
$TotalUsedGB = $OrgObjects | Select-Object -ExpandProperty TotalUsedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProtectedGB = $OrgObjects | Select-Object -ExpandProperty ProtectedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalStorageGB = $OrgObjects | Select-Object -ExpandProperty LocalStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$TransferredGB = $OrgObjects | Select-Object -ExpandProperty TransferredGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LogicalGB = $OrgObjects | Select-Object -ExpandProperty LogicalGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ReplicaStorageGB = $OrgObjects | Select-Object -ExpandProperty ReplicaStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ArchiveStorageGB = $OrgObjects | Select-Object -ExpandProperty ArchiveStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LastSnapshotLogicalGB = $OrgObjects | Select-Object -ExpandProperty LastSnapshotLogicalGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalMeteredDataGB = $OrgObjects | Select-Object -ExpandProperty LocalMeteredDataGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$UsedGB = $OrgObjects | Select-Object -ExpandProperty UsedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProvisionedGB = $OrgObjects | Select-Object -ExpandProperty ProvisionedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalProtectedGB = $OrgObjects | Select-Object -ExpandProperty LocalProtectedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalEffectiveStorageGB = $OrgObjects | Select-Object -ExpandProperty LocalEffectiveStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Totalling Bytes storage stats
$TotalUsedBytes = $OrgObjects | Select-Object -ExpandProperty TotalUsedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProtectedBytes = $OrgObjects | Select-Object -ExpandProperty ProtectedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalStorageBytes = $OrgObjects | Select-Object -ExpandProperty LocalStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$TransferredBytes = $OrgObjects | Select-Object -ExpandProperty TransferredBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LogicalBytes = $OrgObjects | Select-Object -ExpandProperty LogicalBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ReplicaStorageBytes = $OrgObjects | Select-Object -ExpandProperty ReplicaStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ArchiveStorageBytes = $OrgObjects | Select-Object -ExpandProperty ArchiveStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LastSnapshotLogicalBytes = $OrgObjects | Select-Object -ExpandProperty LastSnapshotLogicalBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalMeteredDataBytes = $OrgObjects | Select-Object -ExpandProperty LocalMeteredDataBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$UsedBytes = $OrgObjects | Select-Object -ExpandProperty UsedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProvisionedBytes = $OrgObjects | Select-Object -ExpandProperty ProvisionedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalProtectedBytes = $OrgObjects | Select-Object -ExpandProperty LocalProtectedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalEffectiveStorageBytes = $OrgObjects | Select-Object -ExpandProperty LocalEffectiveStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Org" -Value $RSCOrg
$Object | Add-Member -MemberType NoteProperty -Name "Objects" -Value $OrgObjectsCount
# Storage stats in GB
$Object | Add-Member -MemberType NoteProperty -Name "TotalUsedGB" -Value $TotalUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedGB" -Value $ProtectedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalStorageGB" -Value $LocalStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "TransferredGB" -Value $TransferredGB
$Object | Add-Member -MemberType NoteProperty -Name "LogicalGB" -Value $LogicalGB
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaStorageGB" -Value $ReplicaStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveStorageGB" -Value $ArchiveStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshotLogicalGB" -Value $LastSnapshotLogicalGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalMeteredDataGB" -Value $LocalMeteredDataGB
$Object | Add-Member -MemberType NoteProperty -Name "UsedGB" -Value $UsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedGB" -Value $ProvisionedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalProtectedGB" -Value $LocalProtectedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalEffectiveStorageGB" -Value $LocalEffectiveStorageGB
# Storage stats in bytes
$Object | Add-Member -MemberType NoteProperty -Name "TotalUsedBytes" -Value $TotalUsedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedBytes" -Value $ProtectedBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalStorageBytes" -Value $LocalStorageBytes
$Object | Add-Member -MemberType NoteProperty -Name "TransferredBytes" -Value $TransferredBytes
$Object | Add-Member -MemberType NoteProperty -Name "LogicalBytes" -Value $LogicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaStorageBytes" -Value $ReplicaStorageBytes
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveStorageBytes" -Value $ArchiveStorageBytes
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshotLogicalBytes" -Value $LastSnapshotLogicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalMeteredDataBytes" -Value $LocalMeteredDataBytes
$Object | Add-Member -MemberType NoteProperty -Name "UsedBytes" -Value $UsedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedBytes" -Value $ProvisionedBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalProtectedBytes" -Value $LocalProtectedBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalEffectiveStorageBytes" -Value $LocalEffectiveStorageBytes
# Adding
$RSCOrgStorageUsage.Add($Object) | Out-Null
# End of for each org below
}
# End of for each org above
############################
# Manually processing no org below, as null
############################
# Getting Objects
$OrgObjects = $RSCObjectStorageUsage | Where-Object {$_.Org -eq $null}
$OrgObjectsCount = $OrgObjects | Measure-Object | Select-Object -ExpandProperty Count
# Totalling GB storage stats
$TotalUsedGB = $OrgObjects | Select-Object -ExpandProperty TotalUsedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProtectedGB = $OrgObjects | Select-Object -ExpandProperty ProtectedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalStorageGB = $OrgObjects | Select-Object -ExpandProperty LocalStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$TransferredGB = $OrgObjects | Select-Object -ExpandProperty TransferredGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LogicalGB = $OrgObjects | Select-Object -ExpandProperty LogicalGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ReplicaStorageGB = $OrgObjects | Select-Object -ExpandProperty ReplicaStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ArchiveStorageGB = $OrgObjects | Select-Object -ExpandProperty ArchiveStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LastSnapshotLogicalGB = $OrgObjects | Select-Object -ExpandProperty LastSnapshotLogicalGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalMeteredDataGB = $OrgObjects | Select-Object -ExpandProperty LocalMeteredDataGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$UsedGB = $OrgObjects | Select-Object -ExpandProperty UsedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProvisionedGB = $OrgObjects | Select-Object -ExpandProperty ProvisionedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalProtectedGB = $OrgObjects | Select-Object -ExpandProperty LocalProtectedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalEffectiveStorageGB = $OrgObjects | Select-Object -ExpandProperty LocalEffectiveStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Totalling Bytes storage stats
$TotalUsedBytes = $OrgObjects | Select-Object -ExpandProperty TotalUsedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProtectedBytes = $OrgObjects | Select-Object -ExpandProperty ProtectedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalStorageBytes = $OrgObjects | Select-Object -ExpandProperty LocalStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$TransferredBytes = $OrgObjects | Select-Object -ExpandProperty TransferredBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LogicalBytes = $OrgObjects | Select-Object -ExpandProperty LogicalBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ReplicaStorageBytes = $OrgObjects | Select-Object -ExpandProperty ReplicaStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ArchiveStorageBytes = $OrgObjects | Select-Object -ExpandProperty ArchiveStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LastSnapshotLogicalBytes = $OrgObjects | Select-Object -ExpandProperty LastSnapshotLogicalBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalMeteredDataBytes = $OrgObjects | Select-Object -ExpandProperty LocalMeteredDataBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$UsedBytes = $OrgObjects | Select-Object -ExpandProperty UsedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProvisionedBytes = $OrgObjects | Select-Object -ExpandProperty ProvisionedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalProtectedBytes = $OrgObjects | Select-Object -ExpandProperty LocalProtectedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalEffectiveStorageBytes = $OrgObjects | Select-Object -ExpandProperty LocalEffectiveStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Org" -Value "NoAssignedOrg"
$Object | Add-Member -MemberType NoteProperty -Name "Objects" -Value $OrgObjectsCount
# Storage stats in GB
$Object | Add-Member -MemberType NoteProperty -Name "TotalUsedGB" -Value $TotalUsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedGB" -Value $ProtectedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalStorageGB" -Value $LocalStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "TransferredGB" -Value $TransferredGB
$Object | Add-Member -MemberType NoteProperty -Name "LogicalGB" -Value $LogicalGB
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaStorageGB" -Value $ReplicaStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveStorageGB" -Value $ArchiveStorageGB
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshotLogicalGB" -Value $LastSnapshotLogicalGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalMeteredDataGB" -Value $LocalMeteredDataGB
$Object | Add-Member -MemberType NoteProperty -Name "UsedGB" -Value $UsedGB
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedGB" -Value $ProvisionedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalProtectedGB" -Value $LocalProtectedGB
$Object | Add-Member -MemberType NoteProperty -Name "LocalEffectiveStorageGB" -Value $LocalEffectiveStorageGB
# Storage stats in bytes
$Object | Add-Member -MemberType NoteProperty -Name "TotalUsedBytes" -Value $TotalUsedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedBytes" -Value $ProtectedBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalStorageBytes" -Value $LocalStorageBytes
$Object | Add-Member -MemberType NoteProperty -Name "TransferredBytes" -Value $TransferredBytes
$Object | Add-Member -MemberType NoteProperty -Name "LogicalBytes" -Value $LogicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "ReplicaStorageBytes" -Value $ReplicaStorageBytes
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveStorageBytes" -Value $ArchiveStorageBytes
$Object | Add-Member -MemberType NoteProperty -Name "LastSnapshotLogicalBytes" -Value $LastSnapshotLogicalBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalMeteredDataBytes" -Value $LocalMeteredDataBytes
$Object | Add-Member -MemberType NoteProperty -Name "UsedBytes" -Value $UsedBytes
$Object | Add-Member -MemberType NoteProperty -Name "ProvisionedBytes" -Value $ProvisionedBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalProtectedBytes" -Value $LocalProtectedBytes
$Object | Add-Member -MemberType NoteProperty -Name "LocalEffectiveStorageBytes" -Value $LocalEffectiveStorageBytes
# Adding
$RSCOrgStorageUsage.Add($Object) | Out-Null

# Returning array
Return $RSCOrgStorageUsage
# End of function
}
