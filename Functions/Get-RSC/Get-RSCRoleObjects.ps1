################################################
# Function - Get-RSCRoleObjects - Getting all objects assigned to Roles within RSC
################################################
Function Get-RSCRoleObjects {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all objects explicitly configured on roles.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCRoleObjects
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 07/15/24
#>

################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline=$true)]
        [array]$PipelineArray,
        [Parameter(Mandatory=$false)]
        [string]$RoleID
    )
################################################
# Importing Module & Running Required Functions
################################################
# IF piped the object array pulling out the ObjectID needed
IF($PipelineArray -ne $null){$RoleID = $PipelineArray | Select-Object -ExpandProperty ObjectID -First 1}
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting role assignments
$RSCRoleAssignments = Get-RSCUserRoleAssignments
# Getting roles
$RSCRoles = Get-RSCRoles
# Getting objects list if not already pulled as a global variable in this session
IF($RSCGlobalObjects -eq $null){$RSCObjects = Get-RSCObjects;$Global:RSCGlobalObjects = $RSCObjects}ELSE{$RSCObjects = $RSCGlobalObjects}
# If passed RoleID only querying that role, if not passed any, querying all
IF($RoleID -ne $null){$RoleIDs = $RoleID}ELSE{$RoleIDs = $RSCRoles | Select-Object -ExpandProperty RoleID}
# Creating array
$RSCRoleObjects = [System.Collections.ArrayList]@()
################################################
# Querying RSC GraphQL API
################################################
ForEach($RoleID in $RoleIDs)
{
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "RoleDetailsQuery";

"variables" = @{
"roleIds" = "$RoleID"
};

"query" = "query RoleDetailsQuery(`$roleIds: [String!]!) {
  getRolesByIds(roleIds: `$roleIds) {
    id
    name
    description
    isReadOnly
    protectableClusters
    explicitlyAssignedPermissions {
      ...PermissionsFragment
      __typename
    }
    effectiveRbacPermissions {
      rbacObject {
        objectId
        workloadHierarchy
        clusterId
        __typename
      }
      operations
      __typename
    }
    isOrgAdmin
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
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Getting detail
$RoleDetail = $RSCResponse.data.getRolesByIds
# Setting variables
$RoleName = $RoleDetail.name
$RoleDescription = $RoleDetail.description
$IsOrgAdmin = $RoleDetail.isOrgAdmin
$IsReadOnly = $RoleDetail.IsReadOnly
$RoleObjectsList = $RoleDetail.effectiveRbacPermissions.rbacObject
################################################
# Processing List
################################################
ForEach ($RoleObject in $RoleObjectsList)
{
# Setting variables
$RoleObjectId = $RoleObject.objectId
$RoleClusterId = $RoleObject.clusterId
# Counting characters
$RoleCharCount = $RoleObjectId | Measure-Object -Character | Select-Object -ExpandProperty Characters
# If 36 characters, it's an actual object ID, so getting the object name
IF($RoleCharCount -eq 36)
{
$RoleObjectDetail = $RSCObjects | Where-Object {$_.ObjectID -eq $RoleObjectId}
$RoleObjectName = $RoleObjectDetail.Object
$RoleObjectType = $RoleObjectDetail.Type
# Getting URL for the object
$URL = Get-RSCObjectURL -ObjectType $RoleObjectType -ObjectID $RoleID
}
ELSE
{
# Setting name to be ID and type to null
$RoleObjectName = "ALL"
$RoleObjectType = $RoleObjectId
# Getting URL for role
$URL = Get-RSCObjectURL -ObjectType "Role" -ObjectID $RoleID
}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Role" -Value $RoleName
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $RoleObjectName
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $RoleObjectType
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $RoleObjectId
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $RoleClusterId
$Object | Add-Member -MemberType NoteProperty -Name "RoleID" -Value $RoleID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $URL
# Adding
$RSCRoleObjects.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# End of for each role below
}
# End of for each role above
#
# Returning array
Return $RSCRoleObjects
# End of function
}