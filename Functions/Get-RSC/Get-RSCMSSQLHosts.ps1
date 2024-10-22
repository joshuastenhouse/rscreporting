################################################
# Function - Get-RSCMSSQLHosts - Getting all MSSQL hosts visible to the RSC instance
################################################
Function Get-RSCMSSQLHosts {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all MSSQL hosts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCMSSQLHosts
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
# "instanceDescendantFilter":[{"field":"IS_ARCHIVED","texts":["false"]}],
# Creating array for objects
$RSCHostList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "mssqlTopLevelDescendants";

"variables" = @{
"first" = 1000
};

"query" = "query mssqlTopLevelDescendants(`$first: Int, `$after: String) {
  mssqlTopLevelDescendants(first: `$first, after: `$after) {
    edges {
      node {
        id
        name
        numWorkloadDescendants
        objectType
        slaAssignment
        slaPauseStatus
        effectiveSlaDomain {
          id
          name
        }
        primaryClusterLocation {
          clusterUuid
          id
          name
        }
        ... on PhysicalHost {
          cbtStatus
          cdmId
          defaultCbt
          ipAddresses
          isChangelistEnabled
          osName
          osType        
          vfdState
          numWorkloadDescendants
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
$RSCHostList += $RSCHostsResponse.data.mssqlTopLevelDescendants.edges.node
# Getting all results from paginations
While ($RSCHostsResponse.data.mssqlTopLevelDescendants.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCHostsResponse.data.mssqlTopLevelDescendants.pageInfo.endCursor
$RSCHostsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCHostList += $RSCHostsResponse.data.mssqlTopLevelDescendants.edges.node
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
$HostCDMID = $RSCHost.cdmId
$HostDBs = $RSCHost.numWorkloadDescendants
$HostOSType = $RSCHost.osType
$HostOSName = $RSCHost.osName
$HostCBTStatus = $RSCHost.cbtStatus
$HostVFDStatus = $RScHost.vfdState
$HostRubrikCluster = $RSCHost.primaryClusterLocation.name
$HostRubrikClusterID = $RSCHost.primaryClusterLocation.id
$HostSLADomainID = $RSCHost.effectiveSlaDomain.id
$HostSLADomain = $RSCHost.effectiveSlaDomain.name
$HostSLAAssignment = $RSCHost.slaAssignment
$HostSLAPauseStatus = $RSCHost.slaPauseStatus
$HostConnectionStatus = $RSCHost.connectionStatus.connectivity
$HostLastConnectionUNIX = $RSCHost.connectionStatus.timestampMillis
$HostType = $RSCHost.objectType
# Converting UNIX times if not null
IF($HostLastConnectionUNIX -ne $null){$HostLastConnectionUTC = Convert-RSCUNIXTime $HostLastConnectionUNIX}
# If last connected not null, calculating hours since
IF($HostLastConnectionUTC -ne $null){$HostLastConnectionGap = New-Timespan -Start $HostLastConnectionUTC -End $UTCDateTime;$HostLastConnectionHours = $HostLastConnectionGap.TotalHours;$HostLastConnectionHours = [Math]::Round($HostLastConnectionHours, 1)}
ELSE{$HostLastConnectionHours = $null}
# Overriding Polaris in cluster name
IF($HostRubrikCluster -eq "Polaris"){$HostRubrikCluster = "RSC-Native"}
# Getting URL
$HostURL = Get-RSCObjectURL -ObjectType "MssqlHost" -ObjectID $HostID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $HostRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $HostRubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $HostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $HostID
$Object | Add-Member -MemberType NoteProperty -Name "HostCDMID" -Value $HostCDMID
$Object | Add-Member -MemberType NoteProperty -Name "HostType" -Value $HostType
$Object | Add-Member -MemberType NoteProperty -Name "OSType" -Value $HostOSType
$Object | Add-Member -MemberType NoteProperty -Name "OSName" -Value $HostOSName
$Object | Add-Member -MemberType NoteProperty -Name "DBs" -Value $HostDBs
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $HostConnectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "LastConnnectedUTC" -Value $HostLastConnectionUTC
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $HostLastConnectionHours
$Object | Add-Member -MemberType NoteProperty -Name "CBTStatus" -Value $HostCBTStatus
$Object | Add-Member -MemberType NoteProperty -Name "VFDStatus" -Value $HostVFDStatus
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