################################################
# Function - Test-RSCSQLModule - Testing SQL module exists on system
################################################
Function Test-RSCSQLModule {

<#
.SYNOPSIS
This function verifies a valid SQL server PowerShell module is installed on this host..

.DESCRIPTION
Use to validate that you have a functioning Mssql powershell module installed on this host. Should be either SQLPS or SqlServer.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Test-RSCSQLModule
This example verifies a valid SQL server PowerShell module is installed on this host.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Breaking if no Sqlserver module installed
################################################
$PSModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name
$PSModuleCounter = 0
# Checking for SQLPS
IF($PSModules -contains "SQLPS"){$PSModuleCounter++}
# Checking for SqlServer
IF($PSModules -contains "SqlServer"){$PSModuleCounter++}
# Breaking if nothing found
IF($PSModuleCounter -eq 0)
{
Write-Error "ERROR: SqlServer module not installed and is needed to run this function. As administrator type Install-Module Sqlserver and try again.."
Start-Sleep 2
Break
}

# Returning null
Return $null
# End of function
}