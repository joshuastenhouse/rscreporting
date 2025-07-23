################################################
# Function - Get-RSCClusterSLADomains - Getting all legacy Cluster based SLA domains in RSC
################################################
Function Get-RSCClusterSLADomains {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returns a list of all cluster SLA domains configured and their confiuration details.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCClusterSLADomains
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 10/23/2024
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting all clusters
$RSCClusters = Get-RSCClusters
$RSCClustersCount = $RSCClusters | Measure-Object | Select-Object -ExpandProperty Count
$RSCClustersCounter = 0
# Removing nulls
$RSCClusters = $RSCClusters | Where-Object {$_.ClusterID -ne $null}
################################################
# Getting All SLA Domains For Each Cluster
################################################
# Creating array for objects
$RSCSLADomainList = @()
# For each cluster
ForEach ($RSCCluster in $RSCClusters)
{
# Setting variables
$RSCClusterName = $RSCCluster.Cluster
$RSCClusterID = $RSCCluster.ClusterID
# Logging
$RSCClustersCounter++
Write-Host "Processing:$RSCClustersCounter/$RSCClustersCount Cluster:$RSCClusterName"
# Creating GraphQL
$RSCGraphQL = @{"operationName" = "SLAListQuery";

"variables" = @{
"shouldShowPausedClusters" = $true
"filter" = @{
    "field" = "CLUSTER_UUID"
    "text" = "$RSCClusterID"
  }
"sortBy" = "NAME"
"sortOrder" = "ASC"
"shouldShowProtectedObjectCount" = $true
"first" = 500
};


"query" = "query SLAListQuery(`$after: String, `$first: Int, `$filter: [GlobalSlaFilterInput!], `$sortBy: SlaQuerySortByField, `$sortOrder: SortOrder, `$shouldShowProtectedObjectCount: Boolean, `$shouldShowPausedClusters: Boolean = false) {
  slaDomains(after: `$after, first: `$first, filter: `$filter, sortBy: `$sortBy, sortOrder: `$sortOrder, shouldShowProtectedObjectCount: `$shouldShowProtectedObjectCount, shouldShowPausedClusters: `$shouldShowPausedClusters) {
    edges {
      cursor
      node {
        name
        ...AllObjectSpecificConfigsForSLAFragment
        ...SlaAssignedToOrganizationsFragment
        ... on ClusterSlaDomain {
          id: fid
          protectedObjectCount
          cluster {
            id
            name
            __typename
          }
          baseFrequency {
            duration
            unit
            __typename
          }
          archivalSpec {
            archivalLocationId
            archivalLocationName
            archivalLocationType
            frequencies
            threshold
            thresholdUnit
            threshold
            archivalTieringSpec {
              coldStorageClass
              isInstantTieringEnabled
              minAccessibleDurationInSeconds
              shouldTierExistingSnapshots
            }
          }
          replicationSpecsV2 {
            ...DetailedReplicationSpecsV2ForSlaDomainFragment
            __typename
          }
          localRetentionLimit {
            duration
            unit
            __typename
          }
          snapshotSchedule {
            ...SnapshotSchedulesForSlaDomainFragment
            __typename
          }
          isRetentionLockedSla
          retentionLockMode
          isReadOnly
          name
          version
          upgradeInfo {
            eligibility {
              ineligibilityReason
              isEligible
            }
            latestUpgrade {
              status
              taskchainId
              msg
            }
          }
          __typename
        }
        ... on GlobalSlaReply {
          id
          objectTypes
          description
          protectedObjectCount
          version
          baseFrequency {
            duration
            unit
            __typename
          }
          archivalSpecs {
            storageSetting {
              id
              name
              groupType
              targetType
              __typename
            }
            archivalLocationToClusterMapping {
              cluster {
                id
                name
                __typename
              }
              location {
                id
                name
                targetType
                __typename
              }
              __typename
            }
            __typename
          }
          replicationSpecsV2 {
            ...DetailedReplicationSpecsV2ForSlaDomainFragment
            __typename
          }
          localRetentionLimit {
            duration
            unit
            __typename
          }
          snapshotSchedule {
            ...SnapshotSchedulesForSlaDomainFragment
            __typename
          }
          objectTypes
          isRetentionLockedSla
          __typename
        }
        __typename
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

fragment AllObjectSpecificConfigsForSLAFragment on SlaDomain {
  objectSpecificConfigs {
    awsRdsConfig {
      logRetention {
        duration
        unit
        __typename
      }
      __typename
    }
    sapHanaConfig {
      incrementalFrequency {
        duration
        unit
        __typename
      }
      differentialFrequency {
        duration
        unit
        __typename
      }
      logRetention {
        duration
        unit
        __typename
      }
      __typename
    }
    db2Config {
      incrementalFrequency {
        duration
        unit
        __typename
      }
      differentialFrequency {
        duration
        unit
        __typename
      }
      logRetention {
        duration
        unit
        __typename
      }
      __typename
    }
    oracleConfig {
      frequency {
        duration
        unit
        __typename
      }
      logRetention {
        duration
        unit
        __typename
      }
      hostLogRetention {
        duration
        unit
        __typename
      }
      __typename
    }
    mongoConfig {
      logFrequency {
        duration
        unit
        __typename
      }
      logRetention {
        duration
        unit
        __typename
      }
      __typename
    }
    mssqlConfig {
      frequency {
        duration
        unit
        __typename
      }
      logRetention {
        duration
        unit
        __typename
      }
      __typename
    }
    oracleConfig {
      frequency {
        duration
        unit
        __typename
      }
      logRetention {
        duration
        unit
        __typename
      }
      hostLogRetention {
        duration
        unit
        __typename
      }
      __typename
    }
    vmwareVmConfig {
      logRetentionSeconds
      __typename
    }
    azureSqlDatabaseDbConfig {
      logRetentionInDays
      __typename
    }
    azureSqlManagedInstanceDbConfig {
      logRetentionInDays
      __typename
    }
    __typename
  }
  __typename
}

fragment SnapshotSchedulesForSlaDomainFragment on SnapshotSchedule {
  minute {
    basicSchedule {
      frequency
      retention
      retentionUnit
      __typename
    }
    __typename
  }
  hourly {
    basicSchedule {
      frequency
      retention
      retentionUnit
      __typename
    }
    __typename
  }
  daily {
    basicSchedule {
      frequency
      retention
      retentionUnit
      __typename
    }
    __typename
  }
  weekly {
    basicSchedule {
      frequency
      retention
      retentionUnit
      __typename
    }
    dayOfWeek
    __typename
  }
  monthly {
    basicSchedule {
      frequency
      retention
      retentionUnit
      __typename
    }
    dayOfMonth
    __typename
  }
  quarterly {
    basicSchedule {
      frequency
      retention
      retentionUnit
      __typename
    }
    dayOfQuarter
    quarterStartMonth
    __typename
  }
  yearly {
    basicSchedule {
      frequency
      retention
      retentionUnit
      __typename
    }
    dayOfYear
    yearStartMonth
    __typename
  }
  __typename
}

fragment DetailedReplicationSpecsV2ForSlaDomainFragment on ReplicationSpecV2 {
  replicationLocalRetentionDuration {
    duration
    unit
    __typename
  }
  cascadingArchivalSpecs {
    archivalTieringSpec {
      coldStorageClass
      shouldTierExistingSnapshots
      minAccessibleDurationInSeconds
      isInstantTieringEnabled
      __typename
    }
    archivalLocation {
      id
      name
      targetType
      ... on RubrikManagedAwsTarget {
        immutabilitySettings {
          lockDurationDays
          __typename
        }
        __typename
      }
      ... on RubrikManagedAzureTarget {
        immutabilitySettings {
          lockDurationDays
          __typename
        }
        __typename
      }
      ... on CdmManagedAwsTarget {
        immutabilitySettings {
          lockDurationDays
          __typename
        }
        __typename
      }
      ... on CdmManagedAzureTarget {
        immutabilitySettings {
          lockDurationDays
          __typename
        }
        __typename
      }
      ... on RubrikManagedRcsTarget {
        immutabilityPeriodDays
        syncStatus
        tier
        __typename
      }
      __typename
    }
    frequency
    archivalThreshold {
      duration
      unit
      __typename
    }
    __typename
  }
  retentionDuration {
    duration
    unit
    __typename
  }
  cluster {
    id
    name
    version
    __typename
  }
  targetMapping {
    id
    name
    targets {
      id
      name
      cluster {
        id
        name
        __typename
      }
      __typename
    }
    __typename
  }
  awsTarget {
    accountId
    accountName
    region
    __typename
  }
  azureTarget {
    region
    __typename
  }
  __typename
}

fragment SlaAssignedToOrganizationsFragment on SlaDomain {
  ... on GlobalSlaReply {
    allOrgsWithAccess {
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
Try
{
$RSCSLADomainResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCSLADomainList += $RSCSLADomainResponse.data.slaDomains.edges.node
}
Catch
{
$ErrorMessage = $_.ErrorDetails.Message; "ERROR: $ErrorMessage"
}
# Getting all results from paginations
While ($RSCSLADomainResponse.data.slaDomains.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCSLADomainResponse.data.slaDomains.pageInfo.endCursor
$RSCSLADomainResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCSLADomainList += $RSCSLADomainResponse.data.slaDomains.edges.node
}
# End of for each cluster below
}
# End of for each cluster above
#
# Removing nulls
$RSCSLADomainList = $RSCSLADomainList | Where-Object {$_.cluster.name -ne $null}
# Counting all SLA domains
$RSCSLADomainListCount = $RSCSLADomainList | Measure-Object | Select-Object -ExpandProperty Count
# Logging
Write-Host "TotalClusterSLADomains: $RSCSLADomainListCount"
################################################
# Processing RSC Cluster SLA Domains
################################################
# Building array to store SLAs
$RSCSLADomains = [System.Collections.ArrayList]@()
$RSCSLADomainListCounter = 0
# Cycling through each global SLA to get the settings required
ForEach ($GlobalSLA in $RSCSLADomainList)
{
# Logging
$RSCSLADomainListCounter++
Write-Host "ProcessingSLADomain: $RSCSLADomainListCounter/$RSCSLADomainListCount"
# Setting variables
$GlobalSLAID = $GlobalSLA.id
$GlobalSLAName = $GlobalSLA.name
$GlobalSLADesc = $GlobalSLA.description
$GlobalSLAAPIVersion = $GlobalSLA.version
$GlobalSLABaseFrequency = $GlobalSLA.baseFrequency.duration
$GlobalSLABaseUnit = $GlobalSLA.baseFrequency.unit
$GlobalSLAProtectedObjects = $GlobalSLA.protectedObjectCount
$GlobalSLAObjectTypes = $GlobalSLA.objectTypes
$GlobalSLAIsRetentionLocked = $GlobalSLA.isRetentionLockedSla
# Cluster information
$GlobalClusterName = $GlobalSLA.cluster.name
$GlobalClusterID = $GlobalSLA.cluster.id
$GlobalSLAAPIVersion = "V1"
# Clusters
$GlobalSLAClusters = $GlobalSLA.cluster
$GlobalSLAClustersCount = $GlobalSLAClusters | Measure-Object | Select-Object -ExpandProperty Count
# Counting object types
$GlobalSLAObjectTypesCount = $GlobalSLAObjectTypes | Measure-Object | Select-Object -ExpandProperty Count
# Archive settings
$GlobalSLAArchiveSpecs = $GlobalSLA.archivalSpec
$GlobalSLAArchiveName = $GlobalSLAArchiveSpecs.archivalLocationName
$GlobalSLAArchiveTarget = $GlobalSLAArchiveSpecs.archivalLocationType
$GlobalSLAArchiveType = $GlobalSLAArchiveSpecs.archivalLocationType
$GlobalSLAArchiveID = $GlobalSLAArchiveSpecs.archivalLocationId
IF($GlobalSLAArchiveName -eq $null){$GlobalSLAArchiveEnabled = $FALSE}ELSE{$GlobalSLAArchiveEnabled = $TRUE}
# Overriding type
IF($GlobalSLAArchiveTarget -match "AWS"){$GlobalSLAArchiveType = "S3"}
IF($GlobalSLAArchiveTarget -match "Azure"){$GlobalSLAArchiveType = "Blob"}
IF($GlobalSLAArchiveTarget -match "Goole"){$GlobalSLAArchiveType = "GS"}
# Replication settings
$GlobalSLAReplicationSpecs = $GlobalSLA.replicationSpecsV2
$GlobalSLAReplicationRetention = $GlobalSLAReplicationSpecs.retentionDuration
$GlobalSLAReplicationRetentionDuration = $GlobalSLAReplicationRetention.duration
$GlobalSLAReplicationRetentionUnit = $GlobalSLAReplicationRetention.unit
IF($GlobalSLAReplicationRetentionDuration -eq $null){$GlobalSLAReplicationEnabled = $FALSE}ELSE{$GlobalSLAReplicationEnabled = $TRUE}
$GlobalSLATargetCluster = $GlobalSLAReplicationSpecs.cluster.name
$GlobalSLATargetClusterID = $GlobalSLAReplicationSpecs.cluster.id
# Converting frequency to hours
IF ($GlobalSLABaseUnit -eq "HOURS"){$GlobalSLAFrequencyHours = $GlobalSLABaseFrequency}
IF ($GlobalSLABaseUnit -eq "DAYS"){$GlobalSLAFrequencyHours = 24 * $GlobalSLABaseFrequency}
IF ($GlobalSLABaseUnit -eq "WEEKS"){$GlobalSLAFrequencyHours = 168 * $GlobalSLABaseFrequency}
IF ($GlobalSLABaseUnit -eq "MONTHS"){$GlobalSLAFrequencyHours = 730 * $GlobalSLABaseFrequency}
IF ($GlobalSLABaseUnit -eq "QUARTERS"){$GlobalSLAFrequencyHours = 2190 * $GlobalSLABaseFrequency}
IF ($GlobalSLABaseUnit -eq "MONTHS"){$GlobalSLAFrequencyHours = 8760 * $GlobalSLABaseFrequency}
# Local retention settings if configured
$GlobalSLALocalRetentionDuration = $GlobalSLA.localRetentionLimit.duration
$GlobalSLALocalRetentionUnit = $GlobalSLA.localRetentionLimit.unit
# Snapshot schedules
$GlobalSLAMinuteSchedule = $GlobalSLA.snapshotSchedule.minute.basicSchedule
$GlobalSLAHourlySchedule = $GlobalSLA.snapshotSchedule.hourly.basicSchedule
$GlobalSLADailySchedule = $GlobalSLA.snapshotSchedule.daily.basicSchedule
$GlobalSLAWeeklySchedule = $GlobalSLA.snapshotSchedule.weekly.basicSchedule
$GlobalSLAMonthlySchedule = $GlobalSLA.snapshotSchedule.monthly.basicSchedule
$GlobalSLAQuarterlySchedule = $GlobalSLA.snapshotSchedule.quarterly.basicSchedule
$GlobalSLAYearlySchedule = $GlobalSLA.snapshotSchedule.yearly.basicSchedule
# Hourly snapshot retention
IF ($GlobalSLAHourlySchedule -ne $null)
{$GlobalSLAHourlyFrequency = $GlobalSLAHourlySchedule.frequency; $GlobalSLAHourlyRetention = $GlobalSLAHourlySchedule.retention; $GlobalSLAHourlyRetentionUnit = $GlobalSLAHourlySchedule.retentionUnit}
ELSE
{$GlobalSLAHourlyFrequency = 0; $GlobalSLAHourlyRetention = 0; $GlobalSLAHourlyRetentionUnit = $null}
# Daily snapshot retention
IF ($GlobalSLADailySchedule -ne $null)
{$GlobalSLADailyFrequency = $GlobalSLADailySchedule.frequency; $GlobalSLADailyRetention = $GlobalSLADailySchedule.retention; $GlobalSLADailyRetentionUnit = $GlobalSLADailySchedule.retentionUnit}
ELSE
{$GlobalSLADailyFrequency = 0; $GlobalSLADailyRetention = 0; $GlobalSLADailyRetentionUnit = $null}
# Weekly snapshot retention
IF ($GlobalSLAWeeklySchedule -ne $null)
{$GlobalSLAWeeklyFrequency = $GlobalSLAWeeklySchedule.frequency; $GlobalSLAWeeklyRetention = $GlobalSLAWeeklySchedule.retention; $GlobalSLAWeeklyRetentionUnit = $GlobalSLAWeeklySchedule.retentionUnit}
ELSE
{$GlobalSLAWeeklyFrequency = 0; $GlobalSLAWeeklyRetention = 0; $GlobalSLAWeeklyRetentionUnit = $null}
# Monthly snapshot retention
IF ($GlobalSLAMonthlySchedule -ne $null)
{$GlobalSLAMonthlyFrequency = $GlobalSLAMonthlySchedule.frequency; $GlobalSLAMonthlyRetention = $GlobalSLAMonthlySchedule.retention; $GlobalSLAMonthlyRetentionUnit = $GlobalSLAMonthlySchedule.retentionUnit}
ELSE
{$GlobalSLAMonthlyFrequency = 0; $GlobalSLAMonthlyRetention = 0; $GlobalSLAMonthlyRetentionUnit = $null}
# Quarterly snapshot retention
IF ($GlobalSLAQuarterlySchedule -ne $null)
{$GlobalSLAQuarterlyFrequency = $GlobalSLAQuarterlySchedule.frequency; $GlobalSLAQuarterlyRetention = $GlobalSLAQuarterlySchedule.retention; $GlobalSLAQuarterlyRetentionUnit = $GlobalSLAQuarterlySchedule.retentionUnit}
ELSE
{$GlobalSLAQuarterlyFrequency = 0; $GlobalSLAQuarterlyRetention = 0; $GlobalSLAQuarterlyRetentionUnit = $null}
# Yearly snapshot retention
IF ($GlobalSLAYearlySchedule -ne $null)
{$GlobalSLAYearlyFrequency = $GlobalSLAYearlySchedule.frequency; $GlobalSLAYearlyRetention = $GlobalSLAYearlySchedule.retention; $GlobalSLAYearlyRetentionUnit = $GlobalSLAYearlySchedule.retentionUnit}
ELSE
{$GlobalSLAYearlyFrequency = 0; $GlobalSLAYearlyRetention = 0; $GlobalSLAYearlyRetentionUnit = $null}
# Calculating frequeny per day irrespective of config
IF($GlobalSLAFrequencyHours -gt 0){$GlobalSLAFrequencyDays = 24 / $GlobalSLAFrequencyHours; $GlobalSLAFrequencyDays = [Math]::Round($GlobalSLAFrequencyDays)}ELSE{$GlobalSLAFrequencyDays = 0}
# Overriding to ensure max 1 backup per day even if multiple, for SLA compliance calcs
IF($GlobalSLAFrequencyDays -gt 1){$GlobalSLAFrequencyDays = 1}
# Handling object specific configs
$GlobalSLAObjectConfigs = $GlobalSLA.objectSpecificConfigs
# VM config
$VMConfig = $GlobalSLAObjectConfigs.vmwareVmConfig
IF($VMConfig -ne $null){$VMConfigured = $TRUE}ELSE{$VMConfigured = $FALSE}
$VMConfigJournalSeconds = $VMConfig.logRetentionSeconds
$VMConfigJournalHours = $VMConfigJournalSeconds / 3600; $VMConfigJournalHours = [Math]::Round($VMConfigJournalHours)
# MSSQL config
$MSSQLConfig = $GlobalSLAObjectConfigs.mssqlConfig
IF($MSSQLConfig -ne $null){$MSSQLConfigured = $TRUE}ELSE{$MSSQLConfigured = $FALSE}
$MSSQLLogFrequency = $MSSQLConfig.frequency
$MSSQLLogFrequencyDuration = $MSSQLLogFrequency.duration
$MSSQLLogFrequencyUnit = $MSSQLLogFrequency.unit
$MSSQLLogRetention = $MSSQLConfig.logRetention
$MSSQLLogRetentionDuration = $MSSQLLogRetention.duration
$MSSQLLogRetentionUnit = $MSSQLLogRetention.unit
# Converting log retention to days if minutes equal or greater than 1 day
IF(($MSSQLLogRetentionUnit -eq "MINUTES") -and ($MSSQLLogRetentionDuration -ge 1440))
{
$MSSQLLogRetentionDuration = $MSSQLLogRetentionDuration / 1440; $MSSQLLogRetentionDuration = [Math]::Round($MSSQLLogRetentionDuration)
$MSSQLLogRetentionUnit = "DAYS"
}
# Oracle config
$OracleConfig = $GlobalSLAObjectConfigs.oracleConfig
IF($OracleConfig -ne $null){$OracleConfigured = $TRUE}ELSE{$OracleConfigured = $FALSE}
$OracleLogFrequency = $OracleConfig.frequency
$OracleLogFrequencyDuration = $OracleLogFrequency.duration
$OracleLogFrequencyUnit = $OracleLogFrequency.unit
$OracleLogRetention = $OracleConfig.logRetention
$OracleLogRetentionDuration = $OracleLogRetention.duration
$OracleLogRetentionUnit = $OracleLogRetention.unit
# Converting log retention to days if minutes equal or greater than 1 day
IF(($OracleLogRetentionUnit -eq "MINUTES") -and ($OracleLogRetentionDuration -ge 1440))
{
$OracleLogRetentionDuration = $OracleLogRetentionDuration / 1440; $OracleLogRetentionDuration = [Math]::Round($OracleLogRetentionDuration)
$OracleLogRetentionUnit = "DAYS"
}
# Getting URL
$SLADomainURL = Get-RSCObjectURL -ObjectType "SlaDomain" -ObjectID $GlobalSLAID
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $GlobalSLAName
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $GlobalSLAID
# Cluster info
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $GlobalClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $GlobalClusterID
# SLA info
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedObjects" -Value $GlobalSLAProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "RetentionLocked" -Value $GlobalSLAIsRetentionLocked
$Object | Add-Member -MemberType NoteProperty -Name "APIVersion" -Value $GlobalSLAAPIVersion
# Archiving
$Object | Add-Member -MemberType NoteProperty -Name "Archive" -Value $GlobalSLAArchiveEnabled
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveTarget" -Value $GlobalSLAArchiveTarget
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveName" -Value $GlobalSLAArchiveName
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveType" -Value $GlobalSLAArchiveType
$Object | Add-Member -MemberType NoteProperty -Name "ArchiveID" -Value $GlobalSLAArchiveID
# Replication
$Object | Add-Member -MemberType NoteProperty -Name "Replication" -Value $GlobalSLAReplicationEnabled
$Object | Add-Member -MemberType NoteProperty -Name "ReplicationDuration" -Value $GlobalSLAReplicationRetentionDuration
$Object | Add-Member -MemberType NoteProperty -Name "ReplicationUnit" -Value $GlobalSLAReplicationRetentionUnit
# Replication target info
$Object | Add-Member -MemberType NoteProperty -Name "ReplicationTargetCluster" -Value $GlobalSLATargetCluster
$Object | Add-Member -MemberType NoteProperty -Name "ReplicationTargetClusterID" -Value $GlobalSLATargetClusterID
# Local retention
$Object | Add-Member -MemberType NoteProperty -Name "LocalRetention" -Value $GlobalSLALocalRetentionDuration
$Object | Add-Member -MemberType NoteProperty -Name "LocalRetentionUnit" -Value $GlobalSLALocalRetentionUnit
# Frequencies & Retention
$Object | Add-Member -MemberType NoteProperty -Name "Frequency" -Value $GlobalSLABaseFrequency
$Object | Add-Member -MemberType NoteProperty -Name "FrequnecyUnit" -Value $GlobalSLABaseUnit
$Object | Add-Member -MemberType NoteProperty -Name "FrequencyHours" -Value $GlobalSLAFrequencyHours
$Object | Add-Member -MemberType NoteProperty -Name "FrequencyDays" -Value $GlobalSLAFrequencyDays
$Object | Add-Member -MemberType NoteProperty -Name "HourlyFrequency" -Value $GlobalSLAHourlyFrequency
$Object | Add-Member -MemberType NoteProperty -Name "HourlyRetention" -Value $GlobalSLAHourlyRetention
$Object | Add-Member -MemberType NoteProperty -Name "HourlyRetentionUnit" -Value $GlobalSLAHourlyRetentionUnit
$Object | Add-Member -MemberType NoteProperty -Name "DailyFrequency" -Value $GlobalSLADailyFrequency
$Object | Add-Member -MemberType NoteProperty -Name "DailyRetention" -Value $GlobalSLADailyRetention
$Object | Add-Member -MemberType NoteProperty -Name "DailyRetentionUnit" -Value $GlobalSLADailyRetentionUnit
$Object | Add-Member -MemberType NoteProperty -Name "WeeklyFrequency" -Value $GlobalSLAWeeklyFrequency
$Object | Add-Member -MemberType NoteProperty -Name "WeeklyRetention" -Value $GlobalSLAWeeklyRetention
$Object | Add-Member -MemberType NoteProperty -Name "WeeklyRetentionUnit" -Value $GlobalSLAWeeklyRetentionUnit
$Object | Add-Member -MemberType NoteProperty -Name "MonthlyFrequency" -Value $GlobalSLAMonthlyFrequency
$Object | Add-Member -MemberType NoteProperty -Name "MonthlyRetention" -Value $GlobalSLAMonthlyRetention
$Object | Add-Member -MemberType NoteProperty -Name "MonthlyRetentionUnit" -Value $GlobalSLAMonthlyRetentionUnit
$Object | Add-Member -MemberType NoteProperty -Name "QuarterlyFrequency" -Value $GlobalSLAQuarterlyFrequency
$Object | Add-Member -MemberType NoteProperty -Name "QuarterlyRetention" -Value $GlobalSLAQuarterlyRetention
$Object | Add-Member -MemberType NoteProperty -Name "QuarterlyRetentionUnit" -Value $GlobalSLAQuarterlyRetentionUnit
$Object | Add-Member -MemberType NoteProperty -Name "YearlyFrequency" -Value $GlobalSLAYearlyFrequency
$Object | Add-Member -MemberType NoteProperty -Name "YearlyRetention" -Value $GlobalSLAYearlyRetention
$Object | Add-Member -MemberType NoteProperty -Name "YearlyRetentionUnit" -Value $GlobalSLAYearlyRetentionUnit
# VM specific SLA configrations
$Object | Add-Member -MemberType NoteProperty -Name "VMJournalConfigured" -Value $VMConfigured
$Object | Add-Member -MemberType NoteProperty -Name "VMJournalRetention" -Value $VMConfigJournalHours
$Object | Add-Member -MemberType NoteProperty -Name "VMJournalRetentionUnit" -Value "Hours"
# MSSQL specific SLA configurations
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLConfigured" -Value $MSSQLConfigured
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLLogFrequency" -Value $MSSQLLogFrequencyDuration
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLLogFrequencyUnit" -Value $MSSQLLogFrequencyUnit
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLLogRetention" -Value $MSSQLLogRetentionDuration
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLLogRetentionUnit" -Value $MSSQLLogRetentionUnit
# Oracle specific SLA configurations
$Object | Add-Member -MemberType NoteProperty -Name "OracleConfigured" -Value $OracleConfigured
$Object | Add-Member -MemberType NoteProperty -Name "OracleLogFrequency" -Value $OracleLogFrequencyDuration
$Object | Add-Member -MemberType NoteProperty -Name "OracleLogFrequencyUnit" -Value $OracleLogFrequencyUnit
$Object | Add-Member -MemberType NoteProperty -Name "OracleLogRetention" -Value $OracleLogRetentionDuration
$Object | Add-Member -MemberType NoteProperty -Name "OracleLogRetentionUnit" -Value $OracleLogRetentionUnit
# URL
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $SLADomainURL
# Adding to array
$RSCSLADomains.Add($Object) | Out-Null
# End of for each SLA below
}
# End of for each SLA above
# Removing nulls
$RSCSLADomains = $RSCSLADomains | Where-Object {$_.RubrikClusterID -ne $null}
# Returning array
Return $RSCSLADomains
# End of function
}