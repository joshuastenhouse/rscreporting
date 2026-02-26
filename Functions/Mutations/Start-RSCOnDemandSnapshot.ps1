################################################
# Function - Start-RSCOnDemandSnapshot - Requesting an on demand snapshot of an RSC object
################################################
function Start-RSCOnDemandSnapshot {
	
    <#
.SYNOPSIS
Requests and on-demand snapshot on the ObjectID and SLADomainID specified, ensure both are valid otherwise the request will fail. If SLADomainID is null will use the SLADomain assigned to the object.

.DESCRIPTION
Do not use this function for Managed Volumes (non-SLA based), use the dedicated Start/Stop, this function is used for the following object types: Mssql, VmwareVirtualMachine, OracleDatabase, HypervVirtualMachine, NutanixVirtualMachine, WindowsFileset,
LinuxFileset, Db2Database, K8Namespace, ExchangeDatabase, AzureNativeVm, AzureNativeVm, Ec2Instance, AwsNativeRdsInstance, SLAManagedVolume. 

Not supported as of 08/16/2023: Azure SQL & o365 objects.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
The RSC object ID (sometimes referred to as ObjectFid on the backend API, always translated to ObjectID in the PowerShell module
.PARAMETER SLADomainID
The RSC SLADomainID on which to assign the on-demand snapshot to, if none specified, will use the SLA Domain ID assigned to the object.

.OUTPUTS
Returns an array with the status of the on-demand snapshot request.

.EXAMPLE
Start-RSCOnDemandSnapshot - ObjectID "0a8f6bc2-dce8-53a8-8e04-6de9293b5a26" -SLADomainID "wwiefjiwjefiwjeifjweofwiefjiwef"
This example prompts for the RSC URL, user ID and secret, then connects to RSC and securely stores them for subsequent use in the script directory specified.

.NOTES
Author: Joshua Stenhouse
Date: 08/20/24
#>
    ################################################
    # Paramater Config
    ################################################
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [array]$PipelineArray,
        [Parameter(Mandatory = $true)]
        [string]$ObjectID,
        [Parameter(Mandatory = $false)]
        [string]$SLADomainID,
        [Parameter(Mandatory = $false)]
        [string]$UserNote,
        [Parameter(ParameterSetName = "User")]
        [switch]$ForceOracleFull
    )
    begin {}
    process {
        if ($pscmdlet.ShouldProcess("ObjectID - $ObjectID")) {
            ################################################
            # Importing Module & Running Required Functions
            ################################################
            # IF piped the object array pulling out the ObjectID needed
            if ($PipelineArray -ne $null) { $ObjectID = $PipelineArray | Select-Object -ExpandProperty ObjectID -First 1 }
            # Importing module
            Import-Module RSCReporting
            # Checking connectivity, exiting function with error if not
            Test-RSCConnection
            # Validating object ID exists
            $RSCObjectInfo = Get-RSCObjectDetail -ObjectID $ObjectID
            # Breaking if not
            if ($RSCObjectInfo -eq $null) {
                Write-Error "ERROR: ObjectID specified not found, check and try again.."
                break
            }
            # Getting SLA Domain ID if not already specified
            if ($SLADomainID -eq $null) {
                $SLADomainID = $RSCObjectInfo.SLADomainID
                $SLADomain = $RSCObjectInfo.SLADomain
            }
            else {
                # Getting all SLA domains to validate SLA domain ID
                $RSCSLADomains = Get-RSCSLADomains
                $SLADomainInfo = $RSCSLADomains | Where-Object { $_.SLADomainID -eq $SLADomainID }
                $SLADomainID = $SLADomainInfo.SLADomainID
                $SLADomain = $SLADomainInfo.SLADomain
            }
            # Breaking if not found
            if ($SLADomainID -eq $null) {
                Write-Error "ERROR: SLADomainID specified not found, check and try again.."
                break
            }
            # Getting object type, as not all objects use the generic on-demand snapshot call
            $ObjectType = $RSCObjectInfo.Type
            # IF($OverrideObjecttype -eq $TRUE){$ObjectType = "K8Namespace"}
            # Getting other useful info
            $RSCObjectName = $RSCObjectInfo.Object
            $RSCObjectRubrikCluster = $RSCObjectInfo.RubrikCluster
            $RSCObjectRubrikClusterID = $RSCObjectInfo.RubrikClusterID
            # Deciding if to bypass generic on demand snapshot API call as many snappables requires their own mutation
            $BypassGenericAPI = $FALSE
            # Mssql
            if ($ObjectType -eq "Mssql") { $BypassGenericAPI = $TRUE }
            # VMware 
            if ($ObjectType -eq "VmwareVirtualMachine") { $BypassGenericAPI = $TRUE }
            # Oracle 
            if ($ObjectType -eq "OracleDatabase") { $BypassGenericAPI = $TRUE }
            # HyperV 
            if ($ObjectType -eq "HypervVirtualMachine") { $BypassGenericAPI = $TRUE }
            # NutanixVirtualMachine 
            if ($ObjectType -eq "NutanixVirtualMachine") { $BypassGenericAPI = $TRUE }
            # WindowsFileset
            if ($ObjectType -eq "WindowsFileset") { $BypassGenericAPI = $TRUE }
            # LinuxFileset
            if ($ObjectType -eq "LinuxFileset") { $BypassGenericAPI = $TRUE }
            # Db2Database
            if ($ObjectType -eq "Db2Database") { $BypassGenericAPI = $TRUE }
            # K8Namespace
            if ($ObjectType -eq "K8Namespace") { $BypassGenericAPI = $TRUE }
            # ExchangeDatabase
            if ($ObjectType -eq "ExchangeDatabase") { $BypassGenericAPI = $TRUE }
            # AzureNativeVm
            if ($ObjectType -eq "AzureNativeVm") { $BypassGenericAPI = $TRUE }
            # AzureNativeVm
            if ($ObjectType -eq "AzureNativeVm") { $BypassGenericAPI = $TRUE }
            # Ec2Instance
            if ($ObjectType -eq "Ec2Instance") { $BypassGenericAPI = $TRUE }
            # AwsNativeRdsInstance
            if ($ObjectType -eq "AwsNativeRdsInstance") { $BypassGenericAPI = $TRUE }
            # ManagedVolume
            if ($ObjectType -eq "ManagedVolume") { $BypassGenericAPI = $TRUE }
            ################################################
            # Requesting Generic On Demand Snapshot
            ################################################
            # As of 08/16/23 used by the following object types:
            # Setting mutation type for return
            $RSCMutation = "TakeOnDemandSnapshot"
            # GcpNativeGCEInstance
            if ($BypassGenericAPI -eq $FALSE) {
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "TakeOnDemandSnapshot";

                    "variables"                 = @{
                        "input" = @{
                            "slaId"       = "$SLADomainID"
                            "workloadIds" = "$ObjectID"
                        }
                    };

                    "query"                     = "mutation TakeOnDemandSnapshot(`$input: TakeOnDemandSnapshotInput!) {
  takeOnDemandSnapshot(input: `$input) {
    errors {
      error
      workloadId
    }
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
            }
            ################################################
            # Requesting VmwareVirtualMachine On Demand Snapshot
            ################################################
            if ($ObjectType -eq "VmwareVirtualMachine") {
                # Setting mutation type for return
                $RSCMutation = "TakeVSphereSnapshotMutation"
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "TakeVSphereSnapshotMutation";

                    "variables"                 = @{
                        "input" = @{
                            "id"     = "$ObjectID"
                            "config" = @{
                                "slaId" = "$SLADomainID"
                            }
                        }
                    };

                    "query"                     = "mutation TakeVSphereSnapshotMutation(`$input: VsphereOnDemandSnapshotInput!) {
  vsphereOnDemandSnapshot(input: `$input) {
      id
      status
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobID = $RSCResponse.data.vsphereOnDemandSnapshot.id
                $JobStatus = $RSCResponse.data.vsphereOnDemandSnapshot.status
            }
            ################################################
            # Requesting HypervVirtualMachine On Demand Snapshot
            ################################################
            if ($ObjectType -eq "HypervVirtualMachine") {
                # Setting mutation type for return
                $RSCMutation = "HypervOnDemandSnapshotMutation"
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "HypervOnDemandSnapshotMutation";

                    "variables"                 = @{
                        "input" = @{
                            "id"       = "$ObjectID"
                            "userNote" = "$UserNote"
                            "config"   = @{
                                "slaId" = "$SLADomainID"
                            }
                        }
                    };

                    "query"                     = "mutation HypervOnDemandSnapshotMutation(`$input: HypervOnDemandSnapshotInput!) {
  hypervOnDemandSnapshot(input: `$input) {
    status
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobStatus = $RSCResponse.data.hypervOnDemandSnapshot.status
            }
            ################################################
            # Requesting NutanixVirtualMachine On Demand Snapshot
            ################################################
            if ($ObjectType -eq "NutanixVirtualMachine") {
                # Setting mutation type for return
                $RSCMutation = "NutanixAHVSnapshotMutation"
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "NutanixAHVSnapshotMutation";

                    "variables"                 = @{
                        "input" = @{
                            "id"       = "$ObjectID"
                            "userNote" = "$UserNote"
                            "config"   = @{
                                "slaId" = "$SLADomainID"
                            }
                        }
                    };

                    "query"                     = "mutation NutanixAHVSnapshotMutation(`$input: CreateOnDemandNutanixBackupInput!) {
  createOnDemandNutanixBackup(input: `$input) {
    status
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobStatus = $RSCResponse.data.createOnDemandNutanixBackup.status
            }
            ################################################
            # Requesting WindowsFileset On Demand Snapshot
            ################################################
            if ($ObjectType -eq "WindowsFileset") {
                # Setting mutation type for return
                $RSCMutation = "TakeFilesetSnapshotMutation"
                # Building GraphQL query - note there's no input in the variable
                $RSCGraphQL = @{"operationName" = "TakeFilesetSnapshotMutation";

                    "variables"                 = @{
                        "id"       = "$ObjectID"
                        "userNote" = "$UserNote"
                        "config"   = @{
                            "slaId" = "$SLADomainID"
                        }
                    };

                    "query"                     = "mutation TakeFilesetSnapshotMutation(`$config: BaseOnDemandSnapshotConfigInput!, `$id: String!, `$userNote: String) {
  createFilesetSnapshot(input: {config: `$config, id: `$id, userNote: `$userNote}) {
    id
    status
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobStatus = $RSCResponse.data.createFilesetSnapshot.status
            }
            ################################################
            # Requesting LinuxFileset On Demand Snapshot
            ################################################
            if ($ObjectType -eq "LinuxFileset") {
                # Setting mutation type for return
                $RSCMutation = "TakeFilesetSnapshotMutation"
                # Building GraphQL query - note there's no input in the variable
                $RSCGraphQL = @{"operationName" = "TakeFilesetSnapshotMutation";

                    "variables"                 = @{
                        "id"       = "$ObjectID"
                        "userNote" = "$UserNote"
                        "config"   = @{
                            "slaId" = "$SLADomainID"
                        }
                    };

                    "query"                     = "mutation TakeFilesetSnapshotMutation(`$config: BaseOnDemandSnapshotConfigInput!, `$id: String!, `$userNote: String) {
  createFilesetSnapshot(input: {config: `$config, id: `$id, userNote: `$userNote}) {
    id
    status
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobStatus = $RSCResponse.data.createFilesetSnapshot.status
            }
            ################################################
            # Requesting Db2Database On Demand Snapshot
            ################################################
            if ($ObjectType -eq "Db2Database") {
                # Setting mutation type for return
                $RSCMutation = "Db2OnDemandSnapshotMutation"
                # Building GraphQL query - note there's no input in the variable
                $RSCGraphQL = @{"operationName" = "Db2OnDemandSnapshotMutation";

                    "variables"                 = @{
                        "id"       = "$ObjectID"
                        "userNote" = "$UserNote"
                        "config"   = @{
                            "slaId" = "$SLADomainID"
                        }
                    };

                    "query"                     = "mutation Db2OnDemandSnapshotMutation(`$id: String!, `$config: BaseOnDemandSnapshotConfigInput!) {
  createOnDemandDb2Backup(input: {id: `$id, config: `$config}) {
    id
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobID = $RSCResponse.data.createOnDemandDb2Backup.id
            }
            ################################################
            # Requesting K8Namespace On Demand Snapshot
            ################################################
            if ($ObjectType -eq "K8Namespace") {
                # Setting mutation type for return
                $RSCMutation = "TakeK8NamespaceSnapshotMutation"
                # Building GraphQL query - note there's no input in the variable
                $RSCGraphQL = @{"operationName" = "TakeK8NamespaceSnapshotMutation";

                    "variables"                 = @{
                        "k8sNamespaceSnapshotRequest" = @{
                            "namespaceId"           = "$ObjectID"
                            "onDemandSnapshotSlaId" = "$SLADomainID"
                        }
                    };

                    "query"                     = "mutation TakeK8NamespaceSnapshotMutation(`$k8sNamespaceSnapshotRequest: [K8sNamespaceSnapshot!]!) {
  createK8sNamespaceSnapshots(
    input: {snapshotInput: `$k8sNamespaceSnapshotRequest}
  ) {
    taskchainId
    jobId
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobID = $RSCResponse.data.createK8sNamespaceSnapshots.taskchainId
            }
            ################################################
            # Requesting MSSql On Demand Snapshot
            ################################################
            if ($ObjectType -eq "Mssql") {
                # Setting mutation type for return
                $RSCMutation = "MssqlTakeOnDemandSnapshotMutation"
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "MssqlTakeOnDemandSnapshotMutation";

                    "variables"                 = @{
                        "input" = @{
                            "id"       = "$ObjectID"
                            "userNote" = "$UserNote"
                            "config"   = @{
                                "baseOnDemandSnapshotConfig" = @{
                                    "slaId" = "$SLADomainID"
                                }
                            }
                        }
                    };

                    "query"                     = "mutation MssqlTakeOnDemandSnapshotMutation(`$input: CreateOnDemandMssqlBackupInput!) {
  createOnDemandMssqlBackup(input: `$input) {
    links {
      href
    }
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                # $JobID = $RSCResponse.data.createOnDemandMssqlBackup.id - Not on the API 08/15/23
                # $JobStatus = $RSCResponse.data.createOnDemandMssqlBackup.status - Not on the API 08/15/23
                # There is a link, but it returns the link of CDM? So useless...
            }
            ################################################
            # Requesting OracleDatabase On Demand Snapshot
            ################################################
            if ($ObjectType -eq "OracleDatabase") {
                # Setting mutation type for return
                $RSCMutation = "TakeOracleDatabaseBackupMutation"
                # Getting Oracle switch
                if ($ForceOracleFull) { $ForceOracleFull = $TRUE }else { $ForceOracleFull = $FALSE }
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "TakeOracleDatabaseBackupMutation";

                    "variables"                 = @{
                        "input" = @{
                            "id"     = "$ObjectID"
                            "config" = @{
                                "forceFullSnapshot"          = $ForceOracleFull
                                "baseOnDemandSnapshotConfig" = @{
                                    "slaId" = "$SLADomainID"
                                }
                            }
                        }
                    };

                    "query"                     = "mutation TakeOracleDatabaseBackupMutation(`$input: TakeOnDemandOracleDatabaseSnapshotInput!) {
  takeOnDemandOracleDatabaseSnapshot(input: `$input) {
    links {
      href
    }
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.data.message) { $RSCResponse.errors.message }
                # Getting response
                # $JobID = $RSCResponse.data.createOnDemandMssqlBackup.id - Not on the API 08/15/23
                # $JobStatus = $RSCResponse.data.createOnDemandMssqlBackup.status - Not on the API 08/15/23
                # There is a link, but it returns the link of CDM? So useless...
            }
            ################################################
            # Requesting ExchangeDatabase On Demand Snapshot
            ################################################
            if ($ObjectType -eq "ExchangeDatabase") {
                # Setting mutation type for return
                $RSCMutation = "TakeOnDemandSnapshot"
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "CreateOnDemandExchangeBackupMutation";

                    "variables"                 = @{
                        "input" = @{
                            "id"     = "$ObjectID"
                            "config" = @{
                                "baseOnDemandSnapshotConfig" = @{
                                    "slaId" = "$SLADomainID"
                                }
                            }
                        }
                    };

                    "query"                     = "mutation CreateOnDemandExchangeBackupMutation(`$input: CreateOnDemandExchangeDatabaseBackupInput!) {
  createOnDemandExchangeBackup(input: `$input) {
    id
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobID = $RSCResponse.data.createOnDemandExchangeBackup.id
            }
            ################################################
            # Requesting AzureNativeVm On Demand Snapshot
            ################################################
            if ($ObjectType -eq "AzureNativeVm") {
                # Setting mutation type for return
                $RSCMutation = "TakeAzureVMSnapshotMutation"
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "TakeAzureVMSnapshotMutation";

                    "variables"                 = @{
                        "input" = @{
                            "virtualMachineRubrikIds" = "$ObjectID"
                            "retentionSlaId"          = "$SLADomainID"
                        }
                    };

                    "query"                     = "mutation TakeAzureVMSnapshotMutation(`$input: StartCreateAzureNativeVirtualMachineSnapshotsJobInput!) {
  startCreateAzureNativeVirtualMachineSnapshotsJob(input: `$input) {
    jobIds {
      jobId
    }
    errors {
      error
    }
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobID = $RSCResponse.data.startCreateAzureNativeVirtualMachineSnapshotsJob.jobIds.jobId
            }
            ################################################
            # Requesting Ec2Instance On Demand Snapshot
            ################################################
            if ($ObjectType -eq "Ec2Instance") {
                # Setting mutation type for return
                $RSCMutation = "TakeEC2InstanceSnapshotMutation"
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "TakeEC2InstanceSnapshotMutation";

                    "variables"                 = @{
                        "input" = @{
                            "ec2InstanceIds" = "$ObjectID"
                            "retentionSlaId" = "$SLADomainID"
                        }
                    };

                    "query"                     = "mutation TakeEC2InstanceSnapshotMutation(`$input: StartAwsNativeEc2InstanceSnapshotsJobInput!) {
  startAwsNativeEc2InstanceSnapshotsJob(input: `$input) {
    jobIds {
      rubrikObjectId
      jobId
    }
    errors {
      error
    }
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobID = $RSCResponse.data.startAwsNativeEc2InstanceSnapshotsJob.jobIds.jobId
            }
            ################################################
            # Requesting AwsNativeRdsInstance On Demand Snapshot
            ################################################
            if ($ObjectType -eq "AwsNativeRdsInstance") {
                # Setting mutation type for return
                $RSCMutation = "TakeRDSInstanceSnapshotMutation"
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "TakeRDSInstanceSnapshotMutation";

                    "variables"                 = @{
                        "input" = @{
                            "rdsInstanceIds" = "$ObjectID"
                            "retentionSlaId" = "$SLADomainID"
                        }
                    };

                    "query"                     = "mutation TakeRDSInstanceSnapshotMutation(`$input: StartAwsNativeRdsInstanceSnapshotsJobInput!) {
  startAwsNativeRdsInstanceSnapshotsJob(input: `$input) {
    jobIds {
      rubrikObjectId
      jobId
    }
    errors {
      error
    }
  }
}"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobID = $RSCResponse.data.startAwsNativeRdsInstanceSnapshotsJob.jobIds.jobId
            }
            ################################################
            # Requesting ManagedVolume On Demand Snapshot
            ################################################
            if ($ObjectType -eq "ManagedVolume") {
                # Setting mutation type for return
                $RSCMutation = "SlaManagedVolumeOnDemandSnapshotMutation"
                # Building GraphQL query
                $RSCGraphQL = @{"operationName" = "SlaManagedVolumeOnDemandSnapshotMutation";

                    "variables"                 = @{
                        "input" = @{
                            "id"     = "$ObjectID"
                            "config" = @{
                                "retentionConfig" = @{
                                    "slaId" = "$SLADomainID"
                                }
                            }
                        }
                    };

                    "query"                     = "mutation SlaManagedVolumeOnDemandSnapshotMutation(`$input: TakeManagedVolumeOnDemandSnapshotInput!) {
    takeManagedVolumeOnDemandSnapshot(input: `$input) {
      id
    }
  }"
                }
                # Querying API
                try {
                    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
                    $RSCRequest = "SUCCESS"
                }
                catch {
                    $RSCRequest = "FAILED"
                }
                # Checking for permission errors
                if ($RSCResponse.errors.message) { $RSCResponse.errors.message }
                # Getting response
                $JobID = $RSCResponse.data.takeManagedVolumeOnDemandSnapshot.id
            }

            ################################################
            # Returing Job Info
            ################################################
            # Deciding outcome if no error messages
            if ($RSCResponse.errors.message -eq $null) { $RequestStatus = "SUCCESS" }else { $RequestStatus = "FAILED" }
            # Adding To Array
            $Object = New-Object PSObject
            $Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
            $Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value $RSCMutation
            $Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
            $Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $RSCObjectName
            $Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
            $Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
            $Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
            $Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
            $Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RSCObjectRubrikCluster
            $Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RSCObjectRubrikClusterID
            # $Object | Add-Member -MemberType NoteProperty -Name "JobID" -Value $JobID
            # $Object | Add-Member -MemberType NoteProperty -Name "JobStatus" -Value $JobStatus
            # $Object | Add-Member -MemberType NoteProperty -Name "JobURL" -Value $JobURL
            $Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message
            # Returning array
            return $Object
            # End of function
        }
    }
}
end {}

