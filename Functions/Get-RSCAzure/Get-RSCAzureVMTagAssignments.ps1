################################################
# Function - Get-RSCAzureVMTagAssignments - Getting Azure Tags assigned to VMs visible to RSC
################################################
Function Get-RSCAzureVMTagAssignments {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function a list of all Azure VM tag assignments.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAzureVMTagAssignments
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 07/09/2024
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting all Azure subscriptions
$AzureVMs = Get-RSCAzureVMs
################################################
# Processing
################################################
# Creating array
$RSCTagAssignments = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($AzureVM in $AzureVMs)
{
# Setting variables
$Account = $AzureVM.Account
$AccountID = $AzureVM.AccountID
$VMName = $AzureVM.VM
$VMID = $AzureVM.VMID
$Tags = $AzureVM.Tags
# Adding To Array for Each tag
ForEach($Tag in $Tags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "Azure"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $Tag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $Tag.key
$Object | Add-Member -MemberType NoteProperty -Name "VM" -Value $VMName
$Object | Add-Member -MemberType NoteProperty -Name "VMID" -Value $VMID
$Object | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $Account
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $AccountID
# Adding
$RSCTagAssignments.Add($Object) | Out-Null
# End of for each tag assignment below
}
# End of for each tag assignment above
#
# End of for each object below
}
# End of for each object above
# Returning array
Return $RSCTagAssignments
# End of function
}