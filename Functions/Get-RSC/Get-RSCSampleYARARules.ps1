################################################
# Creating the Get-RSCSampleYARARules function
################################################
Function Get-RSCSampleYARARules {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all YARA rule samples included in the module.

.DESCRIPTION
Makes no API calls, just querying files included in the module filelist.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSampleYARARules
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

# Importing Module 
Import-Module RSCReporting
# Getting module files
$RSCYARAFiles = Get-RSCModuleFiles | Where-Object {$_.Type -eq ".yara"}
# Creating array
$RSCYARARules = [System.Collections.ArrayList]@()
# Creating IDs
$YARARuleIDCounter = 0
# Processing YARA rules
ForEach($File in $RSCYARAFiles)
{
$YARARuleIDCounter++
# Setting variables required
$FilePath = $File.FilePath
$YARARuleName = $File.FileName
$FileType = $File.Type
# Importing file to read metadata
$FileImport = Get-Content $FilePath
# Getting YARA rule date
[string]$YARARuleDate = $FileImport | Select-String -Pattern 'date =' | Select-Object -First 1
IF($YARARuleDate -ne $null){$YARARuleDate = $YARARuleDate.Replace("date = ","").Replace('"',"").Trim()}
# Getting YARA rule author
[string]$YARARuleAuth = $FileImport | Select-String -Pattern 'author =' | Select-Object -First 1
IF($YARARuleAuth -ne $null){$YARARuleAuth = $YARARuleAuth.Replace("author = ","").Replace('"',"").Trim()}
# Getting YARA rule description
[string]$YARARuleDesc = $FileImport | Select-String -Pattern 'description =' | Select-Object -First 1
IF($YARARuleDesc -ne $null){$YARARuleDesc = $YARARuleDesc.Replace("description = ","").Replace('"',"").Trim()}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RuleID" -Value $YARARuleIDCounter
$Object | Add-Member -MemberType NoteProperty -Name "RuleName" -Value $YARARuleName
$Object | Add-Member -MemberType NoteProperty -Name "Author" -Value $YARARuleAuth
$Object | Add-Member -MemberType NoteProperty -Name "Description" -Value $YARARuleDesc
$Object | Add-Member -MemberType NoteProperty -Name "File" -Value $File
$Object | Add-Member -MemberType NoteProperty -Name "FilePath" -Value $FileName
$Object | Add-Member -MemberType NoteProperty -Name "YARARule" -Value $FileImport
# Adding
$RSCYARARules.Add($Object) | Out-Null
}
# Returning data
Return $RSCYARARules
}
################################################
# End of script
################################################