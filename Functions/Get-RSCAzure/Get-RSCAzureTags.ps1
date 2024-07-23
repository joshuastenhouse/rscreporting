################################################
# Function - Get-RSCAzureTags - Getting Azure Tags connected to RSC
################################################
Function Get-RSCAzureTags {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function a list of all Azure tags.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAzureTags
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
# Getting all Azure subscriptions
$AzureSubscriptions = Get-RSCAzureSubscriptions
################################################
# Processing
################################################
# Creating array
$AzureTags = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($AzureSub in $AzureSubscriptions)
{
# Setting variables
$AzureSubName = $AzureSub.Subscription
$AzureSubID = $AzureSub.SubscriptionID
$AzureSubTags = $AzureSub.Tags
# Adding each tag to array
ForEach($Tag in $AzureSubTags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "Azure"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $Tag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $Tag.key
$Object | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $AzureSubName
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $AzureSubID
$AzureTags.Add($Object) | Out-Null
}
# End of for each object below
}
# End of for each object above
# Returning array
Return $AzureTags
# End of function
}