################################################
# Function - Stop-RSCVMwareVMLiveMount - Requests to stop live mount for a VMware VM
################################################
Function Stop-RSCVMwareVMLiveMount {
	
<#
.SYNOPSIS
Requests to stop a live mount of an VMware VM

.DESCRIPTION
The user has to specify the live mount ID to unmount the database.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER LiveMountID
The ID of the live mount to stop, use LiveMountID from Get-RSCVMwareVMLiveMounts to select which to unmount.

.OUTPUTS
Returns an array with the status of the stop live mount request.

.EXAMPLE
Stop-RSCVMwareVMLiveMount -SourceDBID -LiveMountID "yiiuiui-fwfwefwef-2wqed2efwfe-efwef"

.NOTES
Author: Joshua Stenhouse
Date: 10/10/2023
#>
################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$LiveMountID
    )
################################################
# Importing Module & Running Required Functions
################################################
# Importing module
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
# Getting list of live mounts
$LiveMountList = Get-RSCVMwareVMLiveMounts
# Getting live mount ID
$LiveMountID = $LiveMountList | Where-Object {$_.LiveMountID -eq $LiveMountID} | Select-Object -ExpandProperty LiveMountID
# If null exiting
IF($LiveMountID -eq $null)
{
Write-Host "VMLiveMountIDNotFound: $LiveMountID
Check and try again..."
Break
}
################################################
# Requesting Live Mount IF Valid Settings
################################################
IF($LiveMountID -ne $null)
{
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "UnmountLiveMountMutation";

"variables" = @{
                    "livemountId" = "$LiveMountID"
                    "force" = $true
};

"query" = "mutation UnmountLiveMountMutation(`$livemountId: UUID!, `$force: Boolean) {
  vsphereVMDeleteLiveMount(livemountId: `$livemountId, force: `$force) {
    id
    links {
      href
      rel
      __typename
    }
    __typename
  }
}"
}
# Querying API
Try
{
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCRequest = "SUCCESS"
}
Catch
{
$RSCRequest = "FAILED"
}
# Checking for permission errors
IF($RSCResponse.errors.message){$RSCResponse.errors.message}
# Getting response
$JobURL = $RSCResponse.data.createMssqlLiveMount.links.href
$JobID = $RSCResponse.data.createMssqlLiveMount.id
################################################
# Returing Job Info
################################################
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "UnmountLiveMountMutation"
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
$Object | Add-Member -MemberType NoteProperty -Name "LiveMountID" -Value $LiveMountID
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RequestStatus
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message
# Returning array
Return $Object
# Not returning anything if didn't pass validation below
}
# Not returning anything if didn't pass validation above

# End of function
}