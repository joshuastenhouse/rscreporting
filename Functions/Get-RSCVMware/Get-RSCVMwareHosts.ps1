################################################
# Function - Get-RSCVMwareHosts - Getting all VMware hosts connected to the RSC instance
################################################
Function Get-RSCVMwareHosts {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all VMware hosts (ESXi servers).

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCVMwareHosts
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
# Getting All VMware Hosts 
################################################
# Creating array for objects
$RSCHostList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "vSphereHostConnection";

"variables" = @{
"first" = 100
};

"query" = "query vSphereHostConnection(`$first: Int, `$after: String) {
  vSphereHostConnection(first: `$first, after: `$after) {
    edges {
      node {
        id
        name
        logicalPath {
          name
          objectType
          fid
        }
        numWorkloadDescendants
        objectType
        physicalPath {
          fid
          name
          objectType
        }
        slaPauseStatus
        slaAssignment
        latestUserNote {
          objectId
          time
          userName
          userNote
        }
        effectiveSlaDomain {
          id
          name
        }
        isStandaloneHost
        ioFilterStatus
      }
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCHostListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCHostList += $RSCHostListResponse.data.vSphereHostConnection.edges.node
# Getting all results from paginations
While ($RSCHostListResponse.data.vSphereHostConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCHostListResponse.data.vSphereHostConnection.pageInfo.endCursor
$RSCHostListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCHostList += $RSCHostListResponse.data.vSphereHostConnection.edges.node
}
################################################
# Processing All Hosts 
################################################
# Creating array
$RSCHosts = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCHost in $RSCHostList)
{
# Setting variables
$RSCHostID = $RSCHost.id
$RSCHostName = $RSCHost.name
$RSCHostVMCount = $RSCHost.numWorkloadDescendants
$RSCHostSLADomainInfo = $RSCHost.effectiveSlaDomain
$RSCHostSLADomain = $RSCHostSLADomainInfo.name
$RSCHostSLADomainID = $RSCHostSLADomainInfo.id
$RSCHostSLAAssignment = $RSCHost.slaAssignment
$RSCHostSLAPaused = $RSCHost.slaPauseStatus
$RSCHostPhysicalPaths = $RSCHost.physicalPath
$RSCHostClusterInfo = $RSCHostPhysicalPaths | Where-Object {$_.objectType -eq "VSphereComputeCluster"}
$RSCHostCluster = $RSCHostClusterInfo.name
$RSCHostClusterID = $RSCHostClusterInfo.fid
$RSCHostDatacenterInfo = $RSCHostPhysicalPaths | Where-Object {$_.objectType -eq "VSphereDatacenter"}
$RSCHostDatacenter = $RSCHostDatacenterInfo.name
$RSCHostDatacenterID = $RSCHostDatacenterInfo.fid
$RSCHostvCenterInfo = $RSCHostPhysicalPaths | Where-Object {$_.objectType -eq "VSphereVCenter"}
$RSCHostvCenter = $RSCHostvCenterInfo.name
$RSCHostvCenterID = $RSCHostvCenterInfo.fid
$RSCHostUsernote = $RSCHost.latestUserNote
$RSCHostIOFilterStatus = $RSCHost.ioFilterStatus
$RSCHostIsStandalone = $RSCHost.isStandaloneHost
# Getting URL
$RSCHostURL = Get-RSCObjectURL -ObjectType "vCenterHost" -ObjectID $RSCHostID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $RSCHostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $RSCHostID
$Object | Add-Member -MemberType NoteProperty -Name "VMs" -Value $RSCHostVMCount
$Object | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $RSCHostCluster
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $RSCHostClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Datacenter" -Value $RSCHostDatacenter
$Object | Add-Member -MemberType NoteProperty -Name "DatacenterID" -Value $RSCHostDatacenterID
$Object | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $RSCHostvCenter
$Object | Add-Member -MemberType NoteProperty -Name "vCenterID" -Value $RSCHostvCenterID
$Object | Add-Member -MemberType NoteProperty -Name "IOFilter" -Value $RSCHostIOFilterStatus
$Object | Add-Member -MemberType NoteProperty -Name "IsStandalone" -Value $RSCHostIsStandalone
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $RSCHostSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $RSCHostSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $RSCHostSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAIsPaused" -Value $RSCHostSLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $RSCHostURL
# Adding
$RSCHosts.Add($Object) | Out-Null
# End of for each vCenter below
}
# End of for each vCenter above

# Returning array
Return $RSCHosts
# End of function
}