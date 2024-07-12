################################################
# Function - Get-RSCSAPSystems - Getting all RSC SAP Systems connected to the RSC instance
################################################
Function Get-RSCSAPSystems {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all SAP database hosts (SAP systems).

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSAPSystems
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
$RSCGraphQL = @{"operationName" = "SapHanaSystemListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query SapHanaSystemListQuery(`$after: String, , `$first: Int) {
  sapHanaSystems(after: `$after, first: `$first) {
    edges {
      cursor
      node {
        id
        name
        sid
        instanceNumber
        replicatedObjectCount
        slaPauseStatus
        hosts {
          hostName
          id: hostUuid
          status
          host {
            cdmId
            id
            connectionStatus {
              connectivity
              __typename
            }
            __typename
          }
          __typename
        }
        descendantConnection {
          count
          __typename
        }
        ...EffectiveSlaColumnFragment
        cluster {
          name
          id
          status
          version
          type
          __typename
        }
        status
        sslInfo {
          shouldEncrypt
          keyStorePath
          cryptoLibPath
          trustStorePath
          hostNameInCertificate
          shouldValidateCertificate
          __typename
        }
        statusMessage
        lastRefreshTime
        primaryClusterLocation {
          id
          name
          __typename
        }
        __typename
        cdmId
        effectiveSlaDomain {
          id
          name
        }
        latestUserNote {
          objectId
          time
          userName
          userNote
        }
        numWorkloadDescendants
        objectType
        physicalPath {
          fid
          name
          objectType
        }
        slaAssignment
      }
      __typename
    }
    pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
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
$RSCObjectList += $RSCObjectListResponse.data.sapHanaSystems.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.sapHanaSystems.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.sapHanaSystems.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.sapHanaSystems.edges.node
}
################################################
# Processing Objects
################################################
# Creating array
$RSCSAPSystems = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($System in $RSCObjectList)
{
# Setting variables
$ID = $System.id
$CDMID = $System.cdmId
$Type = $System.objectType
$Name = $System.name
$SID = $System.sid
$Instance = $System.instanceNumber
$Status = $System.status
$Hosts = $System.hosts
$HostCount = $Hosts | Measure-Object | Select-Object -ExpandProperty Count
$DBs = $System.numWorkloadDescendants
$SSLInfo = $System.sslInfo
# SLA info
$SLADomainInfo = $System.effectiveSlaDomain
$SLADomain = $SLADomainInfo.name
$SLADomainID = $SLADomainInfo.id
$SLAAssignment = $System.slaAssignment
$SLAPaused = $System.slaPauseStatus
# Rubrik cluster info
$RubrikCluster = $System.primaryClusterLocation.name
$RubrikClusterID = $System.primaryClusterLocation.id
# Last refresh
$LastRefreshUNIX = $System.lastRefreshTime
IF($LastRefreshUNIX -ne $null){$LastRefreshUTC = Convert-RSCUNIXTime $LastRefreshUNIX}ELSE{$LastRefreshUTC = $null}
# Calculating hours since
$UTCDateTime = [System.DateTime]::UtcNow
IF($LastRefreshUTC -ne $null){$RefreshTimespan = New-TimeSpan -Start $LastRefreshUTC -End $UTCDateTime;$RefreshHoursSince = $RefreshTimespan | Select-Object -ExpandProperty TotalHours;$RefreshHoursSince = [Math]::Round($RefreshHoursSince,1)}ELSE{$RefreshHoursSince = $null}
# Getting URL
$SystemURL = Get-RSCObjectURL -ObjectType "SapHanaSystem" -ObjectID $ID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# DB info
$Object | Add-Member -MemberType NoteProperty -Name "System" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "SystemID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "SystemCDMID" -Value $CDMID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $Type
$Object | Add-Member -MemberType NoteProperty -Name "SID" -Value $SID
$Object | Add-Member -MemberType NoteProperty -Name "Instance" -Value $Instance
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $Status
$Object | Add-Member -MemberType NoteProperty -Name "Hosts" -Value $HostCount
$Object | Add-Member -MemberType NoteProperty -Name "DBs" -Value $DBs
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $SLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $SLAPaused
# Rubrik cluster info
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
# Refresh timing
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshUTC" -Value $LastRefreshUTC
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $RefreshHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "SSLInfo" -Value $SSLInfo
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $SystemURL
# Adding
$RSCSAPSystems.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCSAPSystems
# End of function
}