################################################
# Function - Get-RSCDB2Instances - Getting all DB2 Instances connected to the RSC instance
################################################
Function Get-RSCDB2Instances {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all DB2 instances.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCDB2Instances
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
# Getting SLA domains
$RSCSLADomains = Get-RSCSLADomains
################################################
# Getting Object List 
################################################
# Creating array for objects
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "Db2InstanceListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query Db2InstanceListQuery(`$first: Int!, `$after: String) {
  db2Instances(first: `$first, after: `$after) {
    count
    edges {
      cursor
      node {
        id
        name
        slaPauseStatus
        descendantConnection(
          typeFilter: Db2Database
        ) {
          count
          edges {
            node {
              ... on Db2Database {
                cdmId
                isRelic
                id
                name
                objectType
                db2DbType
              }
            }
          }
          __typename
        }
        physicalChildConnection(typeFilter: PhysicalHost) {
          edges {
            node {
              id
              name
              __typename
            }
            __typename
          }
          __typename
        }
        ...CdmClusterColumnFragment
        ... on HierarchyObject {
          ...EffectiveSlaColumnFragment
          __typename
        }
        ...SlaAssignmentColumnFragment
        lastRefreshTime
        status
        statusMessage
        cdmId
        latestUserNote {
          objectId
          userNote
          userName
          time
        }
        objectType
        numWorkloadDescendants
        physicalPath {
          fid
          name
          objectType
        }
        slaAssignment
        primaryClusterLocation {
          clusterUuid
          name
          id
        }
        containsHadrDatabase
        replicatedObjectCount
        lastSyncTime
        effectiveSlaDomain {
          id
          name
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

fragment SlaAssignmentColumnFragment on HierarchyObject {
  slaAssignment
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
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListResponse.data.db2Instances.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.db2Instances.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.db2Instances.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.db2Instances.edges.node
}
################################################
# Processing Objects
################################################
# Creating array
$RSCDB2Instances = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Instance in $RSCObjectList)
{
# Setting variables
$DBInstance = $Instance.name
$DBInstanceID = $Instance.id
$DBInstanceCDMID = $Instance.cdmId
$DBInstanceType = $Instance.objectType
$DBInstanceDBCount = $Instance.descendantConnection.count
$DBInstanceDBs = $Instance.descendantConnection.edges.node
# SLA info
$DBSLADomainInfo = $Instance.effectiveSlaDomain
$DBSLADomain = $DBSLADomainInfo.name
$DBSLADomainID = $DBSLADomainInfo.id
$DBSLAAssignment = $Instance.slaAssignment
$DBSLAPaused = $Instance.slaPauseStatus
# Rubrik cluster info
$DBRubrikClusterInfo = $Instance.primaryClusterLocation
$DBRubrikCluster = $DBRubrikClusterInfo.name
$DBRubrikClusterID = $DBRubrikClusterInfo.id
# User note info
$DBNoteInfo = $Instance.latestUserNote
$DbNote = $DBNoteInfo.userNote
$DBNoteCreator = $DBNoteInfo.userName
$DBNoteCreatedUNIX = $DBNoteInfo.time
IF($DBNoteCreatedUNIX -ne $null){$DBNoteCreatedUTC = Convert-RSCUNIXTime $DBNoteCreatedUNIX}ELSE{$DBNoteCreatedUTC = $null}
# Location
$DBPhysicalPath = $Instance.physicalChildConnection.edges.node
$DBHostName = $DBPhysicalPath.name
$DBHostID = $DBPhysicalPath.id
# Last refresh
$DBLastRefreshUNIX = $Instance.lastRefreshTime
IF($DBLastRefreshUNIX -ne $null){$DBLastRefreshUTC = Convert-RSCUNIXTime $DBLastRefreshUNIX}ELSE{$DBLastRefreshUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($DBLastRefreshUTC -ne $null){$DBRefreshTimespan = New-TimeSpan -Start $DBLastRefreshUTC -End $UTCDateTime;$DBRefreshHoursSince = $DBRefreshTimespan | Select-Object -ExpandProperty TotalHours;$DBRefreshHoursSince = [Math]::Round($DBRefreshHoursSince,1)}ELSE{$DBRefreshHoursSince = $null}
# Getting URL
$DBInstanceURL = Get-RSCObjectURL -ObjectType "Db2Instance" -ObjectID $DBInstanceID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# DB info
$Object | Add-Member -MemberType NoteProperty -Name "Instance" -Value $DBInstance
$Object | Add-Member -MemberType NoteProperty -Name "InstanceID" -Value $DBInstanceID
$Object | Add-Member -MemberType NoteProperty -Name "InstanceCDMID" -Value $DBInstanceCDMID
$Object | Add-Member -MemberType NoteProperty -Name "InstanceType" -Value $DBInstanceType
$Object | Add-Member -MemberType NoteProperty -Name "DBCount" -Value $DBInstanceDBCount
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $DBSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $DBSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $DBSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $DBSLAPaused
# DB note info
$Object | Add-Member -MemberType NoteProperty -Name "LatestRSCNote" -Value $DBNote
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteCreator" -Value $DBNoteCreator
$Object | Add-Member -MemberType NoteProperty -Name "LatestNoteDateUTC" -Value $DBNoteCreatedUTC
# Rubrik cluster info
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $DBRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $DBRubrikClusterID
# Location information
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $DBHostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $DBHostID
# Refresh timing
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshUTC" -Value $DBLastRefreshUTC
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $DBRefreshHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $DBInstanceURL
# Adding
$RSCDB2Instances.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCDB2Instances
# End of function
}