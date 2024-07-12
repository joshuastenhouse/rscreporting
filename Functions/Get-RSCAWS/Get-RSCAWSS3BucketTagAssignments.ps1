################################################
# Function - Get-RSCAWSS3BucketTagAssignments - Getting AWS Tags assigned to S3 Buckets visible to RSC
################################################
Function Get-RSCAWSS3BucketTagAssignments {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function a list of all AWS S3 bucket tag assignments.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAWSS3BucketTagAssignments
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
$AWSS3Buckets = Get-RSCAWSS3Buckets
################################################
# Processing
################################################
# Creating array
$RSCTagAssignments = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($AWSS3Bucket in $AWSS3Buckets)
{
# Setting variables
$Account = $AWSS3Bucket.Account
$AccountID = $AWSS3Bucket.AccountID
$Name = $AWSS3Bucket.S3Bucket
$ID = $AWSS3Bucket.S3BucketID
$Tags = $AWSS3Bucket.Tags
# Adding To Array for Each tag
ForEach($Tag in $Tags)
{
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cloud" -Value "Azure"
$Object | Add-Member -MemberType NoteProperty -Name "Tag" -Value $Tag.value
$Object | Add-Member -MemberType NoteProperty -Name "TagKey" -Value $Tag.key
$Object | Add-Member -MemberType NoteProperty -Name "S3Bucket" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "S3BucketID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "Account" -Value $Account
$Object | Add-Member -MemberType NoteProperty -Name "AccountID" -Value $AccountID
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