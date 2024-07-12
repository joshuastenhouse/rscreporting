################################################
# Function - Get-RSCObjectStorageUsageByVMwareTag - Getting all RSC Object Storage Usage by VMware Tag
################################################
Function Get-RSCObjectStorageUsageByVMwareTag {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of every VMware tag in RSC and it's current storage usage stats.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectStorageUsageByVMwareTag
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
# Getting tags
$RSCVMwareTags = Get-RSCVMwareTags
# Removing duplicates
$RSCVMwareTags = $RSCVMwareTags | Sort-Object TagID -Unique
# Getting tag assignments
$RSCVMwareTagAssignments = Get-RSCVMwareTagAssignments
# Getting object storage usage if global variable not already exists containing it
IF($RSCObjectStorageUsage -eq $null){$RSCObjectStorageUsage = Get-RSCObjectStorageUsage}

############################
# Processing Object Storage Usage by Tags
############################
$RSCTagStorageUsage = [System.Collections.ArrayList]@()
# Filtering to only show for Tags with VMs
$RSCVMwareTagsFiltered = $RSCVMwareTags | Where-Object {$_.VMs -gt 0}
# Processing each tag
ForEach($RSCVMwareTag in $RSCVMwareTagsFiltered)
{
# Setting varibles
$vCenter = $RSCVMwareTag.vCenter 
$vCenterID = $RSCVMwareTag.vCenterID
$Tag = $RSCVMwareTag.Tag  
$TagID = $RSCVMwareTag.TagID
$VMs = $RSCVMwareTag.VMs
$TagCategory = $RSCVMwareTag.TagCategory
$TagCategoryID = $RSCVMwareTag.TagCategoryID
$SLADomain = $RSCVMwareTag.SLADomain
$SLADomainID = $RSCVMwareTag.SLADomainID
$SLAAssignment = $RSCVMwareTag.SLAAssignment
# Getting VMs
$TagVMs = $RSCVMwareTagAssignments | Where-Object {$_.TagID -eq $TagID}
# Creating array
$TagVMStorage = @()
# For each VM adding storage to array
ForEach($TagVM in $TagVMs)
{
# Setting variable
$VMID = $TagVM.VMID
# Getting array
$VMStorageArray = $RSCObjectStorageUsage | Where {$_.ObjectID -eq $VMID}
# Adding to array
$TagVMStorage += $VMStorageArray
}
# Totalling GB storage stats
$TotalUsedGB = $TagVMStorage | Select-Object -ExpandProperty TotalUsedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProtectedGB = $TagVMStorage | Select-Object -ExpandProperty ProtectedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalStorageGB = $TagVMStorage | Select-Object -ExpandProperty LocalStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$TransferredGB = $TagVMStorage | Select-Object -ExpandProperty TransferredGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LogicalGB = $TagVMStorage | Select-Object -ExpandProperty LogicalGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ReplicaStorageGB = $TagVMStorage | Select-Object -ExpandProperty ReplicaStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ArchiveStorageGB = $TagVMStorage | Select-Object -ExpandProperty ArchiveStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LastSnapshotLogicalGB = $TagVMStorage | Select-Object -ExpandProperty LastSnapshotLogicalGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalMeteredDataGB = $TagVMStorage | Select-Object -ExpandProperty LocalMeteredDataGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$UsedGB = $TagVMStorage | Select-Object -ExpandProperty UsedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProvisionedGB = $TagVMStorage | Select-Object -ExpandProperty ProvisionedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalProtectedGB = $TagVMStorage | Select-Object -ExpandProperty LocalProtectedGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalEffectiveStorageGB = $TagVMStorage | Select-Object -ExpandProperty LocalEffectiveStorageGB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Totalling Bytes storage stats
$TotalUsedBytes = $TagVMStorage | Select-Object -ExpandProperty TotalUsedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProtectedBytes = $TagVMStorage | Select-Object -ExpandProperty ProtectedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalStorageBytes = $TagVMStorage | Select-Object -ExpandProperty LocalStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$TransferredBytes = $TagVMStorage | Select-Object -ExpandProperty TransferredBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LogicalBytes = $TagVMStorage | Select-Object -ExpandProperty LogicalBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ReplicaStorageBytes = $TagVMStorage | Select-Object -ExpandProperty ReplicaStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ArchiveStorageBytes = $TagVMStorage | Select-Object -ExpandProperty ArchiveStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LastSnapshotLogicalBytes = $TagVMStorage | Select-Object -ExpandProperty LastSnapshotLogicalBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalMeteredDataBytes = $TagVMStorage | Select-Object -ExpandProperty LocalMeteredDataBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$UsedBytes = $TagVMStorage | Select-Object -ExpandProperty UsedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ProvisionedBytes = $TagVMStorage | Select-Object -ExpandProperty ProvisionedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalProtectedBytes = $TagVMStorage | Select-Object -ExpandProperty LocalProtectedBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LocalEffectiveStorageBytes = $TagVMStorage | Select-Object -ExpandProperty LocalEffectiveStorageBytes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vCenter
$Object | Add-Member -MemberType NoteProperty -Name "vCenterID" -Value $vCenterID
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $Tag
$Object | Add-Member -MemberType NoteProperty -Name "TagID" -Value $TagID
$Object | Add-Member -MemberType NoteProperty -Name "VMs" -Value $VMs
$Object | Add-Member -MemberType NoteProperty -Name "TagCategory" -Value $TagCategory
$Object | Add-Member -MemberType NoteProperty -Name "TagCategoryID" -Value $TagCategoryID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $SLAAssignment
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
$RSCTagStorageUsage.Add($Object) | Out-Null
# End of for each tag with VMs below
}
# End of for each tag with VMs above

# Returning array
Return $RSCTagStorageUsage
# End of function
}
