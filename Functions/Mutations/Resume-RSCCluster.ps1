################################################
# Function - Resume-RSCCluster - Resumes all new jobs from starting on the Rubrik cluster ID specified via RSC
################################################
Function Resume-RSCCluster {
	
<#
.SYNOPSIS
Resumes all new jobs from starting on the specified Rubrik cluster ID.

.DESCRIPTION
Resumes all jobs on the cluster including backup, replication and archiving jobs.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ClusterID
The cluster ID which you want to perform the mutation on.

.EXAMPLE
Resume-RSCCluster -ClusterID "dcb308e8-819e-4782-9952-b978b9441f7e"

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
        [string]$ClusterID
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
$RSCGraphQL = @{"operationName" = "PauseResumeClusterProtectionMutation";

"variables" = @{
        "input" = @{
            "clusterUuids" = $ClusterID
            "togglePauseStatus" = $False
            }
};

"query" = "mutation PauseResumeClusterProtectionMutation(`$input: UpdateClusterPauseStatusInput!) {
  updateClusterPauseStatus(input: `$input) {
    pauseStatuses {
      clusterUuid
      success
      __typename
    }
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
$Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "PauseResumeClusterProtectionMutation"
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $ClusterID
$Object | Add-Member -MemberType NoteProperty -Name "RequestDateUTC" -Value $UTCDateTime
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message

# Returning array
Return $Object
# End of function
}