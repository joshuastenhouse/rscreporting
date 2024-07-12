################################################
# Function - Get-RSCVMwarevCenters - Getting all vCenters connected to the RSC instance
################################################
Function Get-RSCVMwarevCenters {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all VMware vCenters.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCVMwarevCenters
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
$RSCvCenterHostList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "vSphereHostConnection";

"variables" = @{
"first" = 1000
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
$RSCvCenterHostListReponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCvCenterHostList += $RSCvCenterHostListReponse.data.vSphereHostConnection.edges.node
# Getting all results from paginations
While ($RSCvCenterHostListReponse.data.vSphereHostConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCvCenterHostListReponse.data.vSphereHostConnection.pageInfo.endCursor
$RSCvCenterHostListReponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCvCenterHostList += $RSCvCenterHostListReponse.data.vSphereHostConnection.edges.node
}
################################################
# Processing All Hosts 
################################################
# Creating array
$RSCHosts = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCHost in $RSCvCenterList)
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
# Adding
$RSCHosts.Add($Object) | Out-Null
# End of for each vCenter below
}
# End of for each vCenter above

################################################
# Getting All vCenters 
################################################
# Creating array for objects
$RSCvCenterList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "VCenterListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query VCenterListQuery(`$first: Int!, `$after: String) {
  vSphereVCenterConnection(first: `$first, after: `$after) {
    edges {
      cursor
      node {
        id
        ...HierarchyObjectNameColumnFragment
        ...CdmClusterColumnFragment
        ...VCenterStatusFragment
        lastRefreshTime
        aboutInfo {
          version
          __typename
        }
        isVmc
        vmcProvider
          tagChildConnection {
      edges {
        node {
          id
          name
          slaAssignment
        }
      }
    }
        logicalChildConnection {
      edges {
        node {
          id
          name
          objectType
          slaAssignment

          }
        }
      }
        username
        numWorkloadDescendants
        authorizedOperations
                configuredSlaDomain {
      ... on ClusterSlaDomain {
        name
        fid
        cdmId
        protectedObjectCount
      }
    }
        __typename
      }
      __typename
    }
    pageInfo {
      startCursor
      endCursor
      hasNextPage
      hasPreviousPage
      __typename
    }
    __typename
  }
}

fragment HierarchyObjectNameColumnFragment on HierarchyObject {
  name
  __typename
}

fragment CdmClusterColumnFragment on CdmHierarchyObject {
  replicatedObjectCount
  cluster {
    id
    name
    version
    status
    __typename
  }
  __typename
}

fragment VCenterStatusFragment on VsphereVcenter {
  id
  lastRefreshTime
  connectionStatus {
    status
    message
    __typename
  }
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCvCenterListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCvCenterList += $RSCvCenterListResponse.data.vSphereVCenterConnection.edges.node
# Getting all results from paginations
While ($RSCvCenterListResponse.data.vSphereVCenterConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCvCenterListResponse.data.vSphereVCenterConnection.pageInfo.endCursor
$RSCvCenterListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCvCenterList += $RSCvCenterListResponse.data.vSphereVCenterConnection.edges.node
}
################################################
# Processing All vCenters 
################################################
# Creating array
$RSCvCenters = [System.Collections.ArrayList]@()
# Time for refresh since
$UTCDateTime = [System.DateTime]::UtcNow
# For Each Object Getting Data
ForEach ($vCenter in $RSCvCenterList)
{
# Setting variables
$vCenterID = $vCenter.id
$vCenterName = $vCenter.name
$vCenterVersion = $vCenter.aboutInfo.version
$vCenterIsVMC = $vCenter.isVmc
$vCenterVMCProvider = $vCenter.vmcProvider
$vCenterVMs = $vCenter.numWorkloadDescendants
$vCenterUsername = $vCenter.username
# Selecting hosts
$vCenterHosts = $RSCHosts | Where-Object {$_.vCenterID -eq $vCenterID}
$vCenterHostsCount = $vCenterHosts | Measure-Object | Select-Object -ExpandProperty Count
# Selecting clusters
$vCenterClusters = $vCenterHosts | Select-Object -ExpandProperty ClusterID -Unique
$vCenterClustersCount = $vCenterClusters | Measure-Object | Select-Object -ExpandProperty Count
# Calculating VMs per host
IF(($vCenterVMs -gt 0) -and ($vCenterHostsCount -gt 0))
{
$VMsPerHost = $vCenterVMs / $vCenterHostsCount
$VMsPerHost = [Math]::Round($VMsPerHost,2)
}ELSE{$VMsPerHost = 0}
# Last refresh
$vCenterLastRefreshUNIX = $vCenter.lastRefreshTime
$vCenterLastRefreshUTC = Convert-RSCUNIXTime $vCenterLastRefreshUNIX
# Converting dates
IF($vCenterLastRefreshUNIX -ne $null){$vCenterLastRefreshUTC = Convert-RSCUNIXTime $vCenterLastRefreshUNIX}ELSE{$vCenterLastRefreshUTC = $null}
# Calculating timespan if not null
IF ($vCenterLastRefreshUTC -ne $null)
{
$vCenterRefreshTimespan = New-TimeSpan -Start $vCenterLastRefreshUTC -End $UTCDateTime
$vCenterRefreshMinutesSince = $vCenterRefreshTimespan | Select-Object -ExpandProperty TotalMinutes
$vCenterRefreshMinutesSince = [Math]::Round($vCenterRefreshMinutesSince)
}
ELSE
{
$vCenterRefreshMinutesSince = $null
}
# Getting DC and tag counts
$vCenterDatacenters = $vCenter.logicalChildConnection.edges.node | Measure-Object | Select-Object -ExpandProperty Count
$vCenterTags = $vCenter.tagChildConnection.edges.node | Measure-Object | Select-Object -ExpandProperty Count
# Rubrik cluster info
$vCenterRubrikClusters = $vCenter.cluster | Measure-Object | Select-Object -ExpandProperty Count
$vCenterRubrikCluster = $vCenter.cluster | Select-Object -First 1
$vCenterRubrikClusterName = $vCenterRubrikCluster.name
$vCenterRubrikClusterID = $vCenterRubrikCluster.id
$vCenterRubrikClusterVersion = $vCenterRubrikCluster.version
$vCenterRubrikClusterStatus = $vCenterRubrikCluster.status
# Getting URL
$vCenterURL = Get-RSCObjectURL -ObjectType "vCenter" -ObjectID $vCenterID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vCenterName
$Object | Add-Member -MemberType NoteProperty -Name "vCenterID" -Value $vCenterID
$Object | Add-Member -MemberType NoteProperty -Name "Version" -Value $vCenterVersion
$Object | Add-Member -MemberType NoteProperty -Name "VMs" -Value $vCenterVMs
$Object | Add-Member -MemberType NoteProperty -Name "Hosts" -Value $vCenterHostsCount
$Object | Add-Member -MemberType NoteProperty -Name "VMsPerHost" -Value $VMsPerHost
$Object | Add-Member -MemberType NoteProperty -Name "Clusters" -Value $vCenterClustersCount
$Object | Add-Member -MemberType NoteProperty -Name "Datacenters" -Value $vCenterDatacenters
$Object | Add-Member -MemberType NoteProperty -Name "Tags" -Value $vCenterTags
$Object | Add-Member -MemberType NoteProperty -Name "Username" -Value $vCenterUsername
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshUTC" -Value $vCenterLastRefreshUTC
$Object | Add-Member -MemberType NoteProperty -Name "MinutesSince" -Value $vCenterRefreshMinutesSince
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusters" -Value $vCenterRubrikClusters
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterName" -Value $vCenterRubrikClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $vCenterRubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterVersion" -Value $vCenterRubrikClusterVersion
$Object | Add-Member -MemberType NoteProperty -Name "IsVMC" -Value $vCenterIsVMC
$Object | Add-Member -MemberType NoteProperty -Name "VMCProvider" -Value $vCenterVMCProvider
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $vCenterURL
# Adding
$RSCvCenters.Add($Object) | Out-Null
# End of for each vCenter below
}
# End of for each vCenter above

# Returning array
Return $RSCvCenters
# End of function
}