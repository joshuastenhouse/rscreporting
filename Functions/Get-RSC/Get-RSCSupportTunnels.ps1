################################################
# Function - Get-RSCSupportTunnels - Getting all Cluster support tunnels
################################################
Function Get-RSCSupportTunnels {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returns a list of all support tunnels recently open or in use across all Rubrik clusters.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSupportTunnels
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
# Getting clusters
$RSCClusters = Get-RSCClusters
################################################
# Querying RSC GraphQL API
################################################
# Creating array
$RSCSupportTunnels = [System.Collections.ArrayList]@()
# For Each Cluster Getting nodes
ForEach($RSCCluster in $RSCClusters)
{
# Setting variable
$RSCClusterID = $RSCCluster.ClusterID
$RSCClusterName = $RSCCluster.Cluster
$RSCClusterLocation = $RSCCluster.Location
$RSCClusterTimeZone = $RSCCluster.Timezone
# Creating URL
$RSCClusterSupportTunnelURL = $RSCURL + "/support_tunnel"
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "ClusterNodesQuery";

"variables" = @{
"first" = 1000
"clusterUuid" = "$RSCClusterID"
};

"query" = "query ClusterNodesQuery(`$clusterUuid: String!) {
  clusterNodes(input: {clusterUuid: `$clusterUuid}) {
    total
    data {
      id
      status
      supportTunnel {
        isTunnelEnabled
        port
        enabledTime
        inactivityTimeoutInSeconds
        errorMessage
        __typename
      }
      __typename
    }
    __typename
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Getting node list
$RSCNodeList = $RSCResponse.data.clusterNodes.data
################################################
# Processing nodes
################################################
ForEach($RSCNode in $RSCNodeList)
{
# Setting variables
$RSCNodeID = $RSCNode.ID
$RSCSupportTunnelInfo = $RSCNode.supportTunnel
$RSCSupportTunnelEnabled = $RSCSupportTunnelInfo.isTunnelEnabled
$RSCSupportTunnelPort = $RSCSupportTunnelInfo.port
$RSCSupportTunnelEnabledTimeUNIX = $RSCSupportTunnelInfo.enabledTime
$RSCSupportTunnelInactivitySeconds = $RSCSupportTunnelInfo.inactivityTimeoutInSeconds
$RSCSupportTunnelErrorMessage = $RSCSupportTunnelInfo.errorMessage
# Converting if greater than 60
IF($RSCSupportTunnelInactivitySeconds -gt 59)
{
$RSCSupportTunnelInactivityMinutes = $RSCSupportTunnelInactivitySeconds / 60
$RSCSupportTunnelInactivityMinutes = [Math]::Round($RSCSupportTunnelInactivityMinutes)
}
ELSE
{
$RSCSupportTunnelInactivityMinutes = 0
}
# Converting time
$UTCDateTime = [System.DateTime]::UtcNow
IF($RSCSupportTunnelEnabledTimeUNIX -ne $null){$RSCSupportTunnelEnabledTimeUTC = Convert-RSCUNIXTime $RSCSupportTunnelEnabledTimeUNIX}ELSE{$RSCSupportTunnelEnabledTimeUTC = $null}
IF($RSCSupportTunnelEnabledTimeUTC -ne $null)
{
$RSCSupportTunnelTimespan = New-TimeSpan -Start $RSCSupportTunnelEnabledTimeUTC -End $UTCDateTime
$RSCSupportTunnelDays = $RSCSupportTunnelTimespan | Select-Object -ExpandProperty TotalDays
$RSCSupportTunnelDays = [Math]::Round($RSCSupportTunnelDays)
$RSCSupportTunnelHours = $RSCSupportTunnelTimespan | Select-Object -ExpandProperty TotalHours
$RSCSupportTunnelHours = [Math]::Round($RSCSupportTunnelHours)
$RSCSupportTunnelMinutes = $RSCSupportTunnelTimespan | Select-Object -ExpandProperty TotalMinutes
$RSCSupportTunnelMinutes = [Math]::Round($RSCSupportTunnelMinutes)
}
ELSE
{
$RSCSupportTunnelDays = $null
$RSCSupportTunnelHours = $null
$RSCSupportTunnelMinutes = $null
}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Node" -Value $RSCNodeID
$Object | Add-Member -MemberType NoteProperty -Name "SupportTunnelEnabled" -Value $RSCSupportTunnelEnabled
$Object | Add-Member -MemberType NoteProperty -Name "Port" -Value $RSCSupportTunnelPort
$Object | Add-Member -MemberType NoteProperty -Name "EnabledTimeUTC" -Value $RSCSupportTunnelEnabledTimeUTC
$Object | Add-Member -MemberType NoteProperty -Name "TotalDaysOpen" -Value $RSCSupportTunnelDays
$Object | Add-Member -MemberType NoteProperty -Name "TotalHoursOpen" -Value $RSCSupportTunnelHours
$Object | Add-Member -MemberType NoteProperty -Name "TotalMinutesOpen" -Value $RSCSupportTunnelMinutes
$Object | Add-Member -MemberType NoteProperty -Name "TotalInactivityMinutes" -Value $RSCSupportTunnelInactivitySeconds
$Object | Add-Member -MemberType NoteProperty -Name "TotalInactivitySeconds" -Value $RSCSupportTunnelInactivityMinutes
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCSupportTunnelErrorMessage
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RSCClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RSCClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $RSCClusterLocation
$Object | Add-Member -MemberType NoteProperty -Name "Timezone" -Value $RSCClusterTimeZone
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $RSCClusterSupportTunnelURL
# Adding
$RSCSupportTunnels.Add($Object) | Out-Null
# End of for each node below
}
# End of for each node above
#
# End of for each cluster below
}
# End of for each cluster above

# Removing nodes with no tunnel
$RSCSupportTunnels = $RSCSupportTunnels | Where-Object {$_.SupportTunnelEnabled -ne $FALSE}

# Returning array
Return $RSCSupportTunnels
# End of function
}