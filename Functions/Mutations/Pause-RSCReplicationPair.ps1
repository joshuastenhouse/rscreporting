################################################
# Function - Pause-RSCReplicationPair - Pauses replication on a replication pairing in RSC
################################################
Function Pause-RSCReplicationPair {
	
<#
.SYNOPSIS
Makes a regular Managed Volume writeable by initiating a begin snapshot request on ManagedVolumeID or ObjectID (same thing).

.DESCRIPTION
Use Get-RSCReplicationPairings for the correct source and target cluster IDs.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SourceCluserID
The RSC ID of the object required for the mutation.

.PARAMETER TargetClusterID
The RSC ID of the object required for the mutation.

.EXAMPLE
Pause-RSCReplicationPair -SourceCluserID "3422dc50-dbb0-4476-8016-971177e5aa59" -TargetClusterID "dcb308e8-819e-4782-9952-b978b9441f7e"

.NOTES
Author: Joshua Stenhouse
Date: 11/14/2024
#>
################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$SourceClusterID,
        [Parameter(Mandatory=$true)]
        [string]$TargetClusterID,
        [switch]$CancelImmediately
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
################################################
# API Call To RSC GraphQL URI
################################################
# Building GraphQL query
IF($CancelImmediately)
{
$RSCGraphQL = @{"operationName" = "PauseReplicationMutation";

"variables" = @{
        "targetClusterUuid" = "$TargetClusterID"
        "sourceClusterUuids" = $SourceClusterID
        "shouldCancelImmediately" = $true
        "shouldPauseImmediately" = $false
};

"query" = "mutation PauseReplicationMutation(`$targetClusterUuid: String!, `$sourceClusterUuids: [String!]!, `$shouldCancelImmediately: Boolean!, `$shouldPauseImmediately: Boolean) {
  enableReplicationPause(
    input: {clusterUuid: `$targetClusterUuid, enablePerLocationPause: {shouldCancelImmediately: `$shouldCancelImmediately, sourceClusterUuids: `$sourceClusterUuids, shouldPauseImmediately: `$shouldPauseImmediately}}
  ) {
    success
    __typename
  }
}"
}
}
ELSE
{
$RSCGraphQL = @{"operationName" = "PauseReplicationMutation";

"variables" = @{
        "targetClusterUuid" = "$TargetClusterID"
        "sourceClusterUuids" = $SourceClusterID
        "shouldCancelImmediately" = $false
        "shouldPauseImmediately" = $true
};

"query" = "mutation PauseReplicationMutation(`$targetClusterUuid: String!, `$sourceClusterUuids: [String!]!, `$shouldCancelImmediately: Boolean!, `$shouldPauseImmediately: Boolean) {
  enableReplicationPause(
    input: {clusterUuid: `$targetClusterUuid, enablePerLocationPause: {shouldCancelImmediately: `$shouldCancelImmediately, sourceClusterUuids: `$sourceClusterUuids, shouldPauseImmediately: `$shouldPauseImmediately}}
  ) {
    success
    __typename
  }
}"
}
}
# Querying API
Try
{
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCRequest = "SUCCESS"
}
Catch
{
$RSCRequest = "FAILED"
}
# Checking for permission errors
IF($RSCResponse.errors.message){$RSCResponse.errors.message}
# Setting timestamp
$UTCDateTime = [System.DateTime]::UtcNow
################################################
# Returing Job Info
################################################
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "PauseReplicationMutation"
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
$Object | Add-Member -MemberType NoteProperty -Name "SourceClusterID" -Value $SourceClusterID
$Object | Add-Member -MemberType NoteProperty -Name "TargetClusterID" -Value $TargetClusterID
$Object | Add-Member -MemberType NoteProperty -Name "CancelImmediately" -Value $CancelImmediately
$Object | Add-Member -MemberType NoteProperty -Name "DoNotPauseImmediately" -Value $DoNotPauseImmediately
$Object | Add-Member -MemberType NoteProperty -Name "RequestDateUTC" -Value $UTCDateTime
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message
$RSCEvents.Add($Object) | Out-Null

# Returning array
Return $Object
# End of function
}