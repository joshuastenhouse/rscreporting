################################################
# Function - Get-RSCObjectSummary - Getting summary all objects visible to the RSC instance
################################################
Function Get-RSCObjectSummary {

<#
.SYNOPSIS
A RSC Reporting Function returning a summary count of objects in RSC. WARNING: Requires Get-RSCObject to be run first to generate the data to be summarized.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectSummary
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
################################################
# Getting All Objects 
################################################
IF($RSCGlobalObjects -eq $null)
{
Write-Error "ERROR: Run Get-RSCObjects first to generate the data to summarize.."
Start-Sleep 2
Break
}
# Selecting unique objects
$UniqueObjectTypes = $RSCGlobalObjects | Sort-Object Type | Select-Object -ExpandProperty Type -Unique
 # Creating array
$RSCObjectSummary = [System.Collections.ArrayList]@()
# For each type getting counts
ForEach($UniqueObjectType in $UniqueObjectTypes)
{
# Selecting objects
$UniqueObjects = $RSCGlobalObjects | Where-Object {$_.Type -eq $UniqueObjectType}
# Counting
$UniqueObjectsCount = $UniqueObjects | Measure-Object | Select-Object -ExpandProperty Count
$UniqueProtectedObjects = $UniqueObjects | Where-Object {$_.ProtectionStatus -eq "Protected"} | Measure-Object| Select-Object -ExpandProperty Count
$UniqueUnProtectedObjects = $UniqueObjects | Where-Object {$_.ProtectionStatus -eq "NoSla"} | Measure-Object | Select-Object -ExpandProperty Count
$UniqueDoNotProtectObjects = $UniqueObjects | Where-Object {$_.ProtectionStatus -eq "DoNotProtect"} | Measure-Object | Select-Object -ExpandProperty Count
$UniquePendingFirstFullObjects = $UniqueObjects | Where-Object {$_.PendingFirstFull -eq "True"} | Measure-Object | Select-Object -ExpandProperty Count
$UniqueRubrikClusters = $UniqueObjects | Select-Object -ExpandProperty RubrikClusterID -Unique | Measure-Object | Select-Object -ExpandProperty Count
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $UniqueObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Total" -Value $UniqueObjectsCount
$Object | Add-Member -MemberType NoteProperty -Name "Protected" -Value $UniqueProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "Unprotected" -Value $UniqueUnProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtect" -Value $UniqueDoNotProtectObjects
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $UniquePendingFirstFullObjects
# Adding
$RSCObjectSummary.Add($Object) | Out-Null
}
# Summarizing all
$UniqueObjectsCount = $RSCObjects | Measure-Object | Select-Object -ExpandProperty Count
$UniqueProtectedObjects = $RSCObjects | Where-Object {$_.ProtectionStatus -eq "Protected"} | Measure-Object| Select-Object -ExpandProperty Count
$UniqueUnProtectedObjects = $RSCObjects | Where-Object {$_.ProtectionStatus -eq "NoSla"} | Measure-Object | Select-Object -ExpandProperty Count
$UniqueDoNotProtectObjects = $RSCObjects | Where-Object {$_.ProtectionStatus -ne "DoNotProtect"} | Measure-Object | Select-Object -ExpandProperty Count
$UniquePendingFirstFullObjects = $RSCObjects | Where-Object {$_.PendingFirstFull -eq "True"} | Measure-Object | Select-Object -ExpandProperty Count
$UniqueRubrikClusters = $RSCObjects | Select-Object -ExpandProperty RubrikClusterID -Unique | Measure-Object | Select-Object -ExpandProperty Count
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value "ALL"
$Object | Add-Member -MemberType NoteProperty -Name "Total" -Value $UniqueObjectsCount
$Object | Add-Member -MemberType NoteProperty -Name "Protected" -Value $UniqueProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "Unprotected" -Value $UniqueUnProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtect" -Value $UniqueDoNotProtectObjects
$Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $UniquePendingFirstFullObjects
# Adding
$RSCObjectSummary.Add($Object) | Out-Null

# Returning array
Return $RSCObjectSummary
# End of function
}
