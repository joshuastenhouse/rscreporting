################################################
# Function - Resume-RSCReplicationPair - Resumes replication (un-pause) on a replication pairing in RSC
################################################
Function Resume-RSCReplicationPair {
	
<#
.SYNOPSIS
Resumes replication to the Replication Target Cluster ID specified.

.DESCRIPTION
Use Get-RSCReplicationPairings for the correct source and target cluster IDs.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SourceCluserID
The RSC ID of the object required for the mutation.

.PARAMETER TargetClusterID
The RSC ID of the object required for the mutation.

.EXAMPLE
Resume-RSCReplicationPair -SourceCluserID "3422dc50-dbb0-4476-8016-971177e5aa59" -TargetClusterID "dcb308e8-819e-4782-9952-b978b9441f7e"

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
        [switch]$SkipOldSnapshots
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
IF($SkipOldSnapshots)
{
$RSCGraphQL = @{"operationName" = "ResumeReplicationMutation";

"variables" = @{
        "targetClusterUuid" = "$TargetClusterID"
        "sourceClusterUuids" = $SourceClusterID
        "shouldSkipOldSnapshots" = $true
};

"query" = "mutation ResumeReplicationMutation(`$targetClusterUuid: String!, `$sourceClusterUuids: [String!]!, `$shouldSkipOldSnapshots: Boolean!) {
  disableReplicationPause(
    input: {clusterUuid: `$targetClusterUuid, disablePerLocationPause: {shouldSkipOldSnapshots: `$shouldSkipOldSnapshots, sourceClusterUuids: `$sourceClusterUuids}}
  ) {
    success
    __typename
  }
}"
}
}
ELSE
{
$RSCGraphQL = @{"operationName" = "ResumeReplicationMutation";

"variables" = @{
        "targetClusterUuid" = "$TargetClusterID"
        "sourceClusterUuids" = $SourceClusterID
        "shouldSkipOldSnapshots" = $false
};

"query" = "mutation ResumeReplicationMutation(`$targetClusterUuid: String!, `$sourceClusterUuids: [String!]!, `$shouldSkipOldSnapshots: Boolean!) {
  disableReplicationPause(
    input: {clusterUuid: `$targetClusterUuid, disablePerLocationPause: {shouldSkipOldSnapshots: `$shouldSkipOldSnapshots, sourceClusterUuids: `$sourceClusterUuids}}
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
# Getting response
$JobID = $RSCResponse.data.beginManagedVolumeSnapshot.asyncRequestStatus.id
# Setting timestamp
$UTCDateTime = [System.DateTime]::UtcNow
################################################
# Returing Job Info
################################################
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "ResumeReplicationMutation"
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
$Object | Add-Member -MemberType NoteProperty -Name "SourceClusterID" -Value $SourceClusterID
$Object | Add-Member -MemberType NoteProperty -Name "TargetClusterID" -Value $TargetClusterID
$Object | Add-Member -MemberType NoteProperty -Name "SkipOldSnapshots" -Value $SkipOldSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "RequestDateUTC" -Value $UTCDateTime
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message

# Returning array
Return $Object
# End of function
}