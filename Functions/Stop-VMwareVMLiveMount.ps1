################################################
# Function - Stop-VMwareVMLiveMount - Requests to stop live mount for a VMware VM
################################################
Function Stop-VMwareVMLiveMount {
	
<#
.SYNOPSIS
Requests to stop a live mount of an VMware VM

.DESCRIPTION
The user has to specify the live mount ID to unmount the database.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SQLLiveMountID
The ID of the live mount to stop, use LiveMountID from Get-RSCMSSQLLiveMounts to select which to unmount.

.OUTPUTS
Returns an array with the status of the stop live mount request.

.EXAMPLE
Stop-MSSQLLiveMount -SourceDBID "71c0820a-3fbd-5e91-878f-42da723aa371" -TargetDBName "DemoLiveMount"
This example prompts for the RSC URL, user ID and secret, then connects to RSC and securely stores them for subsequent use in the script directory specified.

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
$RequestStatus = "SUCCESS"
}
Catch
{
$RequestStatus = "FAILED"
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