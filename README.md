Welcome to the Rubrik Security Cloud (RSC) PowerShell Module For Reporting. To get started install the PowerShell module from the PowerShell gallary using:

```Install-Module RSCReporting```

Import the module into your current session:

```Import-Module RSCReporting```

Connect to your RSC instance (recommended to create and use a read only admin role service account):

```Connect-RSCReporting -ScriptDirectory 'C:\Scripts\'```

You'll be prompted for your RSC URL, secret and access key, which are all then encrypted and stored for subsequent runs by repeating the above connection function. Now check out all the functions available with:

```Get-Command -Module RSCReporting```

Following is a list of every command as of the current 1.0.3 build:

```Connect-RSCReporting
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
Get-RSCObjectLastBackup
Get-RSCObjects
Get-RSCObjectSnapshots
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
Get-RSCReplicationTargets
Get-RSCReportTemplates
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
Protect-RSCObject
Register-RSCHost
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
Write-RSCEvents
Write-RSCEventsAllObjects
Write-RSCEventsArchive
Write-RSCEventsAudit
Write-RSCEventsBackup
Write-RSCEventsBackupOnDemand
Write-RSCEventsRecovery
Write-RSCEventsReplication
Write-RSCObjectStorageUsage```
