################################################
# Function - Register-RSCHost - Registering a physical/database host with RSC via the specified Rubrik cluster
################################################
Function Register-RSCHost {
	
<#
.SYNOPSIS
Registering a physical/database host with RSC via the specified Rubrik cluster. 

.DESCRIPTION
Specify the Rubrik cluster ID and the IP address or Hostname of the host to add to register the host with that cluster for fileset, database or volume backups.
This function presumes you already have the appropriate agent/certificate for the Rubrik cluster specified installed on the host.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER RubrikClusterID
The ID of the Rubrik cluster which is going to protect the host, ensure you have the appropriate agent already installed otherwise it will fail.
.PARAMETER IPAddressOrHostname
The IP address of the host to add, the Rubrik Cluster needs to be able to communicate with this IP address (not RSC) for this to work.

.OUTPUTS
Returns an array with the status of the add host request.

.EXAMPLE
Register-RSCHost -RubrikClusterID "0a8f6bc2-dce8-53a8-8e04-6de9293b5a26" -IPAddressOrHostname "10.4.5.6"
This adds a host with the IP address 10.4.5.6 to the Rubrik cluster specified, presuming it can talk to that IP and the correct RBS agent is already installed on the host.

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
        [string]$RubrikClusterID,
        [Parameter(Mandatory=$true)]
        [string]$IPAddressOrHostname
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
# Getting a list of Rubrik clusters to validate the ID specified
$RSCRubrikClusters = Get-RSCClusters
$RubrikClusterInfo = $RSCRubrikClusters | Where-Object {$_.ClusterID -eq $RubrikClusterID}
# Breaking if not found
IF($RubrikClusterInfo -eq $null)
{
Write-Error "ERROR: RubrikClusterID specified not found, check and try again.."
Break
}
# Getting addition info
$RubrikClusterName = $RubrikClusterInfo.Cluster
$RubrikClusterVersion = $RubrikClusterInfo.Version
$RubrikClusterLocation = $RubrikClusterInfo.Location
$RubrikClusterType = $RubrikClusterInfo. Type
################################################
# API Call To RSC GraphQL URI
################################################
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AddPhysicalHostMutation";

"variables" = @{
    "clusterUuid" = "$RubrikClusterID"
    "hosts" = @{
                "hostname" = "$IPAddressOrHostname"
                }
};

"query" = "mutation AddPhysicalHostMutation(`$clusterUuid: String!, `$hosts: [HostRegisterInput!]!) {
    bulkRegisterHost(input: {clusterUuid: `$clusterUuid, hosts: `$hosts}) {
      data {
        hostSummary {
          id
        }
      }
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
$Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "AddPhysicalHostMutation"
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
$Object | Add-Member -MemberType NoteProperty -Name "Hostname" -Value $IPAddressOrHostname
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "RequestDateUTC" -Value $UTCDateTime
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RequestStatus
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message
# Returning array
Return $Object
# End of function
}