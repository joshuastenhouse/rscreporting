################################################
# Function - Get-RSCNewProtectedVMs - Getting all new VMs protected in the RSC instance
################################################
Function Get-RSCNewProtectedVMs {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of every new protected VM in RSV.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjects
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
Param
    (
        $DaysToCapture,
        [Parameter(ParameterSetName="User")][switch]$Logging
    )

################################################
# Importing Module & Running Required Functions
################################################
# If event limit null, setting to value
IF($DaysToCapture -eq $null){$DaysToCapture = 7}
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting RSC VMs
$RSCVMList = Get-RSCVMs
# Filtering
$RSCVMListFiltered = $RSCVMList | Where {(($_.ProtectedDays -gt 0) -and ($_.ProtectedDays -le $DaysToCapture))}
# Returning array
Return $RSCVMListFiltered
# End of function
}
