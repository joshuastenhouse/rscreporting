################################################
# Function - Get-RSCK8SClusters - Getting all K8S Clusters connected to the RSC instance
################################################
Function Get-RSCK8SClusters {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all K8S Clusters.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCK8SClusters
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
# Getting Object List 
################################################
# Creating array for objects
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "K8sClustersListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query K8sClustersListQuery(`$first: Int!, `$after: String, `$isMultitenancyEnabled: Boolean = true) {
  k8sClusters(first: `$first, after: `$after) {
    edges {
      cursor
      node {
        id
        objectType
        name
        ...K8sVersionFragment
        ...K8sClusterRegionColumnFragment
        ...SlaAssignmentColumnFragment
        ...EffectiveSlaColumnFragment
        ...OrganizationsColumnFragment @include(if: `$isMultitenancyEnabled)
        ...K8sClusterCdmClusterColumnFragment
        ...K8sStatusAndNameFragment
        ...RubrikAgentNodePortsFragment
        ...NodeIPAddressFragment
        k8sDescendantNamespaces(filter: []) {
          count
          __typename
        }
        __typename
        clusterInfo {
          associatedCdm {
            id
            name
          }
          k8sVersion
          kuprClusterUuid
          port
          type
        }
        clusterIp
        clusterPortRanges {
          kuprClusterUuid
          maxPort
          minPort
          portRangeType
        }
        lastRefreshTime
        effectiveSlaDomain {
          id
          name
        }
        numWorkloadDescendants
        physicalPath {
          fid
          name
          objectType
        }
        rbsPortRanges {
          kuprClusterUuid
          maxPort
          minPort
        }
        slaAssignment
        slaPauseStatus
        status
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

fragment OrganizationsColumnFragment on HierarchyObject {
  allOrgs {
    name
    __typename
  }
  __typename
}

fragment K8sClusterRegionColumnFragment on K8sCluster {
  clusterInfo {
    associatedCdm {
      id
      name
      geoLocation {
        address
        __typename
      }
      __typename
    }
    __typename
  }
  __typename
}

fragment K8sVersionFragment on K8sCluster {
  clusterInfo {
    k8sVersion
    __typename
  }
  __typename
}

fragment EffectiveSlaColumnFragment on HierarchyObject {
  id
  effectiveSlaDomain {
    ...EffectiveSlaDomainFragment
    ... on GlobalSlaReply {
      description
      __typename
    }
    __typename
  }
  ... on CdmHierarchyObject {
    pendingSla {
      ...SLADomainFragment
      __typename
    }
    __typename
  }
  __typename
}

fragment EffectiveSlaDomainFragment on SlaDomain {
  id
  name
  ... on GlobalSlaReply {
    isRetentionLockedSla
    __typename
  }
  ... on ClusterSlaDomain {
    fid
    cluster {
      id
      name
      __typename
    }
    isRetentionLockedSla
    __typename
  }
  __typename
}

fragment SLADomainFragment on SlaDomain {
  id
  name
  ... on ClusterSlaDomain {
    fid
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  __typename
}

fragment SlaAssignmentColumnFragment on HierarchyObject {
  slaAssignment
  __typename
}

fragment K8sClusterCdmClusterColumnFragment on K8sCluster {
  clusterInfo {
    k8sVersion
    associatedCdm {
      id
      name
      status
      __typename
    }
    __typename
  }
  __typename
}

fragment K8sStatusAndNameFragment on K8sCluster {
  id
  lastRefreshTime
  status
  name
  __typename
}

fragment RubrikAgentNodePortsFragment on K8sCluster {
  clusterPortRanges {
    minPort
    maxPort
    portRangeType
    __typename
  }
  clusterInfo {
    port
    __typename
  }
  __typename
}

fragment NodeIPAddressFragment on K8sCluster {
  clusterIp
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListResponse.data.k8sClusters.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.k8sClusters.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.k8sClusters.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.k8sClusters.edges.node
}
################################################
# Processing Objects
################################################
# Creating array
$RSCK8SClusters = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Cluster in $RSCObjectList)
{
# Setting variables
$ClusterName = $Cluster.name
$ClusterID = $Cluster.id
$ClusterType = $Cluster.objectType
$ClusterStatus = $Cluster.status
$ClusterIPs = $Cluster.clusterIp
$ClusterIPCount = $ClusterIPs | Measure-Object | Select-Object -ExpandProperty Count
$ClusterNamespaceCount = $Cluster.k8sDescendantNamespaces.count
$ClusterInfo = $Cluster.clusterInfo
$ClusterVersion = $ClusterInfo.k8sVersion
$ClusterLocation = $ClusterInfo.type
$RubrikCluster = $ClusterInfo.associatedCdm.name
$RubrikClusterID = $ClusterInfo.associatedCdm.id
$RubrikClusterStatus = $ClusterInfo.associatedCdm.status
# SLA info
$ClusterSLADomainInfo = $Cluster.effectiveSlaDomain
$ClusterSLADomain = $ClusterSLADomainInfo.name
$ClusterSLADomainID = $ClusterSLADomainInfo.id
$ClusterSLAAssignment = $Cluster.slaAssignment
$ClusterSLAPaused = $Cluster.slaPauseStatus
# Last refresh
$ClusterLastRefreshUNIX = $Cluster.lastRefreshTime
IF($ClusterLastRefreshUNIX -ne $null){$ClusterLastRefreshUTC = Convert-RSCUNIXTime $ClusterLastRefreshUNIX}ELSE{$ClusterLastRefreshUTC = $null}
# Calculating hours since
$UTCDateTime = [System.DateTime]::UtcNow
IF($ClusterLastRefreshUTC -ne $null){$ClusterRefreshTimespan = New-TimeSpan -Start $ClusterLastRefreshUTC -End $UTCDateTime;$ClusterRefreshHoursSince = $ClusterRefreshTimespan | Select-Object -ExpandProperty TotalHours;$ClusterRefreshHoursSince = [Math]::Round($ClusterRefreshHoursSince,1)}ELSE{$ClusterRefreshHoursSince = $null}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# DB info
$Object | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $ClusterName
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $ClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ClusterType
$Object | Add-Member -MemberType NoteProperty -Name "Version" -Value $ClusterVersion
$Object | Add-Member -MemberType NoteProperty -Name "IPs" -Value $ClusterIPCount
$Object | Add-Member -MemberType NoteProperty -Name "IPAddresses" -Value $ClusterIPs
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $ClusterStatus
$Object | Add-Member -MemberType NoteProperty -Name "Namespaces" -Value $ClusterNamespaceCount
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ClusterSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ClusterSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $ClusterSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $ClusterSLAPaused
# Rubrik cluster info
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterStatus" -Value $RubrikClusterStatus
# Refresh timing
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshUTC" -Value $ClusterLastRefreshUTC
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $ClusterRefreshHoursSince
# Adding
$RSCK8SClusters.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCK8SClusters
# End of function
}