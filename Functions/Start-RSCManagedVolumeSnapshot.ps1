################################################
# Function - Start-RSCManagedVolumeSnapshot - Requesting an on demand snapshot of an RSC Managed Volume
################################################
Function Start-RSCManagedVolumeSnapshot {
	
<#
.SYNOPSIS
Makes a regular Managed Volume writeable by initiating a begin snapshot request on ManagedVolumeID or ObjectID (same thing).

.DESCRIPTION
Only use this function for regular Managed Volumes, use Start-RSCOnDemandSnapshot for SLA Managed Volumes and any other object type. It can also be piped a ManagedVolume object from Get-RSCManagedVolumes (see examples).

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
The RSC object ID of the managed volume which can be attained from Get-RSCManagedVolumes

.OUTPUTS
Returns an array with the status of the being snapshot request.

.EXAMPLE
Start-RSCManagedVolumeSnapshot - ObjectID $ManagedVolumeID
Where the ObjectID is the Managed Volume ID you want to open/make writeable.

.EXAMPLE
Get-RSCManagedVolumes | Where {$_.ManagedVolume -eq "YOURMVNAME" | Start-RSCManagedVolumeSnapshot
Selecting a managed volume called YOURMVNAME and piping it to Start-RSCManagedVolumeSnapshot

.NOTES
Author: Joshua Stenhouse
Date: 08/16/2023
#>
################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [array]$PipelineArray,
        [Parameter(Mandatory=$false)]
        [string]$ObjectID
    )

################################################
# Importing Module & Running Required Functions
################################################
# IF piped the object array pulling out the ObjectID needed
IF($PipelineArray -ne $null){$ObjectID = $PipelineArray | Select-Object -ExpandProperty ObjectID -First 1}
# Importing
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
# Getting protected objects to validate IDs and get SLADomainID if null
$RSCObjects = Get-RSCManagedVolumes
# Validating object ID exists
$RSCObjectInfo = $RSCObjects | Where-Object {$_.ObjectID -eq $ObjectID}
# Breaking if not
IF($RSCObjectInfo -eq $null)
{
Write-Error "ERROR: ObjectID specified not found, check and try again.."
Break
}
# Getting object type, as not all objects use the generic on-demand snapshot call
$RSCObjectProtocol = $RSCObjectInfo.Protocol
$RSCObjectName = $RSCObjectInfo.ManagedVolume
$RSCObjectRubrikCluster = $RSCObjectInfo.RubrikCluster
$RSCObjectRubrikClusterID = $RSCObjectInfo.RubrikClusterID
################################################
# API Call To RSC GraphQL URI
################################################
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "ManagedVolumeBeginSnapshotMutation";

"variables" = @{
    "input" = @{
        "id" = "$ObjectID"
        "config" = @{
                    "isAsync" = $true
                }
    }
};

"query" = "mutation ManagedVolumeBeginSnapshotMutation(`$input: BeginManagedVolumeSnapshotInput!) {
  beginManagedVolumeSnapshot(input: `$input) {
    asyncRequestStatus {
      id
    }
  }
}"
}
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Checking for permission errors
IF($RSCResponse.errors.message){$RSCResponse.errors.message}
# Getting response
$JobID = $RSCResponse.data.beginManagedVolumeSnapshot.asyncRequestStatus.id
# Setting timestamp
$UTCDateTime = [System.DateTime]::UtcNow
################################################
# Returing Job Info
################################################
# Deciding outcome if no error messages
IF($RSCResponse.errors.message -eq $null){$RequestStatus = "SUCCESS"}ELSE{$RequestStatus = "FAILED"}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ManagedVolume" -Value $RSCObjectName
$Object | Add-Member -MemberType NoteProperty -Name "Protocol" -Value $RSCObjectProtocol
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RSCObjectRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RSCObjectRubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "RequestDateUTC" -Value $UTCDateTime
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RequestStatus
$Object | Add-Member -MemberType NoteProperty -Name "JobID" -Value $JobID
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message

# Returning array
Return $Object
# End of function
}