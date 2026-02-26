################################################
# Function - Protect-RSCObject - Protects an object in RSC with an SLA domain
################################################
function Protect-RSCObject {
	
    <#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that protects the ObjectID with the SLADomainID specified.

.DESCRIPTION
Recommended use case is automated protection by SDK, where automated protection by tag, vCenter, host, account etc is not appropriate.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
The ObjectID of the object to protect, I.E a VMware VM, use Get-RSCUnprotectedObjects to obtain.
.PARAMETER SLADomainID
The SLADomainID of the SLA to protect, use Get-RSCSLADomains to obtain. If you use an SLADomain that is not supported by the ObjectID and/or the Rubrik cluster it's on, will error out with the messsage.

.OUTPUTS
Returns an array with the status of the being snapshot request.

.EXAMPLE
Protect-RSCObject -ObjectID $ObjectID -SLADomainID $SLADomainID
Specify an unprotected objectID and a valid SLADomainID to protect it with.

.NOTES
Author: Joshua Stenhouse
Date: 07/29/2025
#>
    ################################################
    # Paramater Config
    ################################################
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$ObjectID,
        [Parameter(Mandatory = $true)][string]$SLADomainID,
        [Parameter(ParameterSetName = "User")][switch]$CheckIDsExist,
        [Parameter(ParameterSetName = "User")][switch]$ShouldApplyToExistingSnapshots
    )

    ################################################
    # Importing Module & Running Required Functions
    ################################################
    # Importing
    Import-Module RSCReporting
    # Checking connectivity, exiting function with error if not
    Test-RSCConnection
    # Validating IDs exist if switch enabled
    if ($CheckIDsExist) {
        # Getting protected objects to validate ObjectID
        $RSCObjects = Get-RSCObjects
        # Validating object ID exists
        $RSCObjectInfo = $RSCObjects | Where-Object { $_.ObjectID -eq $ObjectID }
        # Breaking if not
        if ($RSCObjectInfo -eq $null) {
            Write-Error "ERROR: ObjectID specified not found, check and try again.."
            break
        }
        # Getting protected objects to validate ObjectID
        $RSCSLADomains = Get-RSCSLADomains
        # Validating object ID exists
        $RSCSLADomainInfo = $RSCSLADomains | Where-Object { $_.SLADomainID -eq $SLADomainID }
        # Breaking if not
        if ($RSCSLADomainInfo -eq $null) {
            Write-Error "ERROR: SLADomainID specified not found, check and try again.."
            break
        }
    }
    ################################################
    # API Call To RSC GraphQL URI To Assign SLA Domain
    ################################################
    # Setting timestamp
    $UTCDateTime = [System.DateTime]::UtcNow
    # Default Building GraphQL query
    if ($CheckIDsExist) {
        $RSCGraphQL = @{"operationName" = "AssignSlasForSnappableHierarchiesMutation";

            "variables"                 = @{
                "userNote"                        = "SLA Assigned By Powershell SDK"
                "globalExistingSnapshotRetention" = "RETAIN_SNAPSHOTS"
                "globalSlaAssignType"             = "protectWithSlaId"
                "globalSlaOptionalFid"            = "$SLADomainID"
                "objectIds"                       = "$ObjectID"
                "shouldApplyToExistingSnapshots"  = $false
                "shouldApplyToNonPolicySnapshots" = $false
            };

            "query"                     = "mutation AssignSlasForSnappableHierarchiesMutation(
`$globalExistingSnapshotRetention: GlobalExistingSnapshotRetention,
    `$globalSlaOptionalFid: UUID,
    `$globalSlaAssignType: SlaAssignTypeEnum!,
    `$objectIds: [UUID!]!,
    `$applicableSnappableTypes: [WorkloadLevelHierarchy!],
    `$shouldApplyToExistingSnapshots: Boolean,
    `$shouldApplyToNonPolicySnapshots: Boolean,
    `$userNote: String) {
    assignSlasForSnappableHierarchies(
      globalExistingSnapshotRetention: `$globalExistingSnapshotRetention,
      globalSlaOptionalFid: `$globalSlaOptionalFid,
      globalSlaAssignType: `$globalSlaAssignType,
      objectIds: `$objectIds,
      applicableSnappableTypes: `$applicableSnappableTypes,
      shouldApplyToExistingSnapshots: `$shouldApplyToExistingSnapshots,
      shouldApplyToNonPolicySnapshots: `$shouldApplyToNonPolicySnapshots,
      userNote: `$userNote
    ) {
      success
    }
  }"
        }
    }
    else {
        # Should not apply to existing snapshots
        $RSCGraphQL = @{"operationName" = "AssignSlasForSnappableHierarchiesMutation";

            "variables"                 = @{
                "userNote"                        = "SLA Assigned By Powershell SDK"
                "globalExistingSnapshotRetention" = "RETAIN_SNAPSHOTS"
                "globalSlaAssignType"             = "protectWithSlaId"
                "globalSlaOptionalFid"            = "$SLADomainID"
                "objectIds"                       = "$ObjectID"
                "shouldApplyToExistingSnapshots"  = $true
                "shouldApplyToNonPolicySnapshots" = $false
            };

            "query"                     = "mutation AssignSlasForSnappableHierarchiesMutation(
`$globalExistingSnapshotRetention: GlobalExistingSnapshotRetention,
    `$globalSlaOptionalFid: UUID,
    `$globalSlaAssignType: SlaAssignTypeEnum!,
    `$objectIds: [UUID!]!,
    `$applicableSnappableTypes: [WorkloadLevelHierarchy!],
    `$shouldApplyToExistingSnapshots: Boolean,
    `$shouldApplyToNonPolicySnapshots: Boolean,
    `$userNote: String) {
    assignSlasForSnappableHierarchies(
      globalExistingSnapshotRetention: `$globalExistingSnapshotRetention,
      globalSlaOptionalFid: `$globalSlaOptionalFid,
      globalSlaAssignType: `$globalSlaAssignType,
      objectIds: `$objectIds,
      applicableSnappableTypes: `$applicableSnappableTypes,
      shouldApplyToExistingSnapshots: `$shouldApplyToExistingSnapshots,
      shouldApplyToNonPolicySnapshots: `$shouldApplyToNonPolicySnapshots,
      userNote: `$userNote
    ) {
      success
    }
  }"
        }
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
    $JobResponse = $RSCResponse.data.assignSlasForSnappableHierarchies.success
    ################################################
    # Returing Job Info
    ################################################
    # Overring if not success on response
    if ($JobResponse -ne $TRUE) { $RequestStatus = "FAILED" }
    # Adding ErrorReason
    $ErrorReason = $null
    if ($RSCResponse.errors.message -eq "INTERNAL: Archival location is not specified in the cluster.") { $ErrorReason = "The SLADomainID specified is not valid for the ObjectID, resolve or use a different SLADomainID." }
    # Adding To Array
    $Object = New-Object PSObject
    $Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
    $Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "AssignSlasForSnappableHierarchiesMutation"
    $Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
    $Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
    $Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
    $Object | Add-Member -MemberType NoteProperty -Name "RequestDateUTC" -Value $UTCDateTime
    $Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RequestStatus
    $Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message
    $Object | Add-Member -MemberType NoteProperty -Name "ErrorReason" -Value $ErrorReason

    # Returning array
    return $Object
    # End of function
}
