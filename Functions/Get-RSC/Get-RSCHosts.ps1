################################################
# Function - Get-RSCHosts - Getting all hosts visible to the RSC instance
################################################
Function Get-RSCHosts {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning all hosts registered to RSC via the Rubrik Backup Service agent for database, fileset or volume based backups.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCHosts
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
# Building array of host types
$RSCHostTypes = "LINUX_HOST_ROOT","WINDOWS_HOST_ROOT","NAS_HOST_ROOT"
# For each host type, getting hosts
ForEach ($RSCHostType in $RSCHostTypes)
{
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "physicalHosts";

"variables" = @{
"hostRoot" = "$RSCHostType"
"first" = 100
};

"query" = "query physicalHosts(`$hostRoot: HostRoot!,`$after: String, `$first: Int) {
  physicalHosts(hostRoot: `$hostRoot,after: `$after, first: `$first) {
    nodes {
      osName
      ipAddresses
      id
      name
      numWorkloadDescendants
      connectionStatus {
        connectivity
        timestampMillis
      }
      cluster {
        id
        name
      }
      objectType
      slaAssignment
      slaPauseStatus
      effectiveSlaDomain {
        ... on ClusterSlaDomain {
          name
          fid
          isRetentionLockedSla
        }
      }
      osType
      cdmId
      isArchived
      vfdState
      isOracleHost
      oracleUserDetails {
        sysDbaUser
        queryUser
      }
      defaultCbt
      cbtStatus
      latestUserNote {
        time
        userName
        objectId
        userNote
      }
      logicalPath {
        fid
        name
        objectType
      }
      physicalPath {
        fid
        name
        objectType
      }
    }
    pageInfo {
      startCursor
      endCursor
      hasPreviousPage
      hasNextPage
      __typename
    }
  }
}
"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCHostsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCHostList += $RSCHostsResponse.data.physicalHosts.nodes
# Getting all results from paginations
While ($RSCHostsResponse.data.physicalHosts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCHostsResponse.data.physicalHosts.pageInfo.endCursor
$RSCHostsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCHostList += $RSCHostsResponse.data.physicalHosts.nodes
}
# End of for each host type below
}
# End of for each host type above
################################################
# Processing All Hosts 
################################################
# Creating array
$RSCHosts = [System.Collections.ArrayList]@()
# Counting
$RSCHostListCount = $RSCHostList | Measure-Object | Select-Object -ExpandProperty Count
# Processing Objects
$RSCHostListCounter = 0
# Getting current time for last snapshot age
$UTCDateTime = [System.DateTime]::UtcNow
# For Each Object Getting Data
ForEach ($RSCHost in $RSCHostList)
{
$RSCHostListCounter ++
# Write-Host "ProcessingObject: $RSCHostListCounter/$RSCHostListCount"
# Setting variables
$HostName = $RSCHost.name
$HostID = $RSCHost.id
$HostCDMID = $RSCHost.cdmId
$HostCluster = $RSCHost.cluster
$HostClusterID = $HostCluster.id
$HostClusterName = $HostCluster.name
$HostOS = $RSCHost.osName
$HostType = $RSCHost.objectType
$HostIsOracle = $RSCHost.isOracleHost
$HostConnection = $RSCHost.connectionStatus
$HostStatus = $HostConnection.connectivity
$HostLastConnection = $HostConnection.timestampMillis
$HostIsArchived = $RSCHost.isArchived
$HostObjects = $RSCHost.numWorkloadDescendants
$HostNote = $RSCHost.latestUserNote
$HostDefaultCBT = $RSCHost.defaultCbt
$HostCBTStatus = $RSCHost.cbtStatus
$HostVFDStatus = $RSCHost.vfdState
$HostSLAAssignment = $RSCHost.slaAssignment
$HostSLAPauseStatus = $RSCHost.slaPauseStatus
# Converting UNIX times if not null
IF($HostLastConnection -ne $null){$HostLastConnection = Convert-RSCUNIXTime $HostLastConnection}
# If host status is replicated, not calculating gap or connection as it's not valid from the replica
IF ($HostStatus -eq "REPLICATED_TARGET")
{
$HostLastConnectionHours = $null
$HostLastConnection = $null
}
ELSE
{
# If last connected not null, calculating hours since
IF($HostLastConnection -ne $null){
$HostLastConnectionGap = New-Timespan -Start $HostLastConnection -End $UTCDateTime
$HostLastConnectionHours = $HostLastConnectionGap.TotalHours
$HostLastConnectionHours = [Math]::Round($HostLastConnectionHours, 1)
}
ELSE
{
$HostLastConnectionHours = $null	
}
}
# Overriding Polaris in cluster name
IF($HostClusterName -eq "Polaris"){$HostClusterName = "RSC-Native"}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $HostClusterName
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $HostName
$Object | Add-Member -MemberType NoteProperty -Name "OS" -Value $HostOS
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $HostStatus
$Object | Add-Member -MemberType NoteProperty -Name "LastConnectedUTC" -Value $HostLastConnection
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $HostLastConnectionHours
$Object | Add-Member -MemberType NoteProperty -Name "ProtectableObjects" -Value $HostObjects
$Object | Add-Member -MemberType NoteProperty -Name "IsOracle" -Value $HostIsOracle
$Object | Add-Member -MemberType NoteProperty -Name "DefaultCBT" -Value $HostDefaultCBT
$Object | Add-Member -MemberType NoteProperty -Name "CBTStatus" -Value $HostCBTStatus
$Object | Add-Member -MemberType NoteProperty -Name "VFDStatus" -Value $HostVFDStatus
# SLA info
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $HostSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPauseStatus" -Value $HostSLAPauseStatus
# IDs
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $HostClusterID
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $HostID
$Object | Add-Member -MemberType NoteProperty -Name "HostCDMID" -Value $HostCDMID
# Adding
$RSCHosts.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCHosts
# End of function
}