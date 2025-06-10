Welcome to the Rubrik Security Cloud (RSC) PowerShell Module For Reporting. To get started install the PowerShell module from the PowerShell gallary using:

```Install-Module RSCReporting```

Import the module into your current session:

```Import-Module RSCReporting```

The current build is: 

```1.1.7```

Changes in 1.1.7:

    - Added retention units to Get-RSCSLADomains to discern actual retention of hourly, daily frequencies etc
    - Updated Write-RSCSLADomains to reflect the above, added the following varchar 50 columns: HourlyRetentionUnit, DailyRetentionUnit, WeeklyRetentionUnit, MonthlyRetentionUnit, QuarterlyRetentionUnit, YearlyRetentionUnit
    - Added Search-RSCObject function to find the Object IDs and basic SLA information of an ojbect based on it's name

To see which build you are on:

```Get-Module RSCReporting```

To update to the latest build from the PowerShell gallery use:

```Update-Module -Name RSCReporting```

Connect to your RSC instance (recommended to create and use a read only admin role service account):

```Connect-RSCReporting -ScriptDirectory 'C:\Scripts\'```

You'll be prompted for your RSC URL, ClientID (user) and ClientSecret (password), which are all then encrypted and stored for subsequent runs by repeating the above connection function. Ensure you enter the clientID in the user field without "User|" as this is hard coded (PowerShell won't accept the pipe in a credentials input field). Now check out all the functions available with:

```Get-Command -Module RSCReporting```

Following are some example reports you can send with this SDK:

```
# Email a list of RSC Users
$RSCUsers = Get-RSCUsers | Select UserName,Email,Domain,TOTPEnabled,TOTPEnforced,LastLoginUTC,LastLoginHoursSince,Lockout,RoleCount,HasDefaultAdminRole
Send-RSCReport -Array $RSCUsers -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "RSC Users" -SortByColumnName "LastLoginHoursSince" -ColumnOrder "UserName,Email,Domain,TOTPEnabled,TOTPEnforced,LastLoginUTC,LastLoginHoursSince,Lockout,RoleCount,HasDefaultAdminRole"

# Email a list of Local RSC Users
$Array = Get-RSCUsers | Where {$_.Domain -eq "LOCAL"} | Select URL,UserName,Email,Domain,TOTPEnabled,TOTPEnforced,LastLoginUTC,LastLoginHoursSince,Lockout,RoleCount,HasDefaultAdminRole
Send-RSCReport -Array $Array -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "RSC Local Users" -SortByColumnName "LastLoginHoursSince" -ColumnOrder "UserName,Email,Domain,TOTPEnabled,TOTPEnforced,LastLoginUTC,LastLoginHoursSince,Lockout,RoleCount,HasDefaultAdminRole"

# Email a list of IPs in the allow list
$RSCIPAllowlist = Get-RSCIPAllowlist
Send-RSCReport -Array $RSCIPAllowlist -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "RSC IP AllowList" -SortByColumnName "IP" -ColumnOrder "IP,SubnetMask,IPCidrs,Enabled,Mode"

# Email a list of VMware VMs
$VMwareVMs= Get-RSCVMwareVMs
$Array = $VMwareVMs | Where {$_.IsRelic -eq $False} | Select URL,VM,VMvCenter,OSType,RubrikCluster,SLADomain,SLAPaused,Power,ProtectedOn
Send-RSCReport -Array $Array -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "VMware VMs" -SortByColumnName "VM" -ColumnOrder "VM,VMvCenter,OSType,RubrikCluster,SLADomain,SLAPaused,Power,ProtectedOn"

# Email a list of RBS hosts
$Array = Get-RSCHosts | Where {$_.Status -ne "REPLICATED_TARGET"} | Select Host,OS,RubrikCluster,Status,LastConnectedUTC,HoursSince,ProtectableObjects
$Array = $Array | Where {$_.OS -ne ""}
$Array = $Array | Where {$_.Status -ne "DELETED"}
Send-RSCReport -Array $Array -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "RSC Hosts" -SortByColumnName "HoursSince" -ColumnOrder "Host,OS,RubrikCluster,Status,LastConnectedUTC,HoursSince,ProtectableObjects" -SortDescending

#Email a list of MS SQL DBs
$Array = Get-RSCMSSQLDatabases | Where {$_.IsRelic -eq $False} | Select URL,DB,Instance,Host,RubrikCluster,SLADomain,Online,InDag,DAG,HasPermissions
Send-RSCReport -Array $Array -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "MSSQL DBs" -SortByColumnName "DB" -ColumnOrder "DB,Instance,Host,RubrikCluster,SLADomain,Online,InDag,DAG,HasPermissions"
```

List of all functions as of 1.1.2:

```
Connect-RSCReporting
Convert-RSCUNIXTime
Get-RSCADDomainControllers
Get-RSCADDomainDNT
Get-RSCADDomainObjects
Get-RSCADDomains
Get-RSCAHVVMs
Get-RSCAnomalies
Get-RSCArchiveTargets
Get-RSCAWSAccounts
Get-RSCAWSEBSTagAssignments
Get-RSCAWSEBSVolumes
Get-RSCAWSEC2Instances
Get-RSCAWSEC2TagAssignments
Get-RSCAWSRDSDatabases
Get-RSCAWSRDSTagAssignments
Get-RSCAWSS3Buckets
Get-RSCAWSS3BucketTagAssignments
Get-RSCAWSTagAssignments
Get-RSCAzureSQLDBs
Get-RSCAzureSQLDBTagAssignments
Get-RSCAzureStorageAccounts
Get-RSCAzureStorageAccountTagAssignments
Get-RSCAzureSubscriptions
Get-RSCAzureTags
Get-RSCAzureVMs
Get-RSCAzureVMTagAssignments
Get-RSCBackupSuccessRate
Get-RSCCloudAccounts
Get-RSCCloudVMs
Get-RSCClusterDisks
Get-RSCClusterNodes
Get-RSCClusters
Get-RSCClusterSLADomains
Get-RSCDB2Databases
Get-RSCDB2Instances
Get-RSCDoNotProtectObjects
Get-RSCEntraIDDomains
Get-RSCEventObjectTypes
Get-RSCEvents
Get-RSCEventsAllObjects
Get-RSCEventsAnomalies
Get-RSCEventsArchive
Get-RSCEventsAudit
Get-RSCEventsBackup
Get-RSCEventsBackupFailures
Get-RSCEventsBackupOnDemand
Get-RSCEventsHardware
Get-RSCEventsLogBackup
Get-RSCEventsLogBackupOnDemand
Get-RSCEventsRecovery
Get-RSCEventsReplication
Get-RSCEventsRunning
Get-RSCEventTypes
Get-RSCFilesets
Get-RSCFilesetTemplates
Get-RSCGCPInstances
Get-RSCGCPProjects
Get-RSCHostFilesetObjects
Get-RSCHosts
Get-RSCHypervVMs
Get-RSCIPAllowlist
Get-RSCK8SClusters
Get-RSCK8SNamespaces
Get-RSCLegalHoldSnapshots
Get-RSCLiveMounts
Get-RSCM365DoNotProtectObjects
Get-RSCM365Objects
Get-RSCM365ProtectedObjects
Get-RSCM365Subscriptions
Get-RSCM365UnprotectedObjects
Get-RSCManagedVolumes
Get-RSCModuleFiles
Get-RSCMSSQLDatabaseRecoveryPoints
Get-RSCMSSQLDatabases
Get-RSCMSSQLHosts
Get-RSCMSSQLInstances
Get-RSCMSSQLLiveMounts
Get-RSCNewProtectedVMs
Get-RSCObjectCompliance
Get-RSCObjectComplianceAll
Get-RSCObjectDetail
Get-RSCObjectIDs
Get-RSCObjectLastBackup
Get-RSCObjects
Get-RSCObjectSnapshots
Get-RSCObjectsPendingFirstFull
Get-RSCObjectStorageUsage
Get-RSCObjectStorageUsageByOrg
Get-RSCObjectStorageUsageByVMwareTag
Get-RSCObjectSummary
Get-RSCObjectTypes
Get-RSCObjectURL
Get-RSCOracleDatabases
Get-RSCOracleHosts
Get-RSCOraclePDBs
Get-RSCOracleTableSpaces
Get-RSCProtectedObjects
Get-RSCReplicationPairings
Get-RSCReportTemplates
Get-RSCRoleObjects
Get-RSCRoles
Get-RSCSampleYARARules
Get-RSCSAPDatabases
Get-RSCSAPSystems
Get-RSCSensitiveDataFiles
Get-RSCSensitiveDataObjectAnalyzerHits
Get-RSCSensitiveDataObjects
Get-RSCSensitiveDataPolicies
Get-RSCSensitiveDataPolicyAnalyzers
Get-RSCSensitiveDataPolicyObjects
Get-RSCServiceAccounts
Get-RSCSLADomains
Get-RSCSLADomainsLogSettings
Get-RSCSLAManagedVolumes
Get-RSCSSOGroupRoleAssignments
Get-RSCSSOGroups
Get-RSCSSOGroupUsers
Get-RSCSupportAccess
Get-RSCSupportTunnels
Get-RSCThreatHuntMatches
Get-RSCThreatHuntMatchesAll
Get-RSCThreatHuntObjects
Get-RSCThreatHuntResult
Get-RSCThreatHunts
Get-RSCThreatHuntSnapshots
Get-RSCUnprotectedObjects
Get-RSCUserRoleAssignments
Get-RSCUsers
Get-RSCVMs
Get-RSCVMwareClusters
Get-RSCVMwareHosts
Get-RSCVMwareTagAssignments
Get-RSCVMwareTagCategories
Get-RSCVMwareTags
Get-RSCVMwarevCenters
Get-RSCVMwareVMLiveMounts
Get-RSCVMwareVMs
Get-RSCVMwareVMsDetail
Get-RSCWebhooks
Import-RSCReportTemplate
Pause-RSCArchiveTarget
Pause-RSCCluster
Pause-RSCReplicationPair
Pause-RSCReplicationPairsOnTarget
Protect-RSCObject
Register-RSCHost
Resume-RSCArchiveTarget
Resume-RSCCluster
Resume-RSCReplicationPair
Resume-RSCReplicationPairsOnTarget
Save-RSCReport
Save-RSCReport02MultiDayStrikes
Send-RSCEmail
Send-RSCReport
Send-RSCReport01GlobalClusterHealth
Send-RSCReport02MultiDayStrikes
Start-RSCMSSQLLiveMount
Start-RSCMVSnapshot
Start-RSCOnDemandSnapshot
Start-RSCThreatHunt
Start-RSCVMwareVMLiveMount
Stop-RSCMSSQLLiveMount
Stop-RSCMVSnapshot
Stop-RSCVMwareVMLiveMount
Test-RSCConnection
Test-RSCEmail
Test-RSCSQLConnection
Test-RSCSQLModule
Test-RSCSQLTableCreation
Unregister-RSCHost
Wait-RSCObjectJob
Write-RSCAWSTagAssignments
Write-RSCClusterSLADomains
Write-RSCEvents
Write-RSCEventsAllObjects
Write-RSCEventsArchive
Write-RSCEventsAudit
Write-RSCEventsBackup
Write-RSCEventsBackupOnDemand
Write-RSCEventsLogBackup
Write-RSCEventsRecovery
Write-RSCEventsReplication
Write-RSCObjects
Write-RSCObjectStorageUsage
Write-RSCSLADomains
```
