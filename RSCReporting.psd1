@{
	RootModule 		= 'RSCReporting.psm1' 
	ModuleVersion 		= '1.0.7' 
	CompatiblePSEditions 	= 'Desktop', 'Core' 
	GUID 			= 'dc18a919-f4bf-4da2-8c76-24b68fa33ef0' 
	Author 			= 'Joshua Stenhouse' 
	CompanyName 		= 'Rubrik Inc' 
	Copyright 		= '(c) Rubrik. All rights reserved.' 
	Description 		= 'A module for reporting on your Rubrik Security Cloud instance'
	PowerShellVersion 	= '5.1'

FunctionsToExport = @(
"Connect-RSCReporting",
"Convert-RSCUNIXTime",
"Get-RSCADDomainControllers",
"Get-RSCADDomainDNT",
"Get-RSCADDomainObjects",
"Get-RSCADDomains",
"Get-RSCAHVVMs",
"Get-RSCAnomalies",
"Get-RSCArchiveTargets",
"Get-RSCAWSAccounts",
"Get-RSCAWSEBSTagAssignments",
"Get-RSCAWSEBSVolumes",
"Get-RSCAWSEC2Instances",
"Get-RSCAWSEC2TagAssignments",
"Get-RSCAWSRDSDatabases",
"Get-RSCAWSRDSTagAssignments",
"Get-RSCAWSS3Buckets",
"Get-RSCAWSS3BucketTagAssignments",
"Get-RSCAWSTagAssignments",
"Get-RSCAzureSQLDBs",
"Get-RSCAzureSQLDBTagAssignments",
"Get-RSCAzureStorageAccounts",
"Get-RSCAzureStorageAccountTagAssignments",
"Get-RSCAzureSubscriptions",
"Get-RSCAzureTags",
"Get-RSCAzureVMs",
"Get-RSCAzureVMTagAssignments",
"Get-RSCBackupSuccessRate",
"Get-RSCCloudAccounts",
"Get-RSCCloudVMs",
"Get-RSCClusterDisks",
"Get-RSCClusterNodes",
"Get-RSCClusters",
"Get-RSCDB2Databases",
"Get-RSCDB2Instances",
"Get-RSCDoNotProtectObjects",
"Get-RSCEntraIDDomains",
"Get-RSCEventObjectTypes",
"Get-RSCEvents",
"Get-RSCEventsAllObjects",
"Get-RSCEventsAnomalies",
"Get-RSCEventsArchive",
"Get-RSCEventsAudit",
"Get-RSCEventsBackup",
"Get-RSCEventsBackupFailures",
"Get-RSCEventsBackupOnDemand",
"Get-RSCEventsHardware",
"Get-RSCEventsLogBackup",
"Get-RSCEventsLogBackupOnDemand",
"Get-RSCEventsRecovery",
"Get-RSCEventsReplication",
"Get-RSCEventsRunning",
"Get-RSCEventTypes",
"Get-RSCFilesets",
"Get-RSCFilesetTemplates",
"Get-RSCGCPInstances",
"Get-RSCGCPProjects",
"Get-RSCHostFilesetObjects",
"Get-RSCHosts",
"Get-RSCHypervVMs",
"Get-RSCIPAllowlist",
"Get-RSCK8SClusters",
"Get-RSCK8SNamespaces",
"Get-RSCLegalHoldSnapshots",
"Get-RSCLiveMounts",
"Get-RSCM365DoNotProtectObjects",
"Get-RSCM365Objects",
"Get-RSCM365ProtectedObjects",
"Get-RSCM365Subscriptions",
"Get-RSCM365UnprotectedObjects",
"Get-RSCManagedVolumes",
"Get-RSCModuleFiles",
"Get-RSCMSSQLDatabaseRecoveryPoints",
"Get-RSCMSSQLDatabases",
"Get-RSCMSSQLHosts",
"Get-RSCMSSQLInstances",
"Get-RSCMSSQLLiveMounts",
"Get-RSCNewProtectedVMs",
"Get-RSCObjectCompliance",
"Get-RSCObjectComplianceAll",
"Get-RSCObjectDetail",
"Get-RSCObjectIDs",
"Get-RSCObjectLastBackup",
"Get-RSCObjects",
"Get-RSCObjectSnapshots",
"Get-RSCObjectsPendingFirstFull",
"Get-RSCObjectStorageUsage",
"Get-RSCObjectStorageUsageByOrg",
"Get-RSCObjectStorageUsageByVMwareTag",
"Get-RSCObjectSummary",
"Get-RSCObjectTypes",
"Get-RSCObjectURL",
"Get-RSCOracleDatabases",
"Get-RSCOracleHosts",
"Get-RSCOraclePDBs",
"Get-RSCOracleTableSpaces",
"Get-RSCProtectedObjects",
"Get-RSCReplicationTargets",
"Get-RSCReportTemplates",
"Get-RSCRoleObjects",
"Get-RSCRoles",
"Get-RSCSampleYARARules",
"Get-RSCSAPDatabases",
"Get-RSCSAPSystems",
"Get-RSCSensitiveDataFiles",
"Get-RSCSensitiveDataObjectAnalyzerHits",
"Get-RSCSensitiveDataObjects",
"Get-RSCSensitiveDataPolicies",
"Get-RSCSensitiveDataPolicyAnalyzers",
"Get-RSCSensitiveDataPolicyObjects",
"Get-RSCServiceAccounts",
"Get-RSCSLADomains",
"Get-RSCSLADomainsLogSettings",
"Get-RSCSLAManagedVolumes",
"Get-RSCSSOGroupRoleAssignments",
"Get-RSCSSOGroups",
"Get-RSCSSOGroupUsers",
"Get-RSCSupportAccess",
"Get-RSCSupportTunnels",
"Get-RSCThreatHuntMatches",
"Get-RSCThreatHuntMatchesAll",
"Get-RSCThreatHuntObjects",
"Get-RSCThreatHuntResult",
"Get-RSCThreatHunts",
"Get-RSCThreatHuntSnapshots",
"Get-RSCUnprotectedObjects",
"Get-RSCUserRoleAssignments",
"Get-RSCUsers",
"Get-RSCVMs",
"Get-RSCVMwareClusters",
"Get-RSCVMwareHosts",
"Get-RSCVMwareTagAssignments",
"Get-RSCVMwareTagCategories",
"Get-RSCVMwareTags",
"Get-RSCVMwarevCenters",
"Get-RSCVMwareVMLiveMounts",
"Get-RSCVMwareVMs",
"Get-RSCVMwareVMsDetail",
"Get-RSCWebhooks",
"Import-RSCReportTemplate",
"Protect-RSCObject",
"Register-RSCHost",
"Save-RSCReport",
"Save-RSCReport02MultiDayStrikes",
"Send-RSCEmail",
"Send-RSCReport",
"Send-RSCReport01GlobalClusterHealth",
"Send-RSCReport02MultiDayStrikes",
"Start-RSCMSSQLLiveMount",
"Start-RSCMVSnapshot",
"Start-RSCOnDemandSnapshot",
"Start-RSCThreatHunt",
"Start-RSCVMwareVMLiveMount",
"Stop-RSCMSSQLLiveMount",
"Stop-RSCMVSnapshot",
"Stop-RSCVMwareVMLiveMount",
"Test-RSCConnection",
"Test-RSCEmail",
"Test-RSCSQLConnection",
"Test-RSCSQLModule",
"Test-RSCSQLTableCreation",
"Unregister-RSCHost",
"Wait-RSCObjectJob",
"Write-RSCAWSTagAssignments",
"Write-RSCEvents",
"Write-RSCEventsAllObjects",
"Write-RSCEventsArchive",
"Write-RSCEventsAudit",
"Write-RSCEventsBackup",
"Write-RSCEventsBackupOnDemand",
"Write-RSCEventsRecovery",
"Write-RSCEventsReplication",
"Write-RSCObjects",
"Write-RSCObjectStorageUsage",
"Write-RSCSLADomains"
)
	FileList = @(
"Reports\00-RSCReport.html",
"Reports\01-GlobalClusterHealth.html",
"Reports\02-MultiDayStrikes.html",
"Scripts\RSCWelcomeMessage.ps1"
)
	CmdletsToExport 	= @() 
	VariablesToExport 	= @() 
	AliasesToExport 	= @() 
	PrivateData 		= @{
		PSData 			= @{
			Tags = "Rubrik"
			ProjectUri = "https://github.com/joshuastenhouse/rscreporting"
			IconUri = ""
			LicenseURI = 'https://github.com/joshuastenhouse/rscreporting?tab=GPL-3.0-1-ov-file' 
} 
	} 
}