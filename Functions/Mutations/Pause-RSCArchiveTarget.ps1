################################################
# Function - Pause-RSCArchiveTarget - Pauses archiving to an archive target in RSC
################################################
Function Pause-RSCArchiveTarget {
	
<#
.SYNOPSIS
Makes a regular Managed Volume writeable by initiating a begin snapshot request on ManagedVolumeID or ObjectID (same thing).

.DESCRIPTION
Use Get-RSCArchiveTargets for valid archive target IDs.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ArchiveID
The RSC ID of the object required for the mutation.

.EXAMPLE
Pause-RSCArchiveTarget -ArchiveID "dcb308e8-819e-4782-9952-b978b9441f7e"

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
        [string]$ArchiveID
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
$RSCGraphQL = @{"operationName" = "PauseArchivalStorageMutation";

"variables" = @{
        "pauseTargetInput" = @{
            "id" = "$ArchiveID"
            }
};

"query" = "mutation PauseArchivalStorageMutation(`$pauseTargetInput: PauseTargetInput!) {
  pauseTarget(input: `$pauseTargetInput) {
    id: locationId
    __typename
  }
}"
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
$Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "PauseArchivalStorageMutation"
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveID" -Value $ArchiveID
$Object | Add-Member -MemberType NoteProperty -Name "RequestDateUTC" -Value $UTCDateTime
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message

# Returning array
Return $Object
# End of function
}