################################################
# Function - Get-RSCEntraIDDomains - Getting All EntraID Domains Protected by RSC
################################################
Function Get-RSCEntraIDDomains {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all protected EntraID Domains.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCEntraIDDomains
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
$RSCGraphQL = @{"operationName" = "AdDirectoriesQuery";

"variables" = @{
"first" = 100
"sortBy" = "NAME"
"sortOrder" = "ASC"
};

"query" = "query AdDirectoriesQuery(`$first: Int, `$after: String, `$sortBy: HierarchySortByField, `$sortOrder: SortOrder) {
  azureAdDirectories(first: `$first, after: `$after, sortBy: `$sortBy, sortOrder: `$sortOrder) {
    edges {
      cursor
      node {
        directoryId
        isProvisioned
        newestSnapshot {
          id
          date
          __typename
        }
        ...NameColumnFragment
        ...EffectiveSlaColumnFragment
        ...SnapshotCountColumnFragment
        __typename
      }
      __typename
    }
    count
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

fragment NameColumnFragment on HierarchyObject {
  id
  name
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

fragment SnapshotCountColumnFragment on PolarisHierarchySnappable {
  snapshotConnection {
    count
    __typename
  }
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.azureAdDirectories.edges.node
# Getting all results from activeDirectoryDomains
While ($RSCResponse.data.azureAdDirectories.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.azureAdDirectories.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.activeDirectoryDomains.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCEntraIDDomains = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Domain in $RSCList)
{
# Setting variables
$ID = $Domain.id
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AzureAdDetailsQuery";

"variables" = @{
"objectId" = $ID
};

"query" = "query AzureAdDetailsQuery(`$objectId: UUID!) {
  azureAdDirectory(workloadFid: `$objectId) {
    id
    region
    name
    domainName
    latestUserCount
    latestGroupCount
    latestRolesCount
    isProvisioned
    effectiveSlaDomain {
      ...EffectiveSlaDomainFragment
      __typename
    }
    authorizedOperations
    ...SnapshotCountColumnFragment
    newestSnapshot {
      id
      isIndexed
      __typename
    }
    __typename
  }
}

fragment SnapshotCountColumnFragment on PolarisHierarchySnappable {
  snapshotConnection {
    count
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
}"
}
# Querying API
$ObjectDetail = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$DomainDetail = $ObjectDetail.data.azureAdDirectory
# Setting variables
$DomainID = $Domain.id
$DomainName = $Domain.name
$SLADomain = $Domain.effectiveSlaDomain.name
$SLADomainID = $Domain.effectiveSlaDomain.id
$SLADomainRetentionLocked = $Domain.effectiveSlaDomain.isRetentionLockedSla
$Users = $DomainDetail.latestGroupCount
$Roles = $DomainDetail.latestRolesCount
$Groups = $DomainDetail.latestGroupCount
$Snapshots = $DomainDetail.snapshotConnection.count
# Snapshot info
$SnapshotDateUNIX = $Domain.newestSnapshot.date
$SnapshotDateID = $Domain.newestSnapshot.id
IF($SnapshotDateUNIX -ne $null){$SnapshotDateUTC = Convert-RSCUNIXTime $SnapshotDateUNIX}ELSE{$SnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($SnapshotDateUTC -ne $null){$SnapshotTimespan = New-TimeSpan -Start $SnapshotDateUTC -End $UTCDateTime;$SnapshotHoursSince = $SnapshotTimespan | Select-Object -ExpandProperty TotalHours;$SnapshotHoursSince = [Math]::Round($SnapshotHoursSince,1)}ELSE{$SnapshotHoursSince = $null}
# Getting object URL
$ObjectURL = Get-RSCObjectURL -ObjectType "EntraIDDomain" -ObjectID $DomainID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Domain" -Value $DomainName
$Object | Add-Member -MemberType NoteProperty -Name "DomainID" -Value $DomainID
$Object | Add-Member -MemberType NoteProperty -Name "Users" -Value $Users
$Object | Add-Member -MemberType NoteProperty -Name "Roles" -Value $Roles
$Object | Add-Member -MemberType NoteProperty -Name "Groups" -Value $Groups
$Object | Add-Member -MemberType NoteProperty -Name "Snapshots" -Value $Snapshots
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTC" -Value $SnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTCAgeHours" -Value $SnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "RetentionLocked" -Value $SLADomainRetentionLocked
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$RSCEntraIDDomains.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCEntraIDDomains
# End of function
}