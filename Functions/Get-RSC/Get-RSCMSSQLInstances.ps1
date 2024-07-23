################################################
# Function - Get-RSCMSSQLInstances - Getting all MSSQL instances visible to the RSC instance
################################################
Function Get-RSCMSSQLInstances {

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
Get-RSCMSSQLInstances
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
# Getting All Instances 
################################################
# Creating array for objects
$RSCHostList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "PhysicalHosts";

"variables" = @{
"hostRoot" = "WINDOWS_HOST_ROOT"
};

"query" = "query PhysicalHosts(`$hostRoot: HostRoot!) {
  physicalHosts(hostRoot: `$hostRoot) {
    edges {
      node {
        id
        name
        cluster {
          id
          name
        }
        descendantConnection {
          edges {
            node {
              ... on MssqlInstance {
                id
                objectType
                name
                slaAssignment
                effectiveSlaDomain {
                  id
                  name
                  version
                }
                unprotectableReasons
                numWorkloadDescendants
              }
            }
          }
        }
      }
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
$RSCHostList += $RSCHostsResponse.data.PhysicalHosts.edges.node
# Getting all results from paginations
While ($RSCHostsResponse.data.PhysicalHosts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCHostsResponse.data.PhysicalHosts.pageInfo.endCursor
$RSCHostsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCHostList += $RSCHostsResponse.data.PhysicalHosts.edges.node
}
################################################
# Processing All Hosts 
################################################
# Creating array
$RSCMSSQLInstances = [System.Collections.ArrayList]@()
# Getting current time for last connected
$UTCDateTime = [System.DateTime]::UtcNow
# For Each Object Getting Data
ForEach ($RSCHost in $RSCHostList)
{
# Setting variables
$HostName = $RSCHost.name
$HostID = $RSCHost.id
$HostRubrikCluster = $RSCHost.cluster.name
$HostRubrikClusterID = $RSCHost.cluster.id
$HostInfo = $RSCHost.descendantConnection.edges.node
$HostSQLInstances = $HostInfo | Where-Object {$_.ObjectType -eq "MssqlInstance"}
# Adding each SQL instance
ForEach($HostSQLInstance in $HostSQLInstances)
{
$MSSQLInstanceID = $HostSQLInstance.id
$MSSQLInstanceType = $HostSQLInstance.objectType
$MSSQLInstanceName = $HostSQLInstance.name
$MSSQLInstanceSLAssignment = $HostSQLInstance.slaAssignment
$MSSQLInstanceSLADomain = $HostSQLInstance.effectiveSlaDomain.name
$MSSQLInstanceSLADomainID = $HostSQLInstance.effectiveSlaDomain.id
$MSSQLInstanceDBCount = $HostSQLInstance.numWorkloadDescendants
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Instance" -Value $MSSQLInstanceName
$Object | Add-Member -MemberType NoteProperty -Name "InstanceID" -Value $MSSQLInstanceID
$Object | Add-Member -MemberType NoteProperty -Name "InstanceType" -Value $MSSQLInstanceType
$Object | Add-Member -MemberType NoteProperty -Name "DBs" -Value $MSSQLInstanceDBCount
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $MSSQLInstanceSLAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $MSSQLInstanceSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $MSSQLInstanceSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $HostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $HostID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $HostRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $HostRubrikClusterID
# Adding
$RSCMSSQLInstances.Add($Object) | Out-Null
# End of for each sql instance on host below
}
# End of for each sql instance on host above
# End of for each host below
}
# End of for each host above

# Returning array
Return $RSCMSSQLInstances
# End of function
}