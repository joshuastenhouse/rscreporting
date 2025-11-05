################################################
# Creating the Get-RSCObjectURL function
################################################
Function Get-RSCObjectURL {
	
<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that creates URLs for object management in RSC itself.

.DESCRIPTION
Translates the ObjectType and ObjectID specified into a URL that can be used to manage the object via the UI (useful for reporting).

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
A valid object ID in RSC, use Get-RSCObjects to obtain.
.PARAMETER ObjectType
A valid object type in RSC, use Get-RSCObjectTypes to obtain.

.OUTPUTS
Returns a valid URL of the object ID specified, if no matching type just links to RSC so never returns null.

.EXAMPLE
Get-RSCObjectURL -ObjectID "334w34-23423423-234234-234234" -ObjectType "VmwareVirtualMachine"
This example returns a URL for the VmwareVirtualMachine ID specified.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
Param ($ObjectType,$ObjectID)

# Example: $ObjectURL = Get-RSCObjectURL -ObjectType "$ObjectType" -ObjectID "$ObjectID"

$RSCObjectURL = $null

# Cluster
# https://rubrik-gaia.my.rubrik.com/clusters/be8cb1b6-c0d6-43d9-af09-950e26cf6e4a/overview
IF ($ObjectType -eq "Cluster"){$RSCObjectURL = $RSCURL + "/clusters/" + $ObjectID + "/overview"}

# SLA domain
# https://rubrik-gaia.my.rubrik.com/sla/details/41450dc4-1021-448e-9861-efe6a7699624
IF ($ObjectType -eq "SLADomain"){$RSCObjectURL = $RSCURL + "/sla/details/" + $ObjectID}

# VMware VM
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/vsphere/144c6e1d-a060-5305-a5d6-81d8d8e6edca/overview
IF ($ObjectType -eq "VmwareVirtualMachine"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/vsphere/" + $ObjectID + "/overview"}

# vCenter Tag Categories
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/vsphere/tags/vcenter/f6ba8d25-ccea-579f-b1ac-f3aabda76683
IF ($ObjectType -eq "vCenterTagCategories"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/vsphere/tags/vcenter/" + $ObjectID}

# vCenters
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/vsphere/folders/vcenter/4d06815d-07f9-5465-80a5-18c8149cd2d2
IF ($ObjectType -eq "vCenter"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/vsphere/folders/vcenter/" + $ObjectID}

# vCenter hosts
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/vsphere/hosts/host/46a14e78-b580-5091-b808-0fbb6c0ddb63
IF ($ObjectType -eq "vCenterHost"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/vsphere/hosts/host/" + $ObjectID}

# vCenter Clusters
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/vsphere/hosts/computecluster/e90741cc-4360-54b8-9ad3-84db4727c62e
IF ($ObjectType -eq "vCenterCluster"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/vsphere/hosts/computecluster/" + $ObjectID}

# Nutanix AHV
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/nutanix/VMS/2da128a0-a65c-50d0-9b3f-5dac778d1014/overview
IF ($ObjectType -eq "NutanixVirtualMachine"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/nutanix/VMS/" + $ObjectID + "/overview"}

# HyperV VM
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/hyperV/vms/c2b7064b-0ae1-5752-b43b-f886f7a2bc79/overview
IF ($ObjectType -eq "HypervVirtualMachine"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/hyperV/vms/" + $ObjectID + "/overview"}

# 0365 Mailbox
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/o365exchange/4800e551-9b3b-4eed-bf33-d0b502906a8f/overview
IF ($ObjectType -eq "O365Mailbox"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/o365exchange/" + $ObjectID + "/overview"}

# 0365 Onedrive
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/o365Onedrive/b14ac525-24f0-4d40-8402-840ced910fd7/overview
IF ($ObjectType -eq "o365OneDrive"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/o365Onedrive/" + $ObjectID + "/overview"}

# 0365 SharePointDrive
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/o365Sharepoint/3715b31b-885c-4b85-8a4e-0fafe200f2a0/overview
IF ($ObjectType -eq "O365SharePointDrive"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/o365Sharepoint/" + $ObjectID + "/overview"}

# 0365 O365SharePointList
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/O365SharepointList/3715b31b-885c-4b85-8a4e-0fafe200f2a0/overview
IF ($ObjectType -eq "O365SharePointList"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/O365SharepointList/" + $ObjectID + "/overview"}

# 0365 O365SharePointSitePages
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/m365SharepointSiteCollection/7cda68be-4525-4e5c-a39b-ce2a70f1a3cf/overview
IF ($ObjectType -eq "Site Pages"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/m365SharepointSiteCollection/" + $ObjectID + "/overview"}

# 0365 Teams
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/o365Teams/91db54d1-af05-4848-9549-84b780dedc9a/overview
IF ($ObjectType -eq "o365Teams"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/o365Teams/" + $ObjectID + "/overview"}

# 0365 User
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/o365exchange/420eb055-e898-4896-92ce-5cd562c34783/overview
IF ($ObjectType -eq "O365User"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/o365exchange/" + $ObjectID + "/overview"}

# 0365 Calendar
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/o365exchange/420eb055-e898-4896-92ce-5cd562c34783/overview
IF ($ObjectType -eq "O365Calendar"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/o365exchange/" + $ObjectID + "/overview"}

# AWS awsNativeEc2Instance
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/awsNativeEc2Instance/07e1d738-33f7-48fb-8282-3eb25fadfd8d/overview
IF ($ObjectType -eq "awsNativeEc2Instance"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/awsNativeEc2Instance/" + $ObjectID + "/overview"}

# AWS Ec2Instance
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/awsNativeEc2Instance/07e1d738-33f7-48fb-8282-3eb25fadfd8d/overview
IF ($ObjectType -eq "Ec2Instance"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/awsNativeEc2Instance/" + $ObjectID + "/overview"}

# AWS S3Bucket
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/awsNativeS3Bucket/c6cf0547-5949-4133-82c4-cf370aba5d89/overview
IF ($ObjectType -eq "S3Bucket"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/awsNativeS3Bucket/" + $ObjectID + "/overview"}

# AWS AwsNativeEbsVolume
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/AwsNativeEbsVolume/07e1d738-33f7-48fb-8282-3eb25fadfd8d/overview
IF ($ObjectType -eq "AwsNativeEbsVolume"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/AwsNativeEbsVolume/" + $ObjectID + "/overview"}

# AWS awsNativeRdsInstance
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/awsNativeRdsInstance/61e86f05-31af-48a9-ae02-a39bb1ff0b3c/overview
IF ($ObjectType -eq "awsNativeRdsInstance"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/awsNativeRdsInstance/" + $ObjectID + "/overview"}

# AWS EC2 and EBS account view
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/aws/EC2/account/ac0b7687-291e-459f-84aa-901f0777ab1f
IF ($ObjectType -eq "awsEC2account"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/aws/EC2/account/" + $ObjectID}

# AWS RDS account view
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/aws/RDS/account/f8d22d77-8d23-4be3-bdc7-3a31774bdd2d
IF ($ObjectType -eq "awsRDSaccount"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/aws/RDS/account/" + $ObjectID}

# Azure AzureNativeVm
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/AzureNativeVm/0f052c97-0ceb-41e3-ac6f-4c663b5735b4/overview
IF ($ObjectType -eq "AzureNativeVm"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/AzureNativeVm/" + $ObjectID + "/overview"}

# Azure AzureNativeManagedDisk
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/AzureNativeVm/0f052c97-0ceb-41e3-ac6f-4c663b5735b4/overview
IF ($ObjectType -eq "AzureNativeManagedDisk"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/AzureNativeManagedDisk/" + $ObjectID + "/overview"}

# Azure SQL database
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/azure_sql/db/databases/04e88f39-5982-4c6e-9cca-f238a3c32446/overview
IF ($ObjectType -eq "AZURE_SQL_DATABASE_DB"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/azure_sql/db/databases/" + $ObjectID + "/overview"}

# Azure VM sub
#https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/azure/subscriptions/46341153-5307-4ee4-8b8b-323880589ad9/virtual_machines
IF ($ObjectType -eq "AzureSubVirtualMachines"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/azure/subscriptions/" + $ObjectID + "/virtual_machines"}
IF ($ObjectType -eq "AzureVirtualMachine"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/azure/subscriptions/" + $ObjectID + "/virtual_machines"}

# Azure SQL sub
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/azure_sql/db/subscriptions/29302ac7-34c3-4691-9da4-175b12dc53cd/databases
IF ($ObjectType -eq "AzureSubSqlDatabases"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/azure_sql/db/subscriptions/" + $ObjectID + "/databases"}
IF ($ObjectType -eq "AzureSqlDatabase"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/azure_sql/db/subscriptions/" + $ObjectID + "/databases"}

# Azure storage account
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/azure/blob/subscriptions/29302ac7-34c3-4691-9da4-175b12dc53cd
IF ($ObjectType -eq "AzureSubStorageAccounts"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/azure/blob/storage_accounts"}
IF ($ObjectType -eq "AzureStorageAccount"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/azure/blob/storage_accounts"}

# GCP gcpNativeGceInstance
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/gcpNativeGceInstance/71fe9073-421c-4892-b96e-a9dffac05f24/overview
IF ($ObjectType -eq "gcpNativeGceInstance"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/gcpNativeGceInstance/" + $ObjectID + "/overview"}

# GCP Project
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/gcp/project/31b683d4-1c5a-43e4-80d0-1805bc31af8c/gce_instances
IF ($ObjectType -eq "gcpProject"){$RSCObjectURL = $RSCURL + "/gcp/project/" + $ObjectID + "/gce_instances"}

# GCP GcpNativeDisk
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/gcpNativeGceInstance/71fe9073-421c-4892-b96e-a9dffac05f24/overview
IF ($ObjectType -eq "GcpNativeDisk"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/gcpNativeGceInstance/" + $ObjectID + "/overview"}

# ShareFileset
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/ShareFileset/71fe9073-421c-4892-b96e-a9dffac05f24/overview
IF ($ObjectType -eq "ShareFileset"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/ShareFileset/" + $ObjectID + "/overview"}

# WindowsFileset
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/ShareFileset/71fe9073-421c-4892-b96e-a9dffac05f24/overview
IF ($ObjectType -eq "WindowsFileset"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/hosts_filesets/windows/hosts?object_status=PROTECTED%2CUNPROTECTED"}

# LinuxFileset
# https://rubrik-se.my.rubrik.com/inventory_hierarchy/ShareFileset/71fe9073-421c-4892-b96e-a9dffac05f24/overview
IF ($ObjectType -eq "LinuxFileset"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/hosts_filesets/unix_like/hosts?object_status=PROTECTED%2CUNPROTECTED"}

# ManagedVolume
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/managedVolumes/LEGACY/422e12dd-d948-537b-93f0-4a951f4fdac7/overview
IF ($ObjectType -eq "ManagedVolume"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/managedVolumes/LEGACY/" + $ObjectID + "/overview"}

# SlaManagedVolume
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/managedVolumes/SLA_BASED/315174be-497e-535a-bcbc-1b28aa61814f/overview
IF ($ObjectType -eq "SlaManagedVolume"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/managedVolumes/SLA_BASED/" + $ObjectID + "/overview"}

# SAP Hapa
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/sap_hana/DATABASES/377cbb80-4d0b-598d-bb65-a589009c88cf/overview
IF ($ObjectType -eq "SapHanaDatabase"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/sap_hana/DATABASES/" + $ObjectID + "/overview"}

# SAP Hana System
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/sap_hana/SYSTEMS/f72a707c-f655-5761-936b-740cd62bff54
IF ($ObjectType -eq "SapHanaSystem"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/sap_hana/SYSTEMS/" + $ObjectID + "/overview"}

# Mssql
# https://rubrik-se-rdp.my.rubrik.com/inventory_hierarchy/MssqlDatabase/0588107b-5ec4-542d-854a-569d91bc4172/overview
IF ($ObjectType -eq "Mssql"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/MssqlDatabase/" + $ObjectID + "/overview"}

# MssqlHost
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/mssql/hosts_instances/host/922d7801-9551-5cf3-92d8-02a9af468b4c
IF ($ObjectType -eq "MssqlHost"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/host/" + $ObjectID}

# OracleDataGuardGroup
# https://rubrik-se-rdp.my.rubrik.com/inventory_hierarchy/OracleDataGuardGroup/170068b8-1f1e-50f3-b9f0-c5fad6ec341d/overview
IF ($ObjectType -eq "OracleDataGuardGroup"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/OracleDataGuardGroup/" + $ObjectID + "/overview"}

# OracleDatabase
# https://rubrik-se-rdp.my.rubrik.com/inventory_hierarchy/OracleDatabase/170068b8-1f1e-50f3-b9f0-c5fad6ec341d/overview
IF ($ObjectType -eq "OracleDatabase"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/OracleDatabase/" + $ObjectID + "/overview"}

# Oracle Host
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/oracle/hosts_rac/host_rac/30481806-7d37-5af6-9d98-c93e687af7fb
IF ($ObjectType -eq "OracleHost"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/hosts_rac/host_rac/" + $ObjectID}

# Roles
# https://rubrik-gaia.my.rubrik.com/roles/00000000-0000-0000-0000-000000000000
IF ($ObjectType -eq "Role"){$RSCObjectURL = $RSCURL + "/roles/" + $ObjectID}

# SDD Policy
# https://rubrik-gaia.my.rubrik.com/sonar/management/policies/9a21a88c-269f-4037-bfe7-99d906848101
IF ($ObjectType -eq "SDDPolicy"){$RSCObjectURL = $RSCURL + "/sonar/management/policies/" + $ObjectID}

# SDD object
# https://rubrik-gaia.my.rubrik.com/sonar/objects/detail/14c3d9c3-7f3c-57fb-b10c-5f6b491b1974/bfa53fcc-e743-5b8b-8ef2-b15b81b773ba/browse
IF ($ObjectType -eq "SDDObject"){$RSCObjectURL = $RSCURL + "/sonar/management/policies/" + $ObjectID}

# Db2Database
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/db2/DATABASES/d3e73715-fe70-5161-b825-ae60b0c19809/overview
IF ($ObjectType -eq "Db2Database"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/db2/DATABASES/" + $ObjectID + "/overview"}

# Db2Instance
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/db2/INSTANCES/a82babe6-65c2-523b-97b9-3a5a1bb271dd
IF ($ObjectType -eq "Db2Instance"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/db2/INSTANCES/" + $ObjectID + "/overview"}

# K8 Namespace
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/kubernetes/K8Namespace/42a70899-88f8-506d-9aeb-0c4a03e79fc6/overview
IF ($ObjectType -eq "K8SNamespace"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/kubernetes/K8Namespace/" + $ObjectID + "/overview"}

# AD Domain
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/on_prem_ad/domains/797ea553-a601-5772-b650-7325a8ae3ed2/overview
IF ($ObjectType -eq "ADDomain"){$RSCObjectURL = $RSCURL + "/on_prem_ad/domains/" + $ObjectID + "/overview"}

# AD Domain Controllers
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/on_prem_ad/domain_controllers/5218aae2-cee6-5bcc-b2e8-1348f10f61d9/overview
IF ($ObjectType -eq "ADDomainController"){$RSCObjectURL = $RSCURL + "/on_prem_ad/domain_controllers/" + $ObjectID + "/overview"}

# AD Domain controllers
# https://rubrik-dc.my.rubrik.com/inventory_hierarchy/on_prem_ad/domain_controllers/bfcb4867-959e-5329-99a4-e1160937b0a8/overview
IF ($ObjectType -eq "ACTIVE_DIRECTORY_DOMAIN_CONTROLLER"){$RSCObjectURL = $RSCURL + "/on_prem_ad/domain_controllers/" + $ObjectID + "/overview"}

# EntraID domain
# https://rubrik-dc.my.rubrik.com/inventory_hierarchy/azure_ad/f07e6ce6-2536-40d0-8509-ed6d8c78034f/overview
IF ($ObjectType -eq "EntraIDDomain"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/azure_ad/" + $ObjectID + "/overview"}

# EntraID domain
# https://rubrik-dc.my.rubrik.com/inventory_hierarchy/azure_ad/f07e6ce6-2536-40d0-8509-ed6d8c78034f/overview
IF ($ObjectType -eq "ENTRA_ID_DOMAIN"){$RSCObjectURL = $RSCURL + "/inventory_hierarchy/azure_ad/" + $ObjectID + "/overview"}

# If null not manageable in Polaris, or it's a fileset and I haven't figured out how to link to the host yet
IF ($RSCObjectURL -eq $null){$RSCObjectURL = $RSCURL}

# Returning Result
Return $RSCObjectURL
}