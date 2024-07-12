################################################
# Function - Get-RSCOracleHosts - Getting all Oracle hosts visible to the RSC instance
################################################
Function Get-RSCOracleHosts {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all Oracle database hosts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCOracleHosts
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
################################################
# Getting All Hosts 
################################################
# Creating array for objects
$RSCHostList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "OracleHost";

"variables" = @{
"first" = 1000
};

"query" = "query OracleHost(`$first: Int, `$after: String) {
  oracleTopLevelDescendants(first: `$first, after: `$after) {
    edges {
      node {
        ... on OracleHost {
          id
          name
          objectType
          primaryClusterLocation {
            id
            clusterUuid
            name
            type
          }
          logBackupFrequency
          numChannels
          numWorkloadDescendants
          slaAssignment
          slaPauseStatus
          effectiveSlaDomain {
            id
            name
          }
          host {
            cdmId
            ipAddresses
            osName
            osType
            isOracleHost
            oracleUserDetails {
              queryUser
              sysDbaUser
            }
          }
          logRetentionHours
          hostLogRetentionHours
          connectionStatus {
            connectivity
            timestampMillis
          }
        }
      }
    }
    pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      startCursor
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCHostsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCHostList += $RSCHostsResponse.data.oracleTopLevelDescendants.edges.node
# Getting all results from paginations
While ($RSCHostsResponse.data.oracleTopLevelDescendants.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCHostsResponse.data.oracleTopLevelDescendants.pageInfo.endCursor
$RSCHostsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCHostList += $RSCHostsResponse.data.oracleTopLevelDescendants.edges.node
}
################################################
# Processing All Hosts 
################################################
# Creating array
$RSCHosts = [System.Collections.ArrayList]@()
# Counting
$RSCHostListCount = $RSCHostList | Measure-Object | Select-Object -ExpandProperty Count
# Processing Objects
$RSCHostListCounter = 0
# Getting current time for last connected
$UTCDateTime = [System.DateTime]::UtcNow
# For Each Object Getting Data
ForEach ($RSCHost in $RSCHostList)
{
# Setting variables
$HostName = $RSCHost.name
$HostID = $RSCHost.id
$HostCDMID = $RSCHost.host.cdmId
$HostDBs = $RSCHost.numWorkloadDescendants
$HostChanngels = $RSCHost.numChannels
$HostOSType = $RSCHost.host.osType
$HostOSName = $RSCHost.host.osName
$HostOracleSysdbaUser = $RSCHost.host.oracleUserDetails.sysDbaUser
$HostOracleQueryUser = $RSCHost.host.oracleUserDetails.queryUser
$HostLogRetentionHours = $RSCHost.hostLogRetentionHours
$HostRubrikCluster = $RSCHost.primaryClusterLocation.name
$HostRubrikClusterID = $RSCHost.primaryClusterLocation.id
$HostSLADomainID = $RSCHost.effectiveSlaDomain.id
$HostSLADomain = $RSCHost.effectiveSlaDomain.name
$HostSLAAssignment = $RSCHost.slaAssignment
$HostSLAPauseStatus = $RSCHost.slaPauseStatus
$HostConnectionStatus = $RSCHost.connectionStatus.connectivity
$HostLastConnectionUNIX = $RSCHost.connectionStatus.timestampMillis
# Converting UNIX times if not null
IF($HostLastConnectionUNIX -ne $null){$HostLastConnectionUTC = Convert-RSCUNIXTime $HostLastConnectionUNIX}
# If last connected not null, calculating hours since
IF($HostLastConnectionUTC -ne $null){$HostLastConnectionGap = New-Timespan -Start $HostLastConnectionUTC -End $UTCDateTime;$HostLastConnectionHours = $HostLastConnectionGap.TotalHours;$HostLastConnectionHours = [Math]::Round($HostLastConnectionHours, 1)}
ELSE{$HostLastConnectionHours = $null}
# Overriding Polaris in cluster name
IF($HostRubrikCluster -eq "Polaris"){$HostRubrikCluster = "RSC-Native"}
# Getting URL
$HostURL = Get-RSCObjectURL -ObjectType "OracleHost" -ObjectID $HostID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $HostRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $HostRubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $HostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $HostID
$Object | Add-Member -MemberType NoteProperty -Name "HostCDMID" -Value $HostCDMID
$Object | Add-Member -MemberType NoteProperty -Name "OSType" -Value $HostOSType
$Object | Add-Member -MemberType NoteProperty -Name "OSName" -Value $HostOSName
$Object | Add-Member -MemberType NoteProperty -Name "DBs" -Value $HostDBs
$Object | Add-Member -MemberType NoteProperty -Name "Channels" -Value $HostChanngels
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $HostConnectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "LastConnnectedUTC" -Value $HostLastConnectionUTC
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $HostLastConnectionHours
$Object | Add-Member -MemberType NoteProperty -Name "OracleSysDBAUser" -Value $HostOracleSysdbaUser
$Object | Add-Member -MemberType NoteProperty -Name "OracleQueryUser" -Value $HostOracleQueryUser
$Object | Add-Member -MemberType NoteProperty -Name "HostLogRetentionHours" -Value $HostLogRetentionHours
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $HostSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $HostSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $HostSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAPauseStatus" -Value $HostSLAPauseStatus
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $HostURL
# Adding
$RSCHosts.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCHosts
# End of function
}