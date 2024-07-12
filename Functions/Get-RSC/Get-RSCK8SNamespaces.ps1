################################################
# Function - Get-RSCK8SNamespaces - Getting all K*S Namespaces connected to the RSC instance
################################################
Function Get-RSCK8SNamespaces {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all K8S Namespaces.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCK8SNamespaces
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
$RSCK8SClusters = Get-RSCK8SClusters
################################################
# Getting Objects 
################################################
# Creating array for objects
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "K8sNamespaceListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query K8sNamespaceListQuery(`$first: Int!, `$after: String, `$isMultitenancyEnabled: Boolean = false) {
  k8sNamespaces(first: `$first, after: `$after) {
    edges {
      cursor
      node {
        id
        name
        logicalPath {
          name
          __typename
        }
        numPvcs
        numWorkloads
        ...SlaAssignmentColumnFragment
        ...EffectiveSlaColumnFragment
        ...OrganizationsColumnFragment @include(if: `$isMultitenancyEnabled)
        isRelic
        __typename
        effectiveSlaDomain {
          id
          name
        }
        k8sClusterId
        namespaceName
        newestSnapshot {
          date
          id
        }
        oldestSnapshot {
          date
          id
        }
        resourceVersion
        slaAssignment
        slaPauseStatus
        numWorkloadDescendants
        objectType
        onDemandSnapshotCount
        clusterScoped
        physicalPath {
          fid
          name
          objectType
        }
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
"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListResponse.data.k8sNamespaces.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.k8sNamespaces.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.k8sNamespaces.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.k8sNamespaces.edges.node
}
################################################
# Processing Objects
################################################
# Creating array
$RSCK8SNamespaces = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Namespace in $RSCObjectList)
{
# Setting variables
$Name = $Namespace.name
$ID = $Namespace.id
$PVCs =$Namespace.numPvcs
$Workloads = $Namespace.numWorkloads
$ResourceVersion = $Namespace.resourceVersion
$IsRelic = $Namespace.isRelic
# SLA info
$SLADomainInfo = $Namespace.effectiveSlaDomain
$SLADomain = $SLADomainInfo.name
$SLADomainID = $SLADomainInfo.id
$SLAAssignment = $Namespace.slaAssignment
$SLAPaused = $Namespace.slaPauseStatus
# Cluster info
$ClusterID = $Namespace.k8sClusterId
$ClusterInfo = $RSCK8SClusters | Where-Object {$_.ClusterID -eq $NamespaceClusterID}
$ClusterName = $ClusterInfo.Cluster
$ClusterVersion = $ClusterInfo.Version
$ClusterStatus = $ClusterInfo.Status
# Rubrik cluster info
$RubrikCluster = $ClusterInfo.RubrikCluster
$RubrikClusterID = $ClusterInfo.RubrikClusterID
$RubrikClusterStatus = $ClusterInfo.RubrikClusterStatus
# Snapshot info
$OnDemandSnapshots = $Namespace.onDemandSnapshotCount
$SnapshotDateUNIX = $Namespace.newestSnapshot.date
$SnapshotDateID = $Namespace.newestSnapshot.id
$OldestSnapshotDateUNIX = $Namespace.oldestSnapshot.date
$OldestSnapshotDateID = $Namespace.oldestSnapshot.id
# Converting snapshot dates
IF($SnapshotDateUNIX -ne $null){$SnapshotDateUTC = Convert-RSCUNIXTime $SnapshotDateUNIX}ELSE{$SnapshotDateUTC = $null}
IF($OldestSnapshotDateUNIX -ne $null){$OldestSnapshotDateUTC = Convert-RSCUNIXTime $OldestSnapshotDateUNIX}ELSE{$OldestSnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($SnapshotDateUTC -ne $null){$SnapshotTimespan = New-TimeSpan -Start $SnapshotDateUTC -End $UTCDateTime;$SnapshotHoursSince = $SnapshotTimespan | Select-Object -ExpandProperty TotalHours;$SnapshotHoursSince = [Math]::Round($SnapshotHoursSince,1)}ELSE{$SnapshotHoursSince = $null}
IF($OldestSnapshotDateUTC -ne $null){$OldestSnapshotTimespan = New-TimeSpan -Start $OldestSnapshotDateUTC -End $UTCDateTime;$OldestSnapshotDaysSince = $OldestSnapshotTimespan | Select-Object -ExpandProperty TotalDays;$OldestSnapshotDaysSince = [Math]::Round($OldestSnapshotDaysSince,1)}ELSE{$OldestSnapshotDaysSince = $null}
# Getting URL
$ObjectURL = Get-RSCObjectURL -ObjectType "K8SNamespace" -ObjectID $ID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# DB info
$Object | Add-Member -MemberType NoteProperty -Name "Namespace" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "NamespaceID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "Workloads" -Value $Workloads
$Object | Add-Member -MemberType NoteProperty -Name "PVCs" -Value $PVCs
$Object | Add-Member -MemberType NoteProperty -Name "ResourceVersion" -Value $ResourceVersion
# Location information
$Object | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $ClusterName
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $ClusterID
$Object | Add-Member -MemberType NoteProperty -Name "ClusterStatus" -Value $ClusterStatus
$Object | Add-Member -MemberType NoteProperty -Name "ClusterVersion" -Value $ClusterVersion
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $SLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $SLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $IsRelic
# Snapshot dates
$Object | Add-Member -MemberType NoteProperty -Name "OnDemandSnapshots" -Value $OnDemandSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTC" -Value $SnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTCAgeHours" -Value $SnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTC" -Value $OldestSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTCAgeDays" -Value $OldestSnapshotDaysSince
# Rubrik cluster info
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterStatus" -Value $RubrikClusterStatus
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCK8SNamespaces.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCK8SNamespaces
# End of function
}