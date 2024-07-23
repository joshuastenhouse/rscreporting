################################################
# Function - Get-RSCAzureSQLDBTagAssignments - Getting Azure Tags assigned to SQLDBs visible to RSC
################################################
Function Get-RSCAzureSQLDBTagAssignments {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function a list of all Azure SQL tag assignments.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAzureSQLDBTagAssignments
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
$AzureSQLDatabases = Get-RSCAzureSQLDBs
################################################
# Processing
################################################
# Creating array
$RSCTagAssignments = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($AzureSQLDatabase in $AzureSQLDatabases)
{
# Setting variables
$Account = $AzureStorageAccount.Account
$AccountID = $AzureStorageAccount.AccountID
$Name = $AzureStorageAccount.StorageAccount
$ID = $AzureStorageAccount.StorageAccountID
$Tags = $AzureStorageAccount.Tags
# Adding To Array for Each tag
ForEach($Tag in $Tags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "Azure"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $Tag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $Tag.key
$Object | Add-Member -MemberType NoteProperty -Name "StorageAccount" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "StorageAccountID" -Value $ID
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