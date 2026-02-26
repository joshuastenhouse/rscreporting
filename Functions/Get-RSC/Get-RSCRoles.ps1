################################################
# Function - Get-RSCRoles - Getting Roles within RSC
################################################
function Get-RSCRole {

    <#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all roles configured.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCRoles
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
    [CmdletBinding()]
    [Alias('Get-RSCRoles')]
    param()
    ################################################
    # Importing Module & Running Required Functions
    ################################################
    # Importing the module is it needs other modules
    Import-Module RSCReporting
    # Checking connectivity, exiting function with error if not connected
    Test-RSCConnection
    # Getting role assignments
    $RSCRoleAssignments = Get-RSCUserRoleAssignments
    ################################################
    # Querying RSC GraphQL API
    ################################################
    # Creating array for objects
    $RSCList = @()
    # Building GraphQL query
    $RSCGraphQL = @{"operationName" = "RolesQuery";

        "variables"                 = @{
            "first" = 1000
        };

        "query"                     = "query RolesQuery(`$after: String, `$first: Int, `$sortBy: RoleFieldEnum, `$sortOrder: SortOrder, `$nameSearch: String) {
  getAllRolesInOrgConnection(after: `$after, first: `$first, sortBy: `$sortBy, sortOrder: `$sortOrder, nameFilter: `$nameSearch) {
    edges {
      cursor
      node {
        id
        isReadOnly
        name
        description
        explicitlyAssignedPermissions {
          ...PermissionsFragment
          __typename
        }
        isOrgAdmin
        __typename
      }
      __typename
    }
    pageInfo {
      startCursor
      endCursor
      hasNextPage
      hasPreviousPage
      __typename
    }
    __typename
  }
}

fragment PermissionsFragment on Permission {
  operation
  objectsForHierarchyTypes {
    objectIds
    snappableType
    __typename
  }
  __typename
}"
    }
    ################################################
    # API Call To RSC GraphQL URI
    ################################################
    # Querying API
    $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
    $RSCList += $RSCResponse.data.getAllRolesInOrgConnection.edges.node
    # Getting all results from paginations
    while ($RSCResponse.data.getAllRolesInOrgConnection.pageInfo.hasNextPage) {
        # Getting next set
        $RSCGraphQL.variables.after = $RSCResponse.data.getAllRolesInOrgConnection.pageInfo.endCursor
        $RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
        $RSCList += $RSCResponse.data.getAllRolesInOrgConnection.edges.node
    }
    ################################################
    # Processing List
    ################################################
    # Creating array
    $RSCRoles = [System.Collections.ArrayList]@()
    # For Each Object Getting Data
    foreach ($Role in $RSCList) {
        # Setting variables
        $RoleID = $Role.id
        $RoleName = $Role.name
        $RoleDescription = $Role.description
        $RoleIsOrgAdmin = $Role.isOrgAdmin
        $RoleOrgID = $Role.orgId
        $RolePermissions = $Role.explicitlyAssignedPermissions
        $RoleExplicitPermissions = $Role.explicitlyAssignedPermissions
        # Counting users assigned
        $RoleAssignments = $RSCRoleAssignments | Where-Object { $_.RoleID -eq $RoleID }
        $RoleAssignmentsCount = $RoleAssignments | Measure-Object | Select-Object -ExpandProperty Count
        # SLA permissions
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_SLA" }) { $RoleCanViewSLAs = $TRUE }else { $RoleCanViewSLAs = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "CREATE_SLA" }) { $RoleCanCreateSLAs = $TRUE }else { $RoleCanCreateSLAs = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "MODIFY_SLA" }) { $RoleCanModifySLAs = $TRUE }else { $RoleCanModifySLAs = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "MANAGE_SLA" }) { $RoleCanManageSLAs = $TRUE }else { $RoleCanManageSLAs = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "DELETE_SLA" }) { $RoleCanDeleteSLAs = $TRUE }else { $RoleCanDeleteSLAs = $FALSE }
        # Job permissions
        if ($RolePermissions | Where-Object { $_.operation -match "CANCEL_RUNNING_ACTIVITY" }) { $RoleCanCancelJobs = $TRUE }else { $RoleCanCancelJobs = $FALSE }
        # Protection
        if ($RolePermissions | Where-Object { $_.operation -match "MANAGE_PROTECTION" }) { $RoleCanManageProtection = $TRUE }else { $RoleCanManageProtection = $FALSE }
        # Webhooks
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_WEBHOOKS" }) { $RoleCanViewWebhooks = $TRUE }else { $RoleCanViewWebhooks = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "MANAGE_WEBHOOKS" }) { $RoleCanManageWebhooks = $TRUE }else { $RoleCanManageWebhooks = $FALSE }
        # Download
        if ($RolePermissions | Where-Object { $_.operation -match "DOWNLOAD" }) { $RoleCanDownload = $TRUE }else { $RoleCanDownload = $FALSE }
        # Mount
        if ($RolePermissions | Where-Object { $_.operation -match "MOUNT" }) { $RoleCanMount = $TRUE }else { $RoleCanMount = $FALSE }
        # Instant Recover
        if ($RolePermissions | Where-Object { $_.operation -match "INSTANT_RECOVER" }) { $RoleCanInstantRecover = $TRUE }else { $RoleCanInstantRecover = $FALSE }
        # Export
        if ($RolePermissions | Where-Object { $_.operation -match "EXPORT" }) { $RoleCanExport = $TRUE }else { $RoleCanExport = $FALSE }
        # Export Files
        if ($RolePermissions | Where-Object { $_.operation -match "EXPORT_FILES" }) { $RoleCanExportFiles = $TRUE }else { $RoleCanExportFiles = $FALSE }
        # Reporting
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_REPORT" }) { $RoleCanViewReports = $TRUE }else { $RoleCanViewReports = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "CREATE_REPORT" }) { $RoleCanCreateReports = $TRUE }else { $RoleCanCreateReports = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "MODIFY_REPORT" }) { $RoleCanModifyReports = $TRUE }else { $RoleCanModifyReports = $FALSE }
        # Legal hold
        if ($RolePermissions | Where-Object { $_.operation -match "MANAGE_LEGAL_HOLD" }) { $RoleCanManageLegalHold = $TRUE }else { $RoleCanManageLegalHold = $FALSE }
        # On demand backup
        if ($RolePermissions | Where-Object { $_.operation -match "TAKE_ON_DEMAND_SNAPSHOT" }) { $RoleCanTakeOnDemandBackup = $TRUE }else { $RoleCanTakeOnDemandBackup = $FALSE }
        # Threat hunting
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_THREAT_HUNT_RESULTS" }) { $RoleCanViewThreatHunt = $TRUE }else { $RoleCanViewThreatHunt = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "CREATE_THREAT_HUNT" }) { $RoleCanCreateThreatHunt = $TRUE }else { $RoleCanCreateThreatHunt = $FALSE }
        # Delete snapshots
        if ($RolePermissions | Where-Object { $_.operation -match "DELETE_SNAPSHOT" }) { $RoleCanDeleteSnapshots = $TRUE }else { $RoleCanDeleteSnapshots = $FALSE }
        # Quarantine
        if ($RolePermissions | Where-Object { $_.operation -match "EDIT_QUARANTINE" }) { $RoleCanQuarantineSnapshots = $TRUE }else { $RoleCanQuarantineSnapshots = $FALSE }
        # Recover from quarantine
        if ($RolePermissions | Where-Object { $_.operation -match "RECOVER_FROM_QUARANTINE" }) { $RoleCanRecoverFromQuarantineSnapshots = $TRUE }else { $RoleCanRecoverFromQuarantineSnapshots = $FALSE }
        # Cluster actions
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_CLUSTER" }) { $RoleCanViewCluster = $TRUE }else { $RoleCanViewCluster = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "REMOVE_CLUSTER" }) { $RoleCanRemoveCluster = $TRUE }else { $RoleCanRemoveCluster = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "REMOVE_CLUSTER_NODES" }) { $RoleCanRemoveClusterNodes = $TRUE }else { $RoleCanRemoveClusterNodes = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "MANAGE_CLUSTER_DISKS" }) { $RoleCanManageClusterDisks = $TRUE }else { $RoleCanManageClusterDisks = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "MANAGE_CLUSTER_SETTINGS" }) { $RoleCanManageClusterSettings = $TRUE }else { $RoleCanManageClusterSettings = $FALSE }
        # Resize MV
        if ($RolePermissions | Where-Object { $_.operation -match "RESIZE_MANAGED_VOLUME" }) { $RoleCanResizeManagedVolumes = $TRUE }else { $RoleCanResizeManagedVolumes = $FALSE }
        # Upgrade cluster
        if ($RolePermissions | Where-Object { $_.operation -match "UPGRADE_CLUSTER" }) { $RoleCanUpgradeCluster = $TRUE }else { $RoleCanUpgradeCluster = $FALSE }
        # Support tunnel
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_CDM_SUPPORT_SETTING" }) { $RoleCanViewSupportTunnels = $TRUE }else { $RoleCanViewSupportTunnels = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "ALLOW_SUPPORT_USER_SESSIONS" }) { $RoleCanOpenSupportTunnels = $TRUE }else { $RoleCanOpenSupportTunnels = $FALSE }
        # Access
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_ACCESS" }) { $RoleCanViewAccess = $TRUE }else { $RoleCanViewAccess = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "MANAGE_ACCESS" }) { $RoleCanManageAccess = $TRUE }else { $RoleCanManageAccess = $FALSE }
        # Restore
        if ($RolePermissions | Where-Object { $_.operation -match "RESTORE" }) { $RoleCanRestore = $TRUE }else { $RoleCanRestore = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "RESTORE_TO_ORIGIN" }) { $RoleCanRestoreToOriginal = $TRUE }else { $RoleCanRestoreToOriginal = $FALSE }
        # Security settings
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_SECURITY_SETTINGS" }) { $RoleCanViewSecuritySettings = $TRUE }else { $RoleCanViewSecuritySettings = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "EDIT_SECURITY_SETTINGS" }) { $RoleCanEditSecuritySettings = $TRUE }else { $RoleCanEditSecuritySettings = $FALSE }
        # Misc
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_CLUSTER_LICENSES" }) { $RoleCanViewLicensing = $TRUE }else { $RoleCanViewLicensing = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_DASHBOARD" }) { $RoleCanViewDashboard = $TRUE }else { $RoleCanViewDashboard = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "REFRESH_DATA_SOURCE" }) { $RoleCanRefreshDataSource = $TRUE }else { $RoleCanRefreshDataSource = $FALSE }
        # Data classification
        if ($RolePermissions | Where-Object { $_.operation -match "VIEW_DATA_CLASS_GLOBAL" }) { $RoleCanViewDataClassification = $TRUE }else { $RoleCanViewDataClassification = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "CONFIGURE_DATA_CLASS_GLOBAL" }) { $RoleCanConfigureDataClassification = $TRUE }else { $RoleCanConfigureDataClassification = $FALSE }
        if ($RolePermissions | Where-Object { $_.operation -match "EXPORT_DATA_CLASS_GLOBAL" }) { $RoleCanExportDataClassification = $TRUE }else { $RoleCanExportDataClassification = $FALSE }
        # Getting URL
        $RoleURL = Get-RSCObjectURL -ObjectType "Role" -ObjectID $RoleID
        # Adding To Array
        $Object = New-Object PSObject
        $Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
        $Object | Add-Member -MemberType NoteProperty -Name "Role" -Value $RoleName
        $Object | Add-Member -MemberType NoteProperty -Name "Description" -Value $RoleDescription
        $Object | Add-Member -MemberType NoteProperty -Name "RoleID" -Value $RoleID
        $Object | Add-Member -MemberType NoteProperty -Name "Users" -Value $RoleAssignmentsCount
        $Object | Add-Member -MemberType NoteProperty -Name "IsOrgAdmin" -Value $RoleIsOrgAdmin
        # SLA permissions
        $Object | Add-Member -MemberType NoteProperty -Name "ViewSLAs" -Value $RoleCanViewSLAs
        $Object | Add-Member -MemberType NoteProperty -Name "CreateSLAs" -Value $RoleCanCreateSLAs
        $Object | Add-Member -MemberType NoteProperty -Name "ModifySLAs" -Value $RoleCanModifySLAs
        $Object | Add-Member -MemberType NoteProperty -Name "ManageSLAs" -Value $RoleCanManageSLAs
        $Object | Add-Member -MemberType NoteProperty -Name "DeleteSLAs" -Value $RoleCanDeleteSLAs
        # Cluster actions
        $Object | Add-Member -MemberType NoteProperty -Name "ViewCluster" -Value $RoleCanViewCluster
        $Object | Add-Member -MemberType NoteProperty -Name "RemoveCluster" -Value $RoleCanRemoveCluster
        $Object | Add-Member -MemberType NoteProperty -Name "RemoveClusterNodes" -Value $RoleCanRemoveClusterNodes
        $Object | Add-Member -MemberType NoteProperty -Name "ManageClusterDisks" -Value $RoleCanManageClusterDisks
        $Object | Add-Member -MemberType NoteProperty -Name "ManageClusterSettings" -Value $RoleCanManageClusterSettings
        # Job permissions
        $Object | Add-Member -MemberType NoteProperty -Name "CancelJobs" -Value $RoleCanCancelJobs
        # Protection
        $Object | Add-Member -MemberType NoteProperty -Name "ManageProtection" -Value $RoleCanManageProtection
        # Webhooks
        $Object | Add-Member -MemberType NoteProperty -Name "ViewWebhooks" -Value $RoleCanViewWebhooks
        $Object | Add-Member -MemberType NoteProperty -Name "ManageWebhooks" -Value $RoleCanManageWebhooks
        # Download
        $Object | Add-Member -MemberType NoteProperty -Name "Download" -Value $RoleCanDownload
        # Mount
        $Object | Add-Member -MemberType NoteProperty -Name "Mount" -Value $RoleCanMount
        # Instant Recover
        $Object | Add-Member -MemberType NoteProperty -Name "InstantRecover" -Value $RoleCanInstantRecover
        # Export
        $Object | Add-Member -MemberType NoteProperty -Name "Export" -Value $RoleCanExport
        # Export Files
        $Object | Add-Member -MemberType NoteProperty -Name "ExportFiles" -Value $RoleCanExportFiles
        # Reporting
        $Object | Add-Member -MemberType NoteProperty -Name "ViewReports" -Value $RoleCanViewReports
        $Object | Add-Member -MemberType NoteProperty -Name "CreateReports" -Value $RoleCanCreateReports
        $Object | Add-Member -MemberType NoteProperty -Name "ModifyReports" -Value $RoleCanModifyReports
        # Legal hold
        $Object | Add-Member -MemberType NoteProperty -Name "ManageLegalHold" -Value $RoleCanManageLegalHold
        # On demand backup
        $Object | Add-Member -MemberType NoteProperty -Name "TakeOnDemandBackup" -Value $RoleCanTakeOnDemandBackup
        # Threat hunting
        $Object | Add-Member -MemberType NoteProperty -Name "ViewThreatHunt" -Value $RoleCanViewThreatHunt
        $Object | Add-Member -MemberType NoteProperty -Name "CreateThreatHunt" -Value $RoleCanCreateThreatHunt
        # Delete snapshots
        $Object | Add-Member -MemberType NoteProperty -Name "DeleteSnapshots" -Value $RoleCanDeleteSnapshots
        # Quarantine
        $Object | Add-Member -MemberType NoteProperty -Name "QuarantineSnapshots" -Value $RoleCanQuarantineSnapshots
        $Object | Add-Member -MemberType NoteProperty -Name "RecoverFromQuarantineSnapshots" -Value $RoleCanRecoverFromQuarantineSnapshots
        # Resize MV
        $Object | Add-Member -MemberType NoteProperty -Name "ResizeManagedVolumes" -Value $RoleCanResizeManagedVolumes
        # Upgrade cluster
        $Object | Add-Member -MemberType NoteProperty -Name "UpgradeCluster" -Value $RoleCanUpgradeCluster
        # Support tunnel
        $Object | Add-Member -MemberType NoteProperty -Name "ViewSupportTunnels" -Value $RoleCanViewSupportTunnels
        $Object | Add-Member -MemberType NoteProperty -Name "OpenSupportTunnels" -Value $RoleCanOpenSupportTunnels
        # Access
        $Object | Add-Member -MemberType NoteProperty -Name "ViewAccess" -Value $RoleCanViewAccess
        $Object | Add-Member -MemberType NoteProperty -Name "ManageAccess" -Value $RoleCanManageAccess
        # Restore
        $Object | Add-Member -MemberType NoteProperty -Name "Restore" -Value $RoleCanRestore
        $Object | Add-Member -MemberType NoteProperty -Name "RestoreToOriginal" -Value $RoleCanRestoreToOriginal
        # Security settings
        $Object | Add-Member -MemberType NoteProperty -Name "ViewSecuritySettings" -Value $RoleCanViewSecuritySettings
        $Object | Add-Member -MemberType NoteProperty -Name "EditSecuritySettings" -Value $RoleCanEditSecuritySettings
        # Data classification
        $Object | Add-Member -MemberType NoteProperty -Name "ViewDataClassification" -Value $RoleCanViewDataClassification
        $Object | Add-Member -MemberType NoteProperty -Name "ConfigureDataClassification" -Value $RoleCanConfigureDataClassification
        $Object | Add-Member -MemberType NoteProperty -Name "ExportDataClassification" -Value $RoleCanExportDataClassification
        # Misc
        $Object | Add-Member -MemberType NoteProperty -Name "ViewLicensing" -Value $RoleCanViewLicensing
        $Object | Add-Member -MemberType NoteProperty -Name "ViewDashboard" -Value $RoleCanViewDashboard
        $Object | Add-Member -MemberType NoteProperty -Name "RefreshDataSource" -Value $RoleCanRefreshDataSource
        # $Object | Add-Member -MemberType NoteProperty -Name "RolePermissions" -Value $RolePermissions
        $Object | Add-Member -MemberType NoteProperty -Name "RoleExplicitPermissions" -Value $RoleExplicitPermissions
        # URL
        $Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $RoleURL
        # Adding
        $RSCRoles.Add($Object) | Out-Null
        # End of for each object below
    }
    # End of for each object above
    #
    # Returning array
    return $RSCRoles
    # End of function
}

