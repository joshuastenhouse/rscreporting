################################################
# Function - Get-RSCUnprotectedObjects - Getting all Unprotected objects visible to the RSC instance
################################################
Function Get-RSCUnprotectedObjects {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all Unprotected objects.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCUnprotectedObjects
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
# Running existing function
$RSCOjbects = Get-RSCObjects
# Filtering
$RSCUnprotectedObjects = $RSCOjbects | Where-Object {$_.ProtectionStatus -eq "NoSla"}

# Returning array
Return $RSCUnprotectedObjects
# End of function
}
