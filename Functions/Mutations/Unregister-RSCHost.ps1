################################################
# Function - Unregister-RSCHost - Unregister a physical/database host with RSC (no need to specify the Rubrik cluster)
################################################
Function Unregister-RSCHost {
	
<#
.SYNOPSIS
Unregister a physical/database host with RSC (no need to specify the Rubrik cluster).

.DESCRIPTION
Specify the host ID which you want to unregsiter from RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER HostID
The HostID you want to unregister from RSC. Use Get-RSCHosts to obtain this.

.OUTPUTS
Returns an array with the status of the unregister host request.

.EXAMPLE
Unregister-RSCHost -HostID "fd3da41d-6cba-5c74-81a9-27490a02c55d"
This unregisters the host with the ID specified. It doesn't need to know the Rubrik cluster.

.NOTES
Author: Joshua Stenhouse
Date: 08/16/2023
#>
################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$HostID
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
# Getting a list of Rubrik clusters to validate the ID specified
$RSCHosts = Get-RSCHosts
$RSCHostInfo = $RSCHosts | Where-Object {$_.HostID -eq $HostID}
# Breaking if not found
IF($RSCHostInfo -eq $null)
{
Write-Error "ERROR: HostID specified not found, check and try again.."
Break
}
# Getting addition info
$RSCHostName = $RSCHostInfo.Host
$RubrikClusterName = $RSCHostInfo.RubrikCluster
$RubrikClusterID = $RSCHostInfo.RubrikClusterID
################################################
# API Call To RSC GraphQL URI
################################################
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "DeletePhysicalHostMutation";

"variables" = @{
    "ids" = "$HostID"
};

"query" = "mutation DeletePhysicalHostMutation(`$ids: [String!]!) {
    bulkDeleteHost(input: {ids: `$ids}) {
      success
    }
  }"
}
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Checking for permission errors
IF($RSCResponse.errors.message){$RSCResponse.errors.message}
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
$Object | Add-Member -MemberType NoteProperty -Name "Hostname" -Value $RSCHostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $HostID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "RequestDateUTC" -Value $UTCDateTime
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RequestStatus
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message

# Returning array
Return $Object
# End of function
}