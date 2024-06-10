################################################
# Function - Start-VMwareVMLiveMount - Requests a live mount for an VMware VM 
################################################
Function Start-VMwareVMLiveMount {
	
<#
.SYNOPSIS
Requests a live mount for a VMware VM using either the target hostID or targetclusterID

.DESCRIPTION
The user has to specify the source VM ID, target VMware host or cluster ID on which to mount, and the target VM name which is the name of the VM to create (make sure it's unique otherwise the mount will fail)

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER DBID
The ID of the database to be live mounted, use Get-RSCMSSQLDatabases to get a valid DBID, can also use the ObjectID of the SQL database (same thing).
.PARAMETER TargetInstanceID
The ID of a valid instance to mount the SQL database to, use Get-RSCMSSQLInstances for a list of all available. You can also use the UI to validate if it's compatible with the database chosen. You can also pull it from the URL in the UI by navigating to the instance you want to mount to, I.E
https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/mssql/hosts_instances/instance/c152e0d1-78e0-515d-9008-1129657b7f5e?object_status=%7B%22listedOptions%22%3A%5B%5D%2C%22selectedIds%22%3A%5B%22PROTECTED%22%2C%22UNPROTECTED%22%5D%7D
From the above the instance ID is c152e0d1-78e0-515d-9008-1129657b7f5e
.PARAMETER TargetDBName
The name for the SQL database when mounted on the target instance ID, make sure it's unique otherwise MSSQL will fail to mount the database and the job will fail.

.OUTPUTS
Returns an array with the status of the on-demand snapshot request.

.EXAMPLE
Start-MSSQLLiveMount -DBID "71c0820a-3fbd-5e91-878f-42da723aa371" -InstanceID "b9aa64d6-5967-5c4c-80aa-938db39857f0" -TargetDBName "DemoLiveMount"
This example prompts for the RSC URL, user ID and secret, then connects to RSC and securely stores them for subsequent use in the script directory specified.

.NOTES
Author: Joshua Stenhouse
Date: 10/23/2023
#>
################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        $VMID,
        [Parameter(Mandatory=$false)]
        $TargetHostID,
        [Parameter(Mandatory=$false)]
        $TargetClusterID,
        [Parameter(Mandatory=$false)]
        [string]$TargetVMName,
        [Parameter(Mandatory=$false)]
        $SnapshotID
    )
################################################
# Importing Module & Running Required Functions
################################################
# Importing module
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
# Getting list VMware hosts, clusters and VMs
$VMwareHosts = Get-RSCVMwareHosts
$VMwareClusters = Get-RSCVMwareClusters
$VMwareVMs = Get-RSCVMwareVMs
################################################
# Requesting Live Mount IF Valid Settings
################################################
# Logging
Write-Host "Verifying IDs.."
# Checking VM ID
$VMIDCheck = $VMwareVMs | Where-Object {$_.VMID -eq $VMID} | Select-Object -First 1
IF($VMIDCheck -eq $null){$VMIDCheck = $FALSE}ELSE{$VMIDCheck = $TRUE}
# Getting VM name
$VMName = $VMIDCheck | Select-Object -ExpandProperty VM
# Checking Host ID if not null
$VMHostIDCheck = $VMwareHosts | Where-Object {$_.HostID -eq $TargetHostID}
IF($VMHostIDCheck -eq $null){$VMHostIDCheck = $FALSE}ELSE{$VMHostIDCheck = $TRUE}
# Checking Cluster ID if not null
$VMClusterIDCheck = $VMwareClusters | Where-Object {$_.ClusterID -eq $TargetClusterID}
IF($VMClusterIDCheck -eq $null){$VMClusterIDCheck = $FALSE}ELSE{$VMClusterIDCheck = $TRUE}
# Getting the original VM host ID if both null
IF(($VMHostIDCheck -eq $False) -and ($VMClusterIDCheck -eq $FLASE))
{
$TargetHostID = $VMwareVMs | Where-Object {$_.VMID -eq $VMID} | Select-Object -ExpandProperty VMHostID
IF($TargetHostID -eq $null){$VMHostIDCheck = $FALSE}ELSE{$VMHostIDCheck = $TRUE}
}
# Getting Snapshot ID
IF($SnapshotID -eq $null){$SnapshotID = Get-RSCObjectSnapshots -ObjectID $VMID -MaxSnapshots 1 | Select-Object -ExpandProperty SnapshotID}
IF($SnapshotID -eq $null){$SnapshotIDCheck = $FALSE}ELSE{$SnapshotIDCheck = $TRUE}
# Logging
Write-Host "VMIDCheck: $VMIDCheck
HostIDCheck: $VMHostIDCheck
ClusterIDCheck: $VMClusterIDCheck
SnapshotIDCheck: $SnapshotIDCheck"
# Exiting if any requirements are null, needs a valid VMID, at least a host or cluster, and a valid snapshot ID to work
IF($VMIDCheck -eq $False){Break}
IF(($VMHostIDCheck -eq $False) -and ($VMClusterIDCheck -eq $FLASE)){Break}
IF($SnapshotIDCheck -eq $False){Break}
# Logging
Write-Host "Checks passed. Processing live mount.."
Start-Sleep 2
################################################
# Performing Live Mount
################################################
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "vSphereLiveMountMutation";

"variables" = @{
        "snapshotFid" = "$SnapshotID"
        "snappableId" = "$VMID"
        "keepMacAddresses" = $false
        "powerOn" = $true
        "removeNetworkDevices" = $false
        "shouldRecoverTags" = $false
        "shouldMigrateImmediately" = $false
};

"query" = "mutation vSphereLiveMountMutation(`$snappableId: String!, `$hostId: String, `$clusterId: String, `$resourcePoolId: String, `$snapshotFid: String, `$shouldRecoverTags: Boolean!, `$keepMacAddresses: Boolean!, `$powerOn: Boolean!, `$removeNetworkDevices: Boolean!, `$vmName: String, `$recoveryPoint: DateTime, `$shouldMigrateImmediately: Boolean!) {
  vsphereVmInitiateLiveMountV2(
    input: {id: `$snappableId, config: {hostId: `$hostId, resourcePoolId: `$resourcePoolId, clusterId: `$clusterId, shouldRecoverTags: `$shouldRecoverTags, requiredRecoveryParameters: {snapshotId: `$snapshotFid, recoveryPoint: `$recoveryPoint}, mountExportSnapshotJobCommonOptionsV2: {keepMacAddresses: `$keepMacAddresses, powerOn: `$powerOn, removeNetworkDevices: `$removeNetworkDevices, vmName: `$vmName}, shouldMigrateImmediately: `$shouldMigrateImmediately}}
  ) {
    status
    __typename
  }
}"
}
# Converting to JSON
$RSCJSON = $RSCGraphQL | ConvertTo-Json -Depth 32
# Converting back to PS object for editing of variables
$RSCJSONObject = $RSCJSON | ConvertFrom-Json
# Adding variables specified
IF($TargetVMName -ne $null){$RSCJSONObject.variables | Add-Member -MemberType NoteProperty "vmName" -Value $TargetVMName}
IF($TargetHostID -ne $null){$RSCJSONObject.variables | Add-Member -MemberType NoteProperty "hostId" -Value $TargetHostID}
IF($TargetClusterID -ne $null){$RSCJSONObject.variables | Add-Member -MemberType NoteProperty "clusterId" -Value $TargetClusterID}
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCJSONObject | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# $RequestStatus = "FAILED"
# Checking for permission errors
IF($RSCResponse.errors.message){$RequestStatus = $RSCResponse.errors.message}ELSE{$RequestStatus = "Success"}
# Getting response
$JobURL = $RSCResponse.data.vsphereVmInitiateLiveMountV2.links.href
$JobID = $RSCResponse.data.vsphereVmInitiateLiveMountV2.id
################################################
# Returing Job Info
################################################
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "SourceVM" -Value $VMName
$Object | Add-Member -MemberType NoteProperty -Name "SourceVMID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "TargetVMName" -Value $TargetVMName
$Object | Add-Member -MemberType NoteProperty -Name "TargetHostID" -Value $TargetHostID
$Object | Add-Member -MemberType NoteProperty -Name "TargetClusterID" -Value $TargetClusterID
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RequestStatus
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message
# Returning array
Return $Object

# End of function
}