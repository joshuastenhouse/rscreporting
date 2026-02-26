################################################
# Function - Stop-RSCMVSnapshot - Stopping an on demand snapshot of an RSC Managed Volume
################################################
function Stop-RSCMVSnapshot {
	
    <#
.SYNOPSIS
Makes a Managed Volume read only by taking a snapshot on the specified ObjectID and SLADomainID.

.DESCRIPTION
Only use this function for Stopping/Closing standard Managed Volumes, use Start-RSCMVSnapshot for SLA Managed Volumes and any other object type. It can also be piped a ManagedVolume object from Get-RSCManagedVolumes (see examples).

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
The RSC object ID of the managed volume which can be attained from Get-RSCManagedVolumes
.PARAMETER SLADomainID
The RSC SLADomainID on which to assign the on-demand snapshot to, if none specified, will use the SLA Domain ID assigned to the object.

.OUTPUTS
Returns an array with the status of the on-demand snapshot request.

.EXAMPLE
Stop-RSCMVSnapshot - ObjectID "0a8f6bc2-dce8-53a8-8e04-6de9293b5a26" -SLADomainID "00000-000000-0000000-00002"
This makes the managed volume (specified by ObjectID) read only by taking a snapshot on the SLADomainID specified.

.EXAMPLE
Get-RSCManagedVolumes | Where {$_.ManagedVolume -eq "YOURMVNAME"} | Stop-RSCMVSnapshot
This makes the managed volume selected read only by taking a snapshot with the SLA domain already assigned to the managed volume.

.NOTES
Author: Joshua Stenhouse
Date: 08/16/2023
#>
    ################################################
    # Paramater Config
    ################################################
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [array]$PipelineArray,
        [Parameter(Mandatory = $false)]
        [string]$ObjectID,
        [Parameter(Mandatory = $false)]
        [string]$SLADomainID
    )
    begin {}
    process {
        if ($pscmdlet.ShouldProcess("ManagedVolumeID $ObjectID")) {
            ################################################
            # Importing Module & Running Required Functions
            ################################################
            # IF piped the object array pulling out the ObjectID needed
            if ($PipelineArray -ne $null) { $ObjectID = $PipelineArray | Select-Object -ExpandProperty ObjectID -First 1 }
            # Importing
            Import-Module RSCReporting
            # Checking connectivity, exiting function with error if not
            Test-RSCConnection
            # Getting protected objects to validate IDs and get SLADomainID if null
            $RSCObjects = Get-RSCManagedVolumes
            # Getting all SLA domains to validate SLA domain ID
            $RSCSLADomains = Get-RSCSLADomains
            # Validating object ID exists
            $RSCObjectInfo = $RSCObjects | Where-Object { $_.ObjectID -eq $ObjectID }
            # Breaking if not
            if ($RSCObjectInfo -eq $null) {
                Write-Error "ERROR: ObjectID specified not found, check and try again.."
                break
            }
            # Getting SLA Domain ID if not already specified
            if ($SLADomainID -eq "") {
                $SLADomainID = $RSCObjectInfo.SLADomainID
                $SLADomain = $RSCObjectInfo.SLADomain
            }
            else {
                # Checking ID specified exists
                $SLADomainInfo = $RSCSLADomains | Where-Object { $_.SLADomainID -eq $SLADomainID }
                $SLADomainID = $SLADomainInfo.SLADomainID
                $SLADomain = $SLADomainInfo.SLADomain
            }
            # Breaking if SLADomainID not found
            if ($SLADomainID -eq $null) {
                Write-Error "ERROR: SLADomainID specified not found, check and try again.."
                break
            }
            # Getting object type, as not all objects use the generic on-demand snapshot call
            $RSCObjectProtocol = $RSCObjectInfo.Protocol
            $RSCObjectName = $RSCObjectInfo.ManagedVolume
            $RSCObjectRubrikCluster = $RSCObjectInfo.RubrikCluster
            $RSCObjectRubrikClusterID = $RSCObjectInfo.RubrikClusterID
            ################################################
            # Requesting ManagedVolume On Demand Snapshot
            ################################################
            # Building GraphQL query
            $RSCGraphQL = @{"operationName" = "ManagedVolumeOnDemandSnapshotMutation";

                "variables"                 = @{
                    "input" = @{
                        "id"     = "$ObjectID"
                        "params" = @{
                            "isAsync"         = $true
                            "retentionConfig" = @{
                                "slaId" = "$SLADomainID"
                            }
                        }
                    }
                };

                "query"                     = "mutation ManagedVolumeOnDemandSnapshotMutation(`$input: EndManagedVolumeSnapshotInput!) {
    endManagedVolumeSnapshot(input: `$input) {
      asyncRequestStatus {
        id
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
            $JobID = $RSCResponse.data.endManagedVolumeSnapshot.asyncRequestStatus.id
            # Setting timestamp
            $UTCDateTime = [System.DateTime]::UtcNow
            ################################################
            # Returing Job Info
            ################################################
            # Adding To Array
            $Object = New-Object PSObject
            $Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
            $Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "ManagedVolumeOnDemandSnapshotMutation"
            $Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
            $Object | Add-Member -MemberType NoteProperty -Name "ManagedVolume" -Value $RSCObjectName
            $Object | Add-Member -MemberType NoteProperty -Name "Protocol" -Value $RSCObjectProtocol
            $Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
            $Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $RSCObjectRubrikCluster
            $Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RSCObjectRubrikClusterID
            $Object | Add-Member -MemberType NoteProperty -Name "RequestDateUTC" -Value $UTCDateTime
            $Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RequestStatus
            $Object | Add-Member -MemberType NoteProperty -Name "JobID" -Value $JobID
            $Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message
            # Returning array
            return $Object
            # End of function
        }
    }
}
end {}

