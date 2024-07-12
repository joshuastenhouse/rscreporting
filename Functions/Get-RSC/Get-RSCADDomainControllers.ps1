################################################
# Function - Get-RSCADDomainControllers - Getting All Active Directory Domain Controllers Protected by RSC
################################################
Function Get-RSCADDomainControllers {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all protected Active Directory Domain Controllers.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCADDomainControllers
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 07/08/2024
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Querying RSC GraphQL API
################################################
# Creating array for objects
$RSCList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "OnPremAdDomainControllerListDeprecatedQuery";

"variables" = @{
"first" = 100
"sortBy" = "NAME"
"sortOrder" = "ASC"
};

"query" = "query OnPremAdDomainControllerListDeprecatedQuery(`$first: Int, `$after: String, `$sortBy: HierarchySortByField, `$sortOrder: SortOrder) {
  activeDirectoryDomainControllers(first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder) {
    count
    edges {
      cursor
      node {
        id
        name
        dcLocation
        fsmoRoles
        activeDirectoryDomain {
          name
          id
          smbDomain {
            id
            status
            __typename
          }
          cluster {
            id
            name
            version
            __typename
          }
          __typename
        }
        serverRoles
        slaPauseStatus
        isRelic
        snapshotConnection {
          count
          __typename
        }
        rbsStatus {
          connectivity
          __typename
        }
        ...EffectiveSlaColumnFragment
        ...SlaAssignmentColumnFragment
        ... on CdmHierarchyObject {
          replicatedObjectCount
          cluster {
            id
            name
            version
            status
            __typename
            clusterNodeConnection {
              count
              nodes {
                ipAddress
                clusterId
                status
                __typename
              }
              __typename
            }
          }
          __typename
        }
        __typename
      }
      __typename
    }
    pageInfo {
      hasNextPage
      endCursor
      __typename
    }
    __typename
  }
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
    retentionLockMode
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
    retentionLockMode
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
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.activeDirectoryDomainControllers.edges.node
# Getting all results from activeDirectoryDomains
While ($RSCResponse.data.activeDirectoryDomainControllers.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.activeDirectoryDomainControllers.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.activeDirectoryDomainControllers.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCADDomainControllers = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($DC in $RSCList)
{
# Setting variables
$DCName = $DC.name
$DCID = $DC.id
$DCLocation = $Dc.dcLocation
$ADDomain = $DC.activeDirectoryDomain.name
$ADDomainID = $DC.activeDirectoryDomain.id
$DCFSMORoles = $DC.fsmoRoles
$Snapshots = $DC.snapshotConnection.count
$Replicas = $DC.replicatedObjectCount
$SLADomain = $DC.effectiveSlaDomain.name
$SLADomainID = $DC.effectiveSlaDomain.id
$SLADomainRetentionLocked = $DC.effectiveSlaDomain.isRetentionLockedSla
$SLADomainAssignment = $DC.slaAssignment
$SLADomainPauseStatus = $DC.slaPauseStatus
$RubrikCluster = $DC.cluster.name
$RubrikClusterID = $DC.cluster.id
$RBSStatus = $DC.rbsStatus.connectivity
# Getting object URL
$ObjectURL = Get-RSCObjectURL -ObjectType "ADDomainController" -ObjectID $DCID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "DomainController" -Value $DCName
$Object | Add-Member -MemberType NoteProperty -Name "DomainControllerID" -Value $DCID
$Object | Add-Member -MemberType NoteProperty -Name "DomainLocation" -Value $DCLocation
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $RBSStatus
$Object | Add-Member -MemberType NoteProperty -Name "FSMORoles" -Value $DCFSMORoles
$Object | Add-Member -MemberType NoteProperty -Name "Snapshots" -Value $Snapshots
$Object | Add-Member -MemberType NoteProperty -Name "Replicas" -Value $Replicas
$Object | Add-Member -MemberType NoteProperty -Name "ADDomain" -Value $ADDomain
$Object | Add-Member -MemberType NoteProperty -Name "ADDomainID" -Value $ADDomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Assignment" -Value $SLADomainAssignment
$Object | Add-Member -MemberType NoteProperty -Name "RetentionLocked" -Value $SLADomainRetentionLocked
$Object | Add-Member -MemberType NoteProperty -Name "PauseStatus" -Value $SLADomainPauseStatus
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCADDomainControllers.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCADDomainControllers
# End of function
}