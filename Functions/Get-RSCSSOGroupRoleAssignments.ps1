################################################
# Function - Get-RSCSSOGroupRoleAssignments - Getting SSO Group Role Assignments within RSC
################################################
Function Get-RSCSSOGroupRoleAssignments {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returns a list of all role assignments per user/service account.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSSOGroupRoleAssignments
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Querying RSC GraphQL API
################################################
# Creating array for objects
$RSCList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "UserGroupsOrgQuery";

"variables" = @{
"first" = 1000
};

"query" = "query UserGroupsOrgQuery(`$after: String, `$before: String, `$first: Int, `$last: Int, `$filter: GroupFilterInput, `$shouldIncludeGroupsWithoutRole: Boolean = false, `$isOrgDataVisible: Boolean = false) {
  groupsInCurrentAndDescendantOrganization(after: `$after, before: `$before, first: `$first, last: `$last, filter: `$filter, shouldIncludeGroupsWithoutRole: `$shouldIncludeGroupsWithoutRole) {
    edges {
      node {
        groupId
        groupName
        roles {
          id
          name
          description
          effectivePermissions {
            objectsForHierarchyTypes {
              objectIds
              snappableType
              __typename
            }
            operation
            __typename
          }
          __typename
        }
        users {
          email
          id
          __typename
        }
        ...OrganizationGroupFragment @include(if: `$isOrgDataVisible)
        __typename
      }
      __typename
    }
    __typename
  }
}

fragment OrganizationGroupFragment on Group {
  allOrgs {
    name
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
$RSCList += $RSCResponse.data.groupsInCurrentAndDescendantOrganization.edges.node
# Getting all results from paginations
While ($RSCResponse.data.groupsInCurrentAndDescendantOrganization.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.groupsInCurrentAndDescendantOrganization.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.groupsInCurrentAndDescendantOrganization.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCSSOGroupRoleAssignments = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Group in $RSCList)
{
# Setting variables
$GroupName = $Group.groupname
$GroupID = $Group.groupId
$GroupRoles = $Group.roles
$GroupUsers = $Group.users
# Counting
$GroupRoleCount = $GroupRoles | Measure-Object | Select-Object -ExpandProperty Count
$GroupUserCount = $GroupUsers | Measure-Object | Select-Object -ExpandProperty Count
# For each role assignment
ForEach($Role in $GroupRoles)
{
# Checking if in default admin group
IF($Role.id -match "00000000-0000-0000-0000-000000000000"){$IsDefaultAdminRole = $TRUE}ELSE{$IsDefaultAdminRole = $FALSE}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Group" -Value $GroupName
$Object | Add-Member -MemberType NoteProperty -Name "GroupID" -Value $GroupID
$Object | Add-Member -MemberType NoteProperty -Name "Role" -Value $Role.name
$Object | Add-Member -MemberType NoteProperty -Name "RoleID" -Value $Role.id
$Object | Add-Member -MemberType NoteProperty -Name "IsDefaultAdminRole" -Value $IsDefaultAdminRole
$Object | Add-Member -MemberType NoteProperty -Name "Description" -Value $Role.description
$Object | Add-Member -MemberType NoteProperty -Name "UserCount" -Value $GroupUserCount
$Object | Add-Member -MemberType NoteProperty -Name "Users" -Value $GroupUsers
$Object | Add-Member -MemberType NoteProperty -Name "Permissions" -Value $Role.effectivePermissions
# Adding
$RSCSSOGroupRoleAssignments.Add($Object) | Out-Null
}
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCSSOGroupRoleAssignments
# End of function
}