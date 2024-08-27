Welcome to the Rubrik Security Cloud (RSC) PowerShell Module For Reporting. To get started install the PowerShell module from the PowerShell gallary using:

```Install-Module RSCReporting```

Import the module into your current session:

```Import-Module RSCReporting```

The current build is: 

```1.0.6```

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

1.0.5 Changelist:

```
1. Removed the following columns from the RSCObjectStorageUsage Table to speed up collection (was using Get-RSCObjects for these causing massive overheads):

	[TotalSnapshots] [int] NULL,
	[ProtectedOn] [datetime] NULL,
	[LastSnapshot] [datetime] NULL,
	[PendingFirstFull] [varchar](50) NULL

2. Added new write to SQL function to map all objects to SLA domains, also, the above 4 columns will now be in the object table vs object storage usage table:

Write-RSCObjects

3. Fixed bugs in the following functions:

Write-RSCTagAssignments (forcing dates as tag to strings to stop newer powershell versions treating it as a date object)
Get-RSCSSOGroups (was throwing an error on efffective permissions graphql call on some RSC instances, was unused anyway so removed)
Get-RSCSSOGroupUsers (as above)
Get-RSCSSOGroupRoleAssignments (as above)
```

