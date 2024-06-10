################################################
# Function - Get-RSCAzureSQLDatabases - Getting all AzureSQLDatabases connected to the RSC instance
################################################
Function Get-RSCAzureSQLDatabases {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all Azure SQL databases in all Azure subscriptions/accounts.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAzureSQLDatabases
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
# Getting All RSCMSSQLDatabases 
################################################
# Creating array for objects
$RSCObjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AzureSqlDatabaseListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query AzureSqlDatabaseListQuery(`$first: Int, `$after: String) {
  azureSqlDatabases(first: `$first, after: `$after) {
    edges {
      cursor
      node {
        id
        name
        ...AzureSqlDbDatabaseNameColumnFragment
        ...AzureSqlDbRedundancyColumnFragment
        ...AzureSqlDbPoolColumnFragment
        ...AzureSqlDbServiceTierColumnFragment
        ...AzureSqlDbSizeColumnFragment
        ...AzureSqlDbSlaDomainColumnFragment
        ...AzureSqlDbServerNameColumnFragment
        ...AzureSqlDbSubscriptionColumnFragment
        ...AzureSqlDbResourceGroupColumnFragment
        ...AzureSqlDbRegionColumnFragment
        ...AzureSqlDbAssignmentColumnFragment
        serviceObjectiveName
        isRelic
        persistentStorage {
          id
          name
          __typename
        }
        backupSetupSpecs {
          isSetupSuccessful
          setupSourceObject {
            fid
            name
            objectType
            __typename
          }
          __typename
        }
        backupSetupStatus
        exocomputeConfigured
        __typename
        azureSqlDatabaseServer {
          id
          name
        }
        backupStorageRedundancy
        databaseName
        effectiveSlaDomain {
          name
          id
        }
        isEligibleForPersistentBackups
        maximumSizeInBytes
        newestIndexedSnapshot {
          id
          date
        }
        newestSnapshot {
          id
          date
        }
        slaAssignment
        serviceTier
        slaPauseStatus
        region
        oldestSnapshot {
          id
          date
        }
        objectType
        tags {
          value
          key
        }
        onDemandSnapshotCount
        logicalPath {
          fid
          name
          objectType
        }
        physicalPath {
          fid
          objectType
          name
        }
        elasticPoolName
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

fragment AzureSqlDbDatabaseNameColumnFragment on AzureSqlDatabaseDb {
  databaseName
  id
  __typename
}

fragment AzureSqlDbRedundancyColumnFragment on AzureSqlDatabaseDb {
  backupStorageRedundancy
  __typename
}

fragment AzureSqlDbPoolColumnFragment on AzureSqlDatabaseDb {
  elasticPoolName
  __typename
}

fragment AzureSqlDbServiceTierColumnFragment on AzureSqlDatabaseDb {
  serviceTier
  __typename
}

fragment AzureSqlDbSizeColumnFragment on AzureSqlDatabaseDb {
  maximumSizeInBytes
  __typename
}

fragment AzureSqlDbServerNameColumnFragment on AzureSqlDatabaseDb {
  azureSqlDatabaseServer {
    serverName
    id
    __typename
  }
  __typename
}

fragment AzureSqlDbSubscriptionColumnFragment on AzureSqlDatabaseDb {
  azureSqlDatabaseServer {
    azureNativeResourceGroup {
      subscription {
        name
        id
        azureSubscriptionNativeId
        azureSubscriptionStatus
        tenantId
        azureCloudType
        __typename
      }
      __typename
    }
    __typename
  }
  __typename
}

fragment AzureSqlDbResourceGroupColumnFragment on AzureSqlDatabaseDb {
  azureSqlDatabaseServer {
    azureNativeResourceGroup {
      id
      name
      subscription {
        id
        __typename
      }
      __typename
    }
    __typename
  }
  __typename
}

fragment AzureSqlDbSlaDomainColumnFragment on AzureSqlDatabaseDb {
  effectiveSlaDomain {
    ...EffectiveSlaDomainFragment
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

fragment AzureSqlDbRegionColumnFragment on AzureSqlDatabaseDb {
  region
  __typename
}

fragment AzureSqlDbAssignmentColumnFragment on AzureSqlDatabaseDb {
  slaAssignment
  effectiveSlaSourceObject {
    fid
    name
    objectType
    __typename
  }
  azureSqlDatabaseServer {
    azureNativeResourceGroup {
      id
      name
      subscription {
        id
        __typename
      }
      __typename
    }
    __typename
  }
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
$RSCObjectList += $RSCObjectListResponse.data.azureSqlDatabases.edges.node
# Getting all results from paginations
While ($RSCObjectListResponse.data.azureSqlDatabases.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCObjectListResponse.data.azureSqlDatabases.pageInfo.endCursor
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectList += $RSCObjectListResponse.data.azureSqlDatabases.edges.node
}
################################################
# Processing DBs
################################################
# Creating array
$RSCDBs = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCDB in $RSCObjectList)
{
# Setting variables
$DBName = $RSCDB.name
$DBID = $RSCDB.id
$DBType = $RSCDB.objectType
$DBBackupStorageRedundancy = $RSCDB.backupStorageRedundancy
$DBRegion = $RSCDB.region
$DBMaxSizeBytes = $RSCDB.maximumSizeInBytes
$DBServiceTier = $RSCDB.serviceTier
$DBIsRelic = $RSCDB.isRelic
$DBSubscription = $RSCDB.effectiveSlaSourceObject.name
$DBSubscriptionID = $RSCDB.effectiveSlaSourceObject.fid
$DBTags = $RSCDB.tags | Select-Object Key,value
# SLA info
$DBSLADomainInfo = $RSCDB.effectiveSlaDomain
$DBSLADomain = $DBSLADomainInfo.name
$DBSLADomainID = $DBSLADomainInfo.id
$DBSLAAssignment = $RSCDB.slaAssignment
$DBSLAPaused = $RSCDB.slaPauseStatus
# DB snapshot info
$DBOnDemandSnapshots = $RSCDB.onDemandSnapshotCount
$DBSnapshotDateUNIX = $RSCDB.newestSnapshot.date
$DBSnapshotDateID = $RSCDB.newestSnapshot.id
$DBOldestSnapshotDateUNIX = $RSCDB.oldestSnapshot.date
$DBOldestSnapshotDateID = $RSCDB.oldestSnapshot.id
# Converting snapshot dates
IF($DBSnapshotDateUNIX -ne $null){$DBSnapshotDateUTC = Convert-RSCUNIXTime $DBSnapshotDateUNIX}ELSE{$DBSnapshotDateUTC = $null}
IF($DBOldestSnapshotDateUNIX -ne $null){$DBOldestSnapshotDateUTC = Convert-RSCUNIXTime $DBOldestSnapshotDateUNIX}ELSE{$DBOldestSnapshotDateUTC = $null}
# Calculating hours since each snapshot
$UTCDateTime = [System.DateTime]::UtcNow
IF($DBSnapshotDateUTC -ne $null){$DBSnapshotTimespan = New-TimeSpan -Start $DBSnapshotDateUTC -End $UTCDateTime;$DBSnapshotHoursSince = $DBSnapshotTimespan | Select-Object -ExpandProperty TotalHours;$DBSnapshotHoursSince = [Math]::Round($DBSnapshotHoursSince,1)}ELSE{$DBSnapshotHoursSince = $null}
IF($DBOldestSnapshotDateUTC -ne $null){$DBOldestSnapshotTimespan = New-TimeSpan -Start $DBOldestSnapshotDateUTC -End $UTCDateTime;$DBOldestSnapshotDaysSince = $DBOldestSnapshotTimespan | Select-Object -ExpandProperty TotalDays;$DBOldestSnapshotDaysSince = [Math]::Round($DBOldestSnapshotDaysSince,1)}ELSE{$DBOldestSnapshotDaysSince = $null}
# Getting URL
$DBURL = Get-RSCObjectURL -ObjectType "AZURE_SQL_DATABASE_DB" -ObjectID $DBID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
# DB info
$Object | Add-Member -MemberType NoteProperty -Name "DB" -Value $DBName
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $DBType
$Object | Add-Member -MemberType NoteProperty -Name "Region" -Value $DBRegion
$Object | Add-Member -MemberType NoteProperty -Name "Redundancy" -Value $DBBackupStorageRedundancy
$Object | Add-Member -MemberType NoteProperty -Name "ServiceTier" -Value $DBServiceTier
$Object | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $DBSubscription
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $DBSubscriptionID
$Object | Add-Member -MemberType NoteProperty -Name "Tags" -Value $DBTags
# Protection
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $DBSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $DBSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $DBSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAPaused" -Value $DBSLAPaused
$Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $DBIsRelic
# Snapshot dates
$Object | Add-Member -MemberType NoteProperty -Name "OnDemandSnapshots" -Value $DBOnDemandSnapshots
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTC" -Value $DBSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "LatestSnapshotUTCAgeHours" -Value $DBSnapshotHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTC" -Value $DBOldestSnapshotDateUTC
$Object | Add-Member -MemberType NoteProperty -Name "OldestSnapshotUTCAgeDays" -Value $DBOldestSnapshotDaysSince
# URL 
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $DBURL
# Adding
$RSCDBs.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCDBs
# End of function
}