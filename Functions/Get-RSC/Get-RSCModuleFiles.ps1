################################################
# Creating the Get-RSCModuleFiles function
################################################
Function Get-RSCModuleFiles {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all files within the PowerShell module, used by multiple other functions.

.DESCRIPTION
Returns a list of all of the files in the RSC Reporting module.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCModuleFiles
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

# Importing Module 
Import-Module RSCReporting
# Creating array
$RSCFileList = [System.Collections.ArrayList]@()
# Checking connectivity, exiting function with error if not connected
$RSCFiles = Get-Module -Name RSCReporting -All | Select-Object -ExpandProperty FileList
# Getting file names
ForEach($RSCFile in $RSCFiles)
{
$FileInfo = Get-ChildItem $RSCFile
$FileName = $FileInfo.BaseName
$FileFullName = $FileInfo.Name
$FileExtension = $FileInfo.Extension
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "File" -Value $FileFullName
$Object | Add-Member -MemberType NoteProperty -Name "FilePath" -Value $RSCFile
$Object | Add-Member -MemberType NoteProperty -Name "FileName" -Value $FileName
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $FileExtension
# Adding
$RSCFileList.Add($Object) | Out-Null

}
# Returning data
Return $RSCFileList
}
################################################
# End of script
################################################