################################################
# Function - Get-RSCObjectsPendingFirstFull - Getting all objects waiting for a first full backup
################################################
Function Get-RSCObjectsPendingFirstFull {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning all objects pending a first full backup.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectTypes
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 08/06/2024
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting All Objects Pending First Full
################################################
# Getting objects list if not already pulled as a global variable in this session
IF($RSCGlobalObjects -eq $null)
{
$RSCObjects = Get-RSCObjects
}
ELSE
{
$RSCObjects = $RSCGlobalObjects
}
# Filtering for where PendingFirstFull is TRUE
$RSCObjectsFiltered = $RSCObjects | Where-Object {(($_.PendingFirstFull -eq $TRUE) -and ($_.ProtectionStatus -eq "Protected"))}

# Returning array
Return $RSCObjectsFiltered
# End of function
}
