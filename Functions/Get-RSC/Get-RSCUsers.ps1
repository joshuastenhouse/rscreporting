################################################
# Function - Get-RSCUsers - Getting Users within RSC
################################################
Function Get-RSCUsers {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all users.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCUsers
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
$RSCGraphQL = @{"operationName" = "usersInCurrentAndDescendantOrganization";

"variables" = @{
"first" = 1000
};

"query" = "query usersInCurrentAndDescendantOrganization(`$first: Int, `$after: String, `$before: String) {
  usersInCurrentAndDescendantOrganization(first: `$first, after: `$after, before: `$before) {
    edges {
      node {
        email
        id
        isAccountOwner
        isHidden
        lastLogin
        lockoutState {
          isLocked
          lockMethod
          lockedAt
          unlockMethod
          unlockedAt
        }
        status
        totpStatus {
          isEnabled
          isEnforced
          isEnforcedUserLevel
          isSupported
          totpConfigUpdateAt
        }
        domain
        emailConfig {
          account
          digestId
          digestName
          eventDigestConfigJson
          frequency
          includeAudits
          includeEvents
          isImmediate
          recipientUserId
        }
        eulaState {
          isAccepted
          isPactsafeEnabled
          isPactsafeV2Enabled
        }
        groups
        roles {
          description
          id
          isOrgAdmin
          isReadOnly
          name
          orgId
          protectableClusters
        }
        unreadCount
        username
      }
    }
    pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      startCursor
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.usersInCurrentAndDescendantOrganization.edges.node
# Getting all results from paginations
While ($RSCResponse.data.usersInCurrentAndDescendantOrganization.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.usersInCurrentAndDescendantOrganization.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.usersInCurrentAndDescendantOrganization.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCUsers = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($User in $RSCList)
{
# Setting variables
$UserID = $User.id
$UserName = $User.username
$UserEmail = $User.email
$UserLockoutState = $User.lockoutState.isLocked
$UserLastLoginUNIX = $User.lastLogin
$UserDomain = $User.domain
$UserTOTPEnabled = $User.totpStatus.isEnabled
$UserTOTPEnforced = $User.totpStatus.isEnforced
$UserTOTPEnforcedOnUser = $User.totpStatus.isEnforcedUserLevel
$UserTOTPSupported = $User.totpStatus.isSupported
$UserTOTPConfiguredUNIX = $User.totpStatus.totpConfigUpdateAt
$UserStatus = $User.status
$UserRoles = $User.roles
$UserRoleNames =$UserRoles.name
$UserEULAAccepted = $User.eulaState.isAccepted
$UserIsHidden = $User.isHidden
$UserIsAccountOwner = $User.isAccountOwner
# Counting roles
$UserRoleCount = $UserRoles | Measure-Object | Select-Object -ExpandProperty Count
# Checking if in default admin group
IF($UserRoles.id -match "00000000-0000-0000-0000-000000000000"){$HasDefaultAdminRole = $TRUE}ELSE{$HasDefaultAdminRole = $FALSE}
# Fixing username if null
IF($UserName -eq ""){$UserSplit = $UserEmail.Split("@");$UserName = $UserSplit[0]}
# Converting UserLastLoginUNIX
IF($UserLastLoginUNIX -ne $null){$UserLastLoginUTC = Convert-RSCUNIXTime $UserLastLoginUNIX}ELSE{$UserLastLoginUTC = $null}
$UTCDateTime = [System.DateTime]::UtcNow
IF($UserLastLoginUTC -ne $null){$UserLastLoginTimespan = New-TimeSpan -Start $UserLastLoginUTC -End $UTCDateTime;$UserLastLoginHoursSince = $UserLastLoginTimespan | Select-Object -ExpandProperty TotalHours;$UserLastLoginHoursSince = [Math]::Round($UserLastLoginHoursSince,1)}ELSE{$UserLastLoginHoursSince = $null}
IF($UserLastLoginUTC -ne $null){$UserLastLoginMinutesSince = $UserLastLoginTimespan | Select-Object -ExpandProperty TotalMinutes;$UserLastLoginMinutesSince = [Math]::Round($UserLastLoginMinutesSince)}ELSE{$UserLastLoginMinutesSince = $null}
IF($UserLastLoginUTC -ne $null){$UserLastLoginDaysSince = $UserLastLoginTimespan | Select-Object -ExpandProperty TotalDays;$UserLastLoginDaysSince = [Math]::Round($UserLastLoginDaysSince,1)}ELSE{$UserLastLoginDaysSince = $null}
# Converting UserTOTPConfiguredUNIX
IF($UserTOTPConfiguredUNIX -ne $null){$UserTOTPConfiguredUTC = Convert-RSCUNIXTime $UserTOTPConfiguredUNIX}ELSE{$UserTOTPConfiguredUTC = $null}
$UTCDateTime = [System.DateTime]::UtcNow
IF($UserTOTPConfiguredUTC -ne $null){$UserTOTPConfiguredTimespan = New-TimeSpan -Start $UserTOTPConfiguredUTC -End $UTCDateTime;$UserTOTPConfiguredHoursSince = $UserTOTPConfiguredTimespan | Select-Object -ExpandProperty TotalHours;$UserTOTPConfiguredHoursSince = [Math]::Round($UserTOTPConfiguredHoursSince,1)}ELSE{$UserTOTPConfiguredHoursSince = $null}
IF($UserTOTPConfiguredUTC -ne $null){$UserTOTPConfiguredMinutesSince = $UserTOTPConfiguredTimespan | Select-Object -ExpandProperty TotalMinutes;$UserTOTPConfiguredMinutesSince = [Math]::Round($UserTOTPConfiguredMinutesSince)}ELSE{$UserTOTPConfiguredMinutesSince = $null}
IF($UserTOTPConfiguredUTC -ne $null){$UserTOTPConfiguredDaysSince = $UserTOTPConfiguredTimespan | Select-Object -ExpandProperty TotalDays;$UserTOTPConfiguredDaysSince = [Math]::Round($UserTOTPConfiguredDaysSince,1)}ELSE{$UserTOTPConfiguredDaysSince = $null}
# Creating URL
$UserURL = $RSCURL + "/users"
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Email" -Value $UserEmail
$Object | Add-Member -MemberType NoteProperty -Name "UserName" -Value $UserName
$Object | Add-Member -MemberType NoteProperty -Name "UserID" -Value $UserID
$Object | Add-Member -MemberType NoteProperty -Name "Domain" -Value $UserDomain
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $UserStatus
$Object | Add-Member -MemberType NoteProperty -Name "Lockout" -Value $UserLockoutState
$Object | Add-Member -MemberType NoteProperty -Name "LastLoginUTC" -Value $UserLastLoginUTC
$Object | Add-Member -MemberType NoteProperty -Name "LastLoginDaysSince" -Value $UserLastLoginDaysSince
$Object | Add-Member -MemberType NoteProperty -Name "LastLoginHoursSince" -Value $UserLastLoginHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "LastLoginMinutesSince" -Value $UserLastLoginMinutesSince
$Object | Add-Member -MemberType NoteProperty -Name "TOTPEnabled" -Value $UserTOTPEnabled
$Object | Add-Member -MemberType NoteProperty -Name "TOTPEnforced" -Value $UserTOTPEnforced
$Object | Add-Member -MemberType NoteProperty -Name "TOTPEnforcedonUser" -Value $UserTOTPEnforcedOnUser
$Object | Add-Member -MemberType NoteProperty -Name "TOTPSupported" -Value $UserTOTPSupported
$Object | Add-Member -MemberType NoteProperty -Name "TOTPConfiguredUTC" -Value $UserTOTPConfiguredUTC
$Object | Add-Member -MemberType NoteProperty -Name "TOTPConfiguredDaysSince" -Value $UserTOTPConfiguredDaysSince
$Object | Add-Member -MemberType NoteProperty -Name "TOTPConfiguredHoursSince" -Value $UserTOTPConfiguredHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "TOTPConfiguredMinutesSince" -Value $UserTOTPConfiguredMinutesSince
$Object | Add-Member -MemberType NoteProperty -Name "HasDefaultAdminRole" -Value $HasDefaultAdminRole
$Object | Add-Member -MemberType NoteProperty -Name "EULAAccepted" -Value $UserEULAAccepted
$Object | Add-Member -MemberType NoteProperty -Name "IsHidden" -Value $UserIsHidden
$Object | Add-Member -MemberType NoteProperty -Name "IsAccountOwner" -Value $UserIsAccountOwner
$Object | Add-Member -MemberType NoteProperty -Name "RoleCount" -Value $UserRoleCount
# $Object | Add-Member -MemberType NoteProperty -Name "Roles" -Value $UserRoles
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $UserURL
# Adding
$RSCUsers.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCUsers
# End of function
}